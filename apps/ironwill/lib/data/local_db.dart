import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// On-disk SQLite database. Single source of truth for every persisted record.
/// The repositories are the only callers; nothing in the UI imports this file.
class LocalDb {
  static const int schemaVersion = 2;
  static const String dbFileName = 'manup.db';

  final Database db;
  LocalDb._(this.db);

  static LocalDb? _instance;
  static LocalDb get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('LocalDb not initialised. Call LocalDb.open() at startup.');
    }
    return i;
  }

  static Future<LocalDb> open() async {
    if (_instance != null) return _instance!;
    final factory = _pickFactory();
    final path = await _resolveDbPath();
    final database = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    _instance = LocalDb._(database);
    return _instance!;
  }

  static DatabaseFactory _pickFactory() {
    if (kIsWeb) {
      throw UnsupportedError('Web is not a target for the offline build.');
    }
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      sqfliteFfiInit();
      return databaseFactoryFfi;
    }
    return databaseFactory;
  }

  static Future<String> _resolveDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dbFileName);
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE habits(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        cadence TEXT NOT NULL,
        custom_days TEXT NOT NULL DEFAULT '',
        glyph_codepoint INTEGER NOT NULL,
        glyph_font_family TEXT,
        glyph_font_package TEXT,
        reminder_hour INTEGER NOT NULL DEFAULT 7,
        reminder_minute INTEGER NOT NULL DEFAULT 0,
        reminder_on INTEGER NOT NULL DEFAULT 1,
        archived INTEGER NOT NULL DEFAULT 0,
        ord INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE habit_logs(
        habit_id TEXT NOT NULL,
        date_iso TEXT NOT NULL,
        utilization INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        PRIMARY KEY(habit_id, date_iso),
        FOREIGN KEY(habit_id) REFERENCES habits(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_habit_logs_date ON habit_logs(date_iso)');
    batch.execute('''
      CREATE TABLE time_blocks(
        date_iso TEXT NOT NULL,
        quarter INTEGER NOT NULL,
        utilization INTEGER NOT NULL,
        PRIMARY KEY(date_iso, quarter)
      )
    ''');
    batch.execute('CREATE INDEX idx_time_blocks_date ON time_blocks(date_iso)');
    batch.execute('''
      CREATE TABLE focus_sessions(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        start_hour INTEGER NOT NULL,
        start_minute INTEGER NOT NULL,
        end_hour INTEGER NOT NULL,
        end_minute INTEGER NOT NULL,
        days_csv TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE profile(
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        daily_focus_minutes_target INTEGER NOT NULL,
        focus_streak_days INTEGER NOT NULL DEFAULT 0,
        avatar_letter TEXT,
        timezone TEXT NOT NULL DEFAULT 'Local'
      )
    ''');
    batch.execute('''
      CREATE TABLE settings(
        id INTEGER PRIMARY KEY CHECK (id = 1),
        first_day TEXT NOT NULL DEFAULT 'monday',
        alarm_sound TEXT NOT NULL DEFAULT 'softChime',
        reminder_logging INTEGER NOT NULL DEFAULT 1,
        daily_focus_minutes INTEGER NOT NULL DEFAULT 240,
        privacy_lock_on INTEGER NOT NULL DEFAULT 0,
        theme_mode TEXT NOT NULL DEFAULT 'system',
        onboarded INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('''
      INSERT INTO profile(id, name, daily_focus_minutes_target, focus_streak_days, avatar_letter)
      VALUES (1, 'You', 240, 0, 'Y')
    ''');
    batch.execute('INSERT INTO settings(id) VALUES (1)');
    await batch.commit(noResult: true);
  }

  static Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute("ALTER TABLE habits ADD COLUMN description TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE habit_logs ADD COLUMN note TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE settings ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'system'");
      await db.execute("ALTER TABLE settings ADD COLUMN onboarded INTEGER NOT NULL DEFAULT 1");
    }
  }

  Future<void> close() async => db.close();

  /// Wipe and replace data with the given snapshot. Used by Import.
  Future<void> replaceAll({
    required List<Map<String, Object?>> habits,
    required List<Map<String, Object?>> habitLogs,
    required List<Map<String, Object?>> timeBlocks,
    required List<Map<String, Object?>> focusSessions,
    required Map<String, Object?> profile,
    required Map<String, Object?> settings,
  }) async {
    await db.transaction((txn) async {
      await txn.delete('habit_logs');
      await txn.delete('time_blocks');
      await txn.delete('focus_sessions');
      await txn.delete('habits');
      await txn.delete('profile');
      await txn.delete('settings');
      for (final h in habits) {
        await txn.insert('habits', h);
      }
      for (final l in habitLogs) {
        await txn.insert('habit_logs', l);
      }
      for (final b in timeBlocks) {
        await txn.insert('time_blocks', b);
      }
      for (final s in focusSessions) {
        await txn.insert('focus_sessions', s);
      }
      await txn.insert('profile', {...profile, 'id': 1});
      await txn.insert('settings', {...settings, 'id': 1});
    });
  }

  Future<Map<String, List<Map<String, Object?>>>> dumpForExport() async {
    final habits = await db.query('habits');
    final logs = await db.query('habit_logs');
    final blocks = await db.query('time_blocks');
    final sessions = await db.query('focus_sessions');
    final profileRows = await db.query('profile');
    final settingsRows = await db.query('settings');
    return {
      'habits': habits,
      'habit_logs': logs,
      'time_blocks': blocks,
      'focus_sessions': sessions,
      'profile': profileRows,
      'settings': settingsRows,
    };
  }
}

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseIso(String s) {
  final parts = s.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

DateTime truncate(DateTime d) => DateTime(d.year, d.month, d.day);
