import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// On-disk SQLite database. Single source of truth for every persisted record.
/// The repositories are the only callers; nothing in the UI imports this file.
///
/// Schema versions:
///   v1: original.
///   v2: habits.description, habit_logs.note, settings.theme_mode + onboarded.
///   v3: focus_sessions replaced by subjects + subject_blocks (a Subject is the
///       umbrella term, and one Subject can have many scheduled blocks across
///       weekdays). habits.metadata (TEXT JSON) replaces the dumb description
///       field as the structured key/value store. settings gains
///       block_size_minutes (default 30), pomodoro_enabled (default 0) and
///       pomodoro_percent (default 15). subjects carry an expires_at date so a
///       schedule decays after a week unless the user presses "Repeat".
///   v4: profile.weekly_focus_minutes_csv (Mon..Sun, 7 ints comma-separated)
///       supersedes the single daily_focus_minutes_target. The user can now
///       pick a different focus target per weekday and a 12-hour day is
///       allowed (cap 1440 min). The legacy column stays in place but is
///       no longer the source of truth.
///   v5: habit_logs.metadata (TEXT JSON) holds the day's values for the
///       structured fields the user defined on the parent habit. Lets the
///       app track e.g. pushup reps `{"PU": [15, 12, 10]}` per day.
class LocalDb {
  static const int schemaVersion = 5;
  static const String dbFileName = 'lockedin.db';

  /// New subjects default to expiring 7 days from today. Migration of existing
  /// focus_sessions also uses this default so the user's old plan is consistent
  /// with the new TTL semantics. The user can extend any time via "Repeat".
  static const int defaultExpiryDays = 7;

  /// Default daily focus target in minutes. Used to seed all 7 weekdays on
  /// first install if the legacy single-value column isn't present.
  static const int defaultDailyFocusMinutes = 240;

  /// Weekly target column default (CSV of 7 ints, Mon..Sun).
  static const String defaultWeeklyFocusCsv = '240,240,240,240,240,240,240';

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
        // sqflite opens with `foreign_keys=OFF` by default. Without this,
        // the ON DELETE CASCADE clauses on `subject_blocks(subject_id)` and
        // `habit_logs(habit_id)` are silently ignored and deleting a
        // parent leaves orphans behind.
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
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
        metadata TEXT NOT NULL DEFAULT '{}',
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
        metadata TEXT NOT NULL DEFAULT '{}',
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
      CREATE TABLE subjects(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        ord INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('''
      CREATE TABLE subject_blocks(
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_hour INTEGER NOT NULL,
        start_minute INTEGER NOT NULL,
        end_hour INTEGER NOT NULL,
        end_minute INTEGER NOT NULL,
        pomodoro_enabled INTEGER NOT NULL DEFAULT 0,
        pomodoro_percent INTEGER NOT NULL DEFAULT 15,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_subject_blocks_subject ON subject_blocks(subject_id)');
    batch.execute('CREATE INDEX idx_subject_blocks_day ON subject_blocks(day_of_week)');
    batch.execute('''
      CREATE TABLE profile(
        id INTEGER PRIMARY KEY CHECK (id = 1),
        name TEXT NOT NULL,
        daily_focus_minutes_target INTEGER NOT NULL,
        weekly_focus_minutes_csv TEXT NOT NULL DEFAULT '$defaultWeeklyFocusCsv',
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
        onboarded INTEGER NOT NULL DEFAULT 0,
        block_size_minutes INTEGER NOT NULL DEFAULT 30,
        pomodoro_enabled INTEGER NOT NULL DEFAULT 0,
        pomodoro_percent INTEGER NOT NULL DEFAULT 15
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
    if (from < 3) {
      await _migrateV2toV3(db);
    }
    if (from < 4) {
      await _migrateV3toV4(db);
    }
    if (from < 5) {
      await _migrateV4toV5(db);
    }
  }

  /// v4 -> v5: add habit_logs.metadata for structured per-day tracking values.
  static Future<void> _migrateV4toV5(Database db) async {
    await db.execute(
        "ALTER TABLE habit_logs ADD COLUMN metadata TEXT NOT NULL DEFAULT '{}'");
  }

  /// v3 -> v4: add per-weekday focus targets. Seed all 7 days from the legacy
  /// single value so the user keeps the same behaviour as before until they
  /// edit any individual day.
  static Future<void> _migrateV3toV4(Database db) async {
    await db.execute(
        "ALTER TABLE profile ADD COLUMN weekly_focus_minutes_csv TEXT NOT NULL DEFAULT '$defaultWeeklyFocusCsv'");
    final rows = await db.query('profile', where: 'id = ?', whereArgs: [1]);
    if (rows.isNotEmpty) {
      final daily = (rows.first['daily_focus_minutes_target'] as int?) ??
          defaultDailyFocusMinutes;
      final csv = List.filled(7, daily).join(',');
      await db.update('profile', {'weekly_focus_minutes_csv': csv},
          where: 'id = ?', whereArgs: [1]);
    }
  }

  /// v2 -> v3: add structured habit metadata, the block-size and pomodoro
  /// settings, and convert focus_sessions into the new subjects + subject_blocks
  /// hierarchy (one focus_session becomes one subject with one block per
  /// scheduled weekday). The old table is dropped at the end.
  static Future<void> _migrateV2toV3(Database db) async {
    await db.execute("ALTER TABLE habits ADD COLUMN metadata TEXT NOT NULL DEFAULT '{}'");
    await db.execute(
        "ALTER TABLE settings ADD COLUMN block_size_minutes INTEGER NOT NULL DEFAULT 30");
    await db.execute(
        "ALTER TABLE settings ADD COLUMN pomodoro_enabled INTEGER NOT NULL DEFAULT 0");
    await db.execute(
        "ALTER TABLE settings ADD COLUMN pomodoro_percent INTEGER NOT NULL DEFAULT 15");
    await db.execute('''
      CREATE TABLE subjects(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        ord INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE subject_blocks(
        id TEXT PRIMARY KEY,
        subject_id TEXT NOT NULL,
        day_of_week INTEGER NOT NULL,
        start_hour INTEGER NOT NULL,
        start_minute INTEGER NOT NULL,
        end_hour INTEGER NOT NULL,
        end_minute INTEGER NOT NULL,
        pomodoro_enabled INTEGER NOT NULL DEFAULT 0,
        pomodoro_percent INTEGER NOT NULL DEFAULT 15,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_subject_blocks_subject ON subject_blocks(subject_id)');
    await db.execute(
        'CREATE INDEX idx_subject_blocks_day ON subject_blocks(day_of_week)');

    // Carry every old focus_session over as a subject with N blocks.
    final oldSessions = await db.query('focus_sessions');
    final today = truncate(DateTime.now());
    final expiresAt = iso(today.add(const Duration(days: defaultExpiryDays)));
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < oldSessions.length; i++) {
      final s = oldSessions[i];
      final id = s['id'] as String;
      await db.insert('subjects', {
        'id': id,
        'name': s['name'],
        'expires_at': expiresAt,
        'created_at': nowMs,
        'ord': i,
      });
      final daysCsv = (s['days_csv'] as String? ?? '').trim();
      final days = daysCsv.isEmpty
          ? const <int>[]
          : daysCsv.split(',').map(int.parse).toList();
      for (final d in days) {
        await db.insert('subject_blocks', {
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
    await db.execute('DROP TABLE focus_sessions');
  }

  Future<void> close() async => db.close();

  /// Wipe and replace data with the given snapshot. Used by Import. Callers
  /// (backup.dart) are responsible for converting any legacy `focus_sessions`
  /// payload into the modern `subjects` + `subject_blocks` shape before passing
  /// it in: this method only knows the current schema.
  Future<void> replaceAll({
    required List<Map<String, Object?>> habits,
    required List<Map<String, Object?>> habitLogs,
    required List<Map<String, Object?>> timeBlocks,
    required List<Map<String, Object?>> subjects,
    required List<Map<String, Object?>> subjectBlocks,
    required Map<String, Object?> profile,
    required Map<String, Object?> settings,
  }) async {
    await db.transaction((txn) async {
      await txn.delete('habit_logs');
      await txn.delete('time_blocks');
      await txn.delete('subject_blocks');
      await txn.delete('subjects');
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
      for (final s in subjects) {
        await txn.insert('subjects', s);
      }
      for (final b in subjectBlocks) {
        await txn.insert('subject_blocks', b);
      }
      await txn.insert('profile', {...profile, 'id': 1});
      await txn.insert('settings', {...settings, 'id': 1});
    });
  }

  Future<Map<String, List<Map<String, Object?>>>> dumpForExport() async {
    final habits = await db.query('habits');
    final logs = await db.query('habit_logs');
    final blocks = await db.query('time_blocks');
    final subjects = await db.query('subjects');
    final subjectBlocks = await db.query('subject_blocks');
    final profileRows = await db.query('profile');
    final settingsRows = await db.query('settings');
    return {
      'habits': habits,
      'habit_logs': logs,
      'time_blocks': blocks,
      'subjects': subjects,
      'subject_blocks': subjectBlocks,
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
