import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'local_db.dart';

/// JSON shape (current):
///
/// {
///   "format": "lockedin-backup",
///   "version": 2,
///   "exported_at": "2026-05-04T13:42:00.000Z",
///   "habits": [...],
///   "habit_logs": [...],
///   "time_blocks": [...],
///   "subjects": [...],
///   "subject_blocks": [...],
///   "profile": {...},
///   "settings": {...}
/// }
///
/// Backwards compatibility: imports also accept legacy format strings
/// `manup-backup` / `ironwill-backup` and the legacy `focus_sessions` field
/// (one focus_session becomes one subject with one block per scheduled
/// weekday). Habits without a `metadata` field default to an empty `{}`.
class BackupService {
  final LocalDb db;
  BackupService(this.db);

  static const String formatId = 'lockedin-backup';
  static const Set<String> _legacyFormatIds = {'manup-backup', 'ironwill-backup'};

  /// Bumped to 2 alongside the schema v3 migration: the export now contains
  /// `subjects` + `subject_blocks` instead of `focus_sessions`, and each habit
  /// row carries a `metadata` JSON column.
  static const int formatVersion = 2;

  /// Build the export string. Pure JSON.
  Future<String> exportJson() async {
    final dump = await db.dumpForExport();
    final payload = {
      'format': formatId,
      'version': formatVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'habits': dump['habits'],
      'habit_logs': dump['habit_logs'],
      'time_blocks': dump['time_blocks'],
      'subjects': dump['subjects'],
      'subject_blocks': dump['subject_blocks'],
      'profile': (dump['profile']!.isNotEmpty ? dump['profile']!.first : <String, Object?>{}),
      'settings': (dump['settings']!.isNotEmpty ? dump['settings']!.first : <String, Object?>{}),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Write JSON to a temp file, return its path.
  Future<File> exportToTempFile() async {
    final json = await exportJson();
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File(p.join(dir.path, 'lockedin-backup-$ts.json'));
    await file.writeAsString(json);
    return file;
  }

  /// Trigger system share sheet so the user picks where to send it.
  Future<void> shareExport() async {
    final file = await exportToTempFile();
    if (kIsWeb) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'LockedIn backup',
      text: 'LockedIn data export.',
    ));
  }

  /// User-driven restore. Returns true on success, false if cancelled.
  /// Throws on validation failure.
  Future<bool> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return false;
    final f = result.files.single;
    final bytes = f.bytes;
    String content;
    if (bytes != null) {
      content = utf8.decode(bytes);
    } else if (f.path != null) {
      content = await File(f.path!).readAsString();
    } else {
      throw const FormatException('Could not read selected file.');
    }
    await importFromJson(content);
    return true;
  }

  Future<void> importFromJson(String json) async {
    final dynamic parsed = jsonDecode(json);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Backup root is not an object.');
    }
    final fmt = parsed['format'];
    if (fmt != formatId && !_legacyFormatIds.contains(fmt)) {
      throw FormatException('Not a LockedIn backup (format=$fmt).');
    }
    final v = parsed['version'];
    if (v is! int || v > formatVersion) {
      throw FormatException(
        'Unsupported backup version $v. This app understands $formatVersion.',
      );
    }
    final habits = _coerceList(parsed['habits']).map(_normaliseHabit).toList();
    final logs = _coerceList(parsed['habit_logs']);
    final timeBlocks = _coerceList(parsed['time_blocks']);

    final hasModernSubjects = parsed.containsKey('subjects');
    final List<Map<String, Object?>> subjects;
    final List<Map<String, Object?>> subjectBlocks;
    if (hasModernSubjects) {
      subjects = _coerceList(parsed['subjects']);
      subjectBlocks = _coerceList(parsed['subject_blocks']);
    } else {
      // v1 export with focus_sessions: collapse each focus_session into a
      // subject + one block per weekday it ran on.
      final legacy = _coerceList(parsed['focus_sessions']);
      final pair = _migrateLegacyFocusSessions(legacy);
      subjects = pair.$1;
      subjectBlocks = pair.$2;
    }

    final profile = _coerceMap(parsed['profile']);
    // v4 introduces `weekly_focus_minutes_csv` on profile; legacy exports
    // only carry the single `daily_focus_minutes_target`. Seed all 7 days
    // from that value so the user keeps the same effective behaviour.
    if (!profile.containsKey('weekly_focus_minutes_csv')) {
      final daily = (profile['daily_focus_minutes_target'] as int?) ?? 240;
      profile['weekly_focus_minutes_csv'] = List.filled(7, daily).join(',');
    }
    final settings = _coerceMap(parsed['settings']);
    // Settings columns added in schema v3 may be absent from a v1 export.
    settings.putIfAbsent('block_size_minutes', () => 30);
    settings.putIfAbsent('pomodoro_enabled', () => 0);
    settings.putIfAbsent('pomodoro_percent', () => 15);

    await db.replaceAll(
      habits: habits,
      habitLogs: logs,
      timeBlocks: timeBlocks,
      subjects: subjects,
      subjectBlocks: subjectBlocks,
      profile: profile,
      settings: settings,
    );
  }

  /// Old habit rows didn't carry a `metadata` column. Add `{}` so the modern
  /// schema's NOT NULL constraint is satisfied without dropping data.
  static Map<String, Object?> _normaliseHabit(Map<String, Object?> h) {
    if (h.containsKey('metadata')) return h;
    return {...h, 'metadata': '{}'};
  }

  /// Convert legacy `focus_sessions` list into modern (subjects, blocks). Each
  /// session becomes one subject row + N block rows (one per scheduled
  /// weekday). The subject expires `defaultExpiryDays` from today, matching
  /// the new TTL semantics; the user can extend any time via "Repeat".
  static (List<Map<String, Object?>>, List<Map<String, Object?>>)
      _migrateLegacyFocusSessions(List<Map<String, Object?>> legacy) {
    final subjects = <Map<String, Object?>>[];
    final blocks = <Map<String, Object?>>[];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expiresAt =
        '${todayDate.add(Duration(days: LocalDb.defaultExpiryDays)).year.toString().padLeft(4, '0')}-'
        '${todayDate.add(Duration(days: LocalDb.defaultExpiryDays)).month.toString().padLeft(2, '0')}-'
        '${todayDate.add(Duration(days: LocalDb.defaultExpiryDays)).day.toString().padLeft(2, '0')}';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < legacy.length; i++) {
      final s = legacy[i];
      final id = s['id'] as String;
      subjects.add({
        'id': id,
        'name': s['name'] as String? ?? 'Subject',
        'expires_at': expiresAt,
        'created_at': nowMs,
        'ord': i,
      });
      final csv = (s['days_csv'] as String? ?? '').trim();
      final days = csv.isEmpty
          ? const <int>[]
          : csv.split(',').map((x) => int.parse(x.trim())).toList();
      for (final d in days) {
        blocks.add({
          'id': 'b${nowMs}_${id}_$d',
          'subject_id': id,
          'day_of_week': d,
          'start_hour': s['start_hour'],
          'start_minute': s['start_minute'],
          'end_hour': s['end_hour'],
          'end_minute': s['end_minute'],
          'pomodoro_enabled': 0,
          'pomodoro_percent': 15,
        });
      }
    }
    return (subjects, blocks);
  }

  static List<Map<String, Object?>> _coerceList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => m.cast<String, Object?>())
        .toList();
  }

  static Map<String, Object?> _coerceMap(Object? raw) {
    if (raw is Map) return raw.cast<String, Object?>();
    return <String, Object?>{};
  }
}
