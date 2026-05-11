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
///   "version": 3,
///   "exported_at": "2026-05-04T13:42:00.000Z",
///   "habits": [...],
///   "habit_logs": [...],
///   "time_blocks": [...],
///   "subjects": [...],
///   "focus_sessions": [...],
///   "profile": {...},
///   "settings": {...}
/// }
///
/// Backwards compatibility: imports also accept legacy format strings
/// `manup-backup` / `ironwill-backup`, the v1 `focus_sessions` (recurring
/// schedule with `days_csv`), and the v2 `subject_blocks` (recurring
/// weekly blocks). Both legacy shapes are fanned out into modern
/// one-shot `focus_sessions` rows at import time, covering the subject's
/// expiry window starting from today.
class BackupService {
  final LocalDb db;
  BackupService(this.db);

  static const String formatId = 'lockedin-backup';
  static const Set<String> _legacyFormatIds = {'manup-backup', 'ironwill-backup'};

  /// Bumped to 3 alongside the schema v6 migration: the export now contains
  /// modern `focus_sessions` (one-shot windows) instead of `subject_blocks`,
  /// and `time_blocks` rows now carry a `subject_id`.
  static const int formatVersion = 3;

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
      'focus_sessions': dump['focus_sessions'],
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
    final timeBlocks =
        _coerceList(parsed['time_blocks']).map(_normaliseTimeBlock).toList();

    // Three input shapes to handle:
    //   * modern v3+ export with `focus_sessions` (one-shot windows)
    //   * v2 export with `subjects` + `subject_blocks` (recurring weekly)
    //   * v1 export with `focus_sessions` legacy fields (days_csv +
    //     start_hour/start_minute), which we fan out into modern sessions
    final List<Map<String, Object?>> subjects;
    final List<Map<String, Object?>> focusSessions;
    if (parsed.containsKey('focus_sessions') &&
        _looksModernFocusSessions(parsed['focus_sessions'])) {
      subjects = _coerceList(parsed['subjects']);
      focusSessions = _coerceList(parsed['focus_sessions']);
    } else if (parsed.containsKey('subjects') &&
        parsed.containsKey('subject_blocks')) {
      subjects = _coerceList(parsed['subjects']);
      focusSessions = _fanOutSubjectBlocks(
        subjects: subjects,
        blocks: _coerceList(parsed['subject_blocks']),
      );
    } else {
      final legacy = _coerceList(parsed['focus_sessions']);
      final pair = _fanOutLegacyFocusSessions(legacy);
      subjects = pair.$1;
      focusSessions = pair.$2;
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
      focusSessions: focusSessions,
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

  /// v6 added `time_blocks.subject_id`; pre-v6 exports don't have it.
  static Map<String, Object?> _normaliseTimeBlock(Map<String, Object?> b) {
    if (b.containsKey('subject_id')) return b;
    return {...b, 'subject_id': null};
  }

  /// A modern focus_sessions row has `start_at` (epoch ms). The legacy v1
  /// shape uses `days_csv` + `start_hour` etc, which we route through the
  /// legacy fan-out instead.
  static bool _looksModernFocusSessions(Object? raw) {
    if (raw is! List || raw.isEmpty) return false;
    final first = raw.first;
    if (first is! Map) return false;
    return first.containsKey('start_at') && first.containsKey('end_at');
  }

  /// Convert v2 `subject_blocks` (recurring weekly) into modern one-shot
  /// focus_sessions. For each block we fan out one session per matching
  /// weekday from today through the owning subject's expires_at.
  static List<Map<String, Object?>> _fanOutSubjectBlocks({
    required List<Map<String, Object?>> subjects,
    required List<Map<String, Object?>> blocks,
  }) {
    final expiresBySubject = <String, DateTime>{};
    for (final s in subjects) {
      final id = s['id'] as String?;
      final ex = s['expires_at'] as String?;
      if (id != null && ex != null) {
        try {
          expiresBySubject[id] = _parseIso(ex);
        } catch (_) {}
      }
    }
    final out = <Map<String, Object?>>[];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var counter = 0;
    for (final b in blocks) {
      final sid = b['subject_id'] as String?;
      if (sid == null) continue;
      final expires = expiresBySubject[sid] ?? todayDate.add(const Duration(days: 7));
      final dow = (b['day_of_week'] as num?)?.toInt();
      final sh = (b['start_hour'] as num?)?.toInt() ?? 0;
      final sm = (b['start_minute'] as num?)?.toInt() ?? 0;
      final eh = (b['end_hour'] as num?)?.toInt() ?? 0;
      final em = (b['end_minute'] as num?)?.toInt() ?? 0;
      if (dow == null || eh * 60 + em <= sh * 60 + sm) continue;
      var day = todayDate;
      while (!day.isAfter(expires)) {
        if (day.weekday == dow) {
          final start = DateTime(day.year, day.month, day.day, sh, sm);
          final end = DateTime(day.year, day.month, day.day, eh, em);
          out.add({
            'id': 'fs_imp_${nowMs}_${counter++}',
            'subject_id': sid,
            'start_at': start.millisecondsSinceEpoch,
            'end_at': end.millisecondsSinceEpoch,
            'created_at': nowMs,
          });
        }
        day = day.add(const Duration(days: 1));
      }
    }
    return out;
  }

  /// Convert v1 legacy `focus_sessions` (one row per "subject" with
  /// `days_csv` + start/end hour/minute) into v2 subjects + v6
  /// one-shot focus_sessions.
  static (List<Map<String, Object?>>, List<Map<String, Object?>>)
      _fanOutLegacyFocusSessions(List<Map<String, Object?>> legacy) {
    final subjects = <Map<String, Object?>>[];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final expires = todayDate.add(Duration(days: LocalDb.defaultExpiryDays));
    final expiresIso =
        '${expires.year.toString().padLeft(4, '0')}-${expires.month.toString().padLeft(2, '0')}-${expires.day.toString().padLeft(2, '0')}';
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final blocks = <Map<String, Object?>>[];
    for (var i = 0; i < legacy.length; i++) {
      final s = legacy[i];
      final id = s['id'] as String;
      subjects.add({
        'id': id,
        'name': s['name'] as String? ?? 'Subject',
        'expires_at': expiresIso,
        'created_at': nowMs,
        'ord': i,
      });
      final csv = (s['days_csv'] as String? ?? '').trim();
      final days = csv.isEmpty
          ? const <int>[]
          : csv.split(',').map((x) => int.parse(x.trim())).toList();
      for (final d in days) {
        blocks.add({
          'subject_id': id,
          'day_of_week': d,
          'start_hour': s['start_hour'],
          'start_minute': s['start_minute'],
          'end_hour': s['end_hour'],
          'end_minute': s['end_minute'],
        });
      }
    }
    final sessions =
        _fanOutSubjectBlocks(subjects: subjects, blocks: blocks);
    return (subjects, sessions);
  }

  static DateTime _parseIso(String s) {
    final parts = s.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
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
