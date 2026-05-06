import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'local_db.dart';

/// JSON shape:
///
/// {
///   "format": "manup-backup",
///   "version": 1,
///   "exported_at": "2026-05-04T13:42:00.000Z",
///   "habits": [...],
///   "habit_logs": [...],
///   "time_blocks": [...],
///   "focus_sessions": [...],
///   "profile": {...},
///   "settings": {...}
/// }
class BackupService {
  final LocalDb db;
  BackupService(this.db);

  static const String formatId = 'manup-backup';
  static const int formatVersion = 1;

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
    final file = File(p.join(dir.path, 'ironwill-backup-$ts.json'));
    await file.writeAsString(json);
    return file;
  }

  /// Trigger system share sheet so the user picks where to send it.
  Future<void> shareExport() async {
    final file = await exportToTempFile();
    if (kIsWeb) return;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'IronWill backup',
      text: 'IronWill data export.',
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
    if (parsed['format'] != formatId) {
      throw FormatException('Not a IronWill backup (format=${parsed['format']}).');
    }
    final v = parsed['version'];
    if (v is! int || v > formatVersion) {
      throw FormatException(
        'Unsupported backup version $v. This app understands $formatVersion.',
      );
    }
    final habits = _coerceList(parsed['habits']);
    final logs = _coerceList(parsed['habit_logs']);
    final blocks = _coerceList(parsed['time_blocks']);
    final sessions = _coerceList(parsed['focus_sessions']);
    final profile = _coerceMap(parsed['profile']);
    final settings = _coerceMap(parsed['settings']);

    await db.replaceAll(
      habits: habits,
      habitLogs: logs,
      timeBlocks: blocks,
      focusSessions: sessions,
      profile: profile,
      settings: settings,
    );
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
