import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/models.dart';
import '../models/utilization.dart';
import 'local_db.dart';
import 'repositories.dart';

const _dailyFocusFallback = 240;

HabitCadence _cadenceFromString(String s) =>
    HabitCadence.values.firstWhere((c) => c.name == s, orElse: () => HabitCadence.daily);

FirstDayOfWeek _firstDayFromString(String s) =>
    FirstDayOfWeek.values.firstWhere((c) => c.name == s, orElse: () => FirstDayOfWeek.monday);

AlarmSound _alarmFromString(String s) =>
    AlarmSound.values.firstWhere((c) => c.name == s, orElse: () => AlarmSound.softChime);

ThemeChoice _themeFromString(String s) =>
    ThemeChoice.values.firstWhere((c) => c.name == s, orElse: () => ThemeChoice.system);

IconData _glyph(int codepoint, String? family, String? package) =>
    IconData(codepoint, fontFamily: family, fontPackage: package);

Map<String, Object?> _habitToRow(Habit h) => {
      'id': h.id,
      'name': h.name,
      'description': h.description,
      'cadence': h.cadence.name,
      'custom_days': h.customDays.join(','),
      'glyph_codepoint': h.glyph.codePoint,
      'glyph_font_family': h.glyph.fontFamily,
      'glyph_font_package': h.glyph.fontPackage,
      'reminder_hour': h.reminder.hour,
      'reminder_minute': h.reminder.minute,
      'reminder_on': h.reminderOn ? 1 : 0,
      'archived': h.archived ? 1 : 0,
      'ord': h.order,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    };

class SqliteHabitsRepository implements HabitsRepository {
  final LocalDb _ldb;
  final ValueNotifier<List<Habit>> _all = ValueNotifier<List<Habit>>([]);
  final ValueNotifier<List<Habit>> _active = ValueNotifier<List<Habit>>([]);
  final DateTime Function() _now;

  SqliteHabitsRepository(this._ldb, {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _refresh();
  }

  Future<void> _refresh() async {
    final rows = await _ldb.db.query('habits', orderBy: 'archived ASC, ord ASC');
    final today = truncate(_now());
    final List<Habit> built = [];
    for (final row in rows) {
      final id = row['id'] as String;
      final logs = await _ldb.db.query(
        'habit_logs',
        where: 'habit_id = ?',
        whereArgs: [id],
        orderBy: 'date_iso ASC',
      );
      final logMap = {
        for (final l in logs) l['date_iso'] as String: l['utilization'] as int,
      };
      final last90 = List<Utilization>.generate(90, (i) {
        final d = today.subtract(Duration(days: 89 - i));
        final v = logMap[iso(d)];
        return v == null ? Utilization.none : Utilization.values[v];
      });
      final stats = _computeStreaks(last90);
      built.add(Habit(
        id: id,
        name: row['name'] as String,
        description: (row['description'] as String?) ?? '',
        cadence: _cadenceFromString(row['cadence'] as String),
        customDays: ((row['custom_days'] as String?) ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList(),
        glyph: _glyph(
          row['glyph_codepoint'] as int,
          row['glyph_font_family'] as String?,
          row['glyph_font_package'] as String?,
        ),
        reminder: TimeOfDay(
          hour: row['reminder_hour'] as int,
          minute: row['reminder_minute'] as int,
        ),
        reminderOn: (row['reminder_on'] as int) == 1,
        currentStreak: stats.current,
        bestStreak: stats.best,
        completionRate: stats.completion,
        last90: last90,
        archived: (row['archived'] as int) == 1,
        order: row['ord'] as int,
      ));
    }
    _all.value = built;
    _active.value = built.where((h) => !h.archived).toList();
  }

  _StreakStats _computeStreaks(List<Utilization> last90) {
    int current = 0;
    int best = 0;
    int run = 0;
    int success = 0;
    int evaluated = 0;
    bool foundFirstResult = false;
    for (int i = last90.length - 1; i >= 0; i--) {
      final v = last90[i];
      if (v == Utilization.none) {
        if (i == last90.length - 1) continue; // unlogged today does not break streak
        run = 0;
        continue;
      }
      evaluated++;
      final ok = v == Utilization.full || v == Utilization.good;
      if (ok) {
        success++;
        run++;
        if (!foundFirstResult) {
          current = run;
        } else {
          current = run > current ? run : current;
        }
      } else {
        if (!foundFirstResult) current = run;
        run = 0;
      }
      foundFirstResult = true;
      if (run > best) best = run;
    }
    final completion = evaluated == 0 ? 0 : ((success / evaluated) * 100).round();
    // Streak rule: showing up beats scoring perfectly. Any logged level except
    // "Missed" (wasted) counts. "Skip day" (notFocus) is neutral. An unlogged
    // past day breaks the streak; today unlogged is still fine.
    int cleanCurrent = 0;
    for (int i = last90.length - 1; i >= 0; i--) {
      final v = last90[i];
      if (v == Utilization.none) {
        if (i == last90.length - 1) continue;
        break;
      }
      if (v == Utilization.wasted) break;
      if (v == Utilization.notFocus) continue;
      cleanCurrent++;
    }
    return _StreakStats(current: cleanCurrent, best: best, completion: completion);
  }

  @override
  ValueListenable<List<Habit>> get all => _all;
  @override
  ValueListenable<List<Habit>> get active => _active;

  @override
  Future<List<Habit>> listAll() async => _all.value;
  @override
  Future<List<Habit>> listActive() async => _active.value;
  @override
  Future<List<Habit>> listArchived() async =>
      _all.value.where((h) => h.archived).toList();

  @override
  Future<Habit?> getById(String id) async {
    try {
      return _all.value.firstWhere((h) => h.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Habit> create(HabitDraft draft) async {
    final id = 'h${DateTime.now().microsecondsSinceEpoch}';
    final orderRow = await _ldb.db.rawQuery('SELECT MAX(ord) AS m FROM habits');
    final nextOrd = ((orderRow.first['m'] as int?) ?? -1) + 1;
    final h = Habit(
      id: id,
      name: draft.name,
      description: draft.description,
      cadence: draft.cadence,
      customDays: draft.customDays,
      glyph: draft.glyph,
      reminder: draft.reminder,
      reminderOn: draft.reminderOn,
      currentStreak: 0,
      bestStreak: 0,
      completionRate: 0,
      last90: List.filled(90, Utilization.none),
      order: nextOrd,
    );
    await _ldb.db.insert('habits', _habitToRow(h));
    await _refresh();
    return _all.value.firstWhere((x) => x.id == id);
  }

  @override
  Future<Habit> update(Habit h) async {
    await _ldb.db.update('habits', _habitToRow(h), where: 'id = ?', whereArgs: [h.id]);
    await _refresh();
    return _all.value.firstWhere((x) => x.id == h.id);
  }

  @override
  Future<void> archive(String id) async {
    await _ldb.db.update('habits', {'archived': 1}, where: 'id = ?', whereArgs: [id]);
    await _refresh();
  }

  @override
  Future<void> unarchive(String id) async {
    await _ldb.db.update('habits', {'archived': 0}, where: 'id = ?', whereArgs: [id]);
    await _refresh();
  }

  @override
  Future<void> reorder(List<String> ids) async {
    final batch = _ldb.db.batch();
    for (int i = 0; i < ids.length; i++) {
      batch.update('habits', {'ord': i}, where: 'id = ?', whereArgs: [ids[i]]);
    }
    await batch.commit(noResult: true);
    await _refresh();
  }

  @override
  Future<void> logToday(String habitId, Utilization u, {String note = ''}) =>
      logDay(habitId, _now(), u, note: note);

  @override
  Future<void> logDay(String habitId, DateTime day, Utilization u, {String note = ''}) async {
    final key = iso(truncate(day));
    if (u == Utilization.none) {
      await _ldb.db.delete(
        'habit_logs',
        where: 'habit_id = ? AND date_iso = ?',
        whereArgs: [habitId, key],
      );
    } else {
      await _ldb.db.insert(
        'habit_logs',
        {'habit_id': habitId, 'date_iso': key, 'utilization': u.index, 'note': note},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _refresh();
  }

  @override
  Future<HabitLog?> getLog(String habitId, DateTime day) async {
    final key = iso(truncate(day));
    final rows = await _ldb.db.query(
      'habit_logs',
      where: 'habit_id = ? AND date_iso = ?',
      whereArgs: [habitId, key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return HabitLog(
      day: parseIso(r['date_iso'] as String),
      utilization: Utilization.values[r['utilization'] as int],
      note: (r['note'] as String?) ?? '',
    );
  }
}

class _StreakStats {
  final int current;
  final int best;
  final int completion;
  const _StreakStats({required this.current, required this.best, required this.completion});
}

class SqliteTimeRepository implements TimeRepository {
  final LocalDb _ldb;
  final DateTime Function() _now;
  final ValueNotifier<DayBlocks> _today;

  SqliteTimeRepository(this._ldb, {DateTime Function()? now})
      : _now = now ?? DateTime.now,
        _today = ValueNotifier<DayBlocks>(
          DayBlocks(date: truncate((now ?? DateTime.now)()), quarters: List.filled(96, Utilization.none)),
        ) {
    _refresh();
  }

  Future<void> _refresh() async {
    final today = truncate(_now());
    _today.value = await getDay(today);
  }

  @override
  ValueListenable<DayBlocks> get today => _today;

  @override
  Future<DayBlocks> getDay(DateTime date) async {
    final key = iso(truncate(date));
    final rows = await _ldb.db.query(
      'time_blocks',
      where: 'date_iso = ?',
      whereArgs: [key],
    );
    final out = List<Utilization>.filled(96, Utilization.none);
    for (final r in rows) {
      final q = r['quarter'] as int;
      final u = r['utilization'] as int;
      if (q >= 0 && q < 96) out[q] = Utilization.values[u];
    }
    return DayBlocks(date: truncate(date), quarters: out);
  }

  @override
  Future<List<DayBlocks>> getRange(DateTime start, DateTime endInclusive) async {
    final out = <DayBlocks>[];
    var d = truncate(start);
    final end = truncate(endInclusive);
    while (!d.isAfter(end)) {
      out.add(await getDay(d));
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  @override
  Future<void> logQuarter(DateTime date, int quarterIndex, Utilization u) async {
    final key = iso(truncate(date));
    if (u == Utilization.none) {
      await _ldb.db.delete(
        'time_blocks',
        where: 'date_iso = ? AND quarter = ?',
        whereArgs: [key, quarterIndex],
      );
    } else {
      await _ldb.db.insert(
        'time_blocks',
        {'date_iso': key, 'quarter': quarterIndex, 'utilization': u.index},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    if (truncate(date) == truncate(_now())) {
      _today.value = await getDay(truncate(_now()));
    }
  }
}

class SqliteFocusSessionsRepository implements FocusSessionsRepository {
  final LocalDb _ldb;
  final ValueNotifier<List<FocusSession>> _all = ValueNotifier<List<FocusSession>>([]);
  SqliteFocusSessionsRepository(this._ldb) {
    _refresh();
  }

  Future<void> _refresh() async {
    final rows = await _ldb.db.query('focus_sessions', orderBy: 'start_hour, start_minute');
    _all.value = rows
        .map((r) => FocusSession(
              id: r['id'] as String,
              name: r['name'] as String,
              start: TimeOfDay(hour: r['start_hour'] as int, minute: r['start_minute'] as int),
              end: TimeOfDay(hour: r['end_hour'] as int, minute: r['end_minute'] as int),
              daysOfWeek: ((r['days_csv'] as String?) ?? '')
                  .split(',')
                  .where((s) => s.isNotEmpty)
                  .map(int.parse)
                  .toList(),
              quarters: List.filled(0, Utilization.none),
            ))
        .toList();
  }

  @override
  ValueListenable<List<FocusSession>> get all => _all;
  @override
  Future<List<FocusSession>> listAll() async => _all.value;
  @override
  Future<FocusSession?> getById(String id) async {
    try { return _all.value.firstWhere((s) => s.id == id); } catch (_) { return null; }
  }

  @override
  Future<FocusSession> create(FocusSessionDraft draft) async {
    final id = 's${DateTime.now().microsecondsSinceEpoch}';
    await _ldb.db.insert('focus_sessions', {
      'id': id,
      'name': draft.name,
      'start_hour': draft.start.hour,
      'start_minute': draft.start.minute,
      'end_hour': draft.end.hour,
      'end_minute': draft.end.minute,
      'days_csv': draft.daysOfWeek.join(','),
    });
    await _refresh();
    return _all.value.firstWhere((s) => s.id == id);
  }

  @override
  Future<FocusSession> update(FocusSession s) async {
    await _ldb.db.update('focus_sessions', {
      'name': s.name,
      'start_hour': s.start.hour,
      'start_minute': s.start.minute,
      'end_hour': s.end.hour,
      'end_minute': s.end.minute,
      'days_csv': s.daysOfWeek.join(','),
    }, where: 'id = ?', whereArgs: [s.id]);
    await _refresh();
    return s;
  }

  @override
  Future<void> delete(String id) async {
    await _ldb.db.delete('focus_sessions', where: 'id = ?', whereArgs: [id]);
    await _refresh();
  }
}

class SqliteStatsRepository implements StatsRepository {
  final HabitsRepository _habits;
  final TimeRepository _time;
  final ProfileRepository _profile;
  final DateTime Function() _now;
  final ValueNotifier<int> _focusStreakDays = ValueNotifier<int>(0);
  SqliteStatsRepository(
    this._habits,
    this._time,
    this._profile, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _time.today.addListener(_recomputeStreak);
    _profile.profile.addListener(_recomputeStreak);
    _recomputeStreak();
  }

  Future<void> _recomputeStreak() async {
    final p = await _profile.get();
    _focusStreakDays.value = await _focusStreak(p.dailyFocusMinutesTarget);
  }

  @override
  ValueListenable<int> get focusStreakDays => _focusStreakDays;

  @override
  Future<DashboardStats> getDashboard() async {
    final today = await _time.getDay(_now());
    final habits = await _habits.listActive();
    final completed = habits.where((h) {
      final t = h.last90.last;
      return t == Utilization.full || t == Utilization.good;
    }).length;
    final profile = await _profile.get();
    return DashboardStats(
      focusMinutesToday: today.focusedMinutes,
      dailyFocusTarget: profile.dailyFocusMinutesTarget,
      focusStreakDays: await _focusStreak(profile.dailyFocusMinutesTarget),
      habitsDueToday: habits.length,
      habitsCompletedToday: completed,
    );
  }

  Future<int> _focusStreak(int target) async {
    final today = truncate(_now());
    int streak = 0;
    for (int back = 0; back < 365; back++) {
      final d = today.subtract(Duration(days: back));
      final day = await _time.getDay(d);
      if (back == 0 && day.focusedMinutes < target) {
        // skip today if we have not earned it yet
        continue;
      }
      if (day.focusedMinutes >= target) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  @override
  Future<WeeklyStats> getWeekly() async {
    final today = truncate(_now());
    final days = <DayBlocks>[];
    for (int i = 6; i >= 0; i--) {
      days.add(await _time.getDay(today.subtract(Duration(days: i))));
    }
    final mins = days.map((d) => d.focusedMinutes).toList();
    final total = mins.fold<int>(0, (a, b) => a + b);
    final habits = await _habits.listActive();
    final avgCompletion = habits.isEmpty
        ? 0
        : (habits.fold<int>(0, (a, h) => a + h.completionRate) ~/ habits.length);
    return WeeklyStats(
      focusMinutesByDay: mins,
      days: days,
      totalFocusMinutes: total,
      avgPerDay: total ~/ days.length,
      avgHabitCompletion: avgCompletion,
    );
  }
}

class SqliteProfileRepository implements ProfileRepository {
  final LocalDb _ldb;
  final ValueNotifier<UserProfile> _state =
      ValueNotifier<UserProfile>(const UserProfile(name: 'You'));
  SqliteProfileRepository(this._ldb) {
    _refresh();
  }

  Future<void> _refresh() async {
    final rows = await _ldb.db.query('profile', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return;
    final r = rows.first;
    _state.value = UserProfile(
      name: r['name'] as String,
      dailyFocusMinutesTarget: r['daily_focus_minutes_target'] as int? ?? _dailyFocusFallback,
      focusStreakDays: r['focus_streak_days'] as int? ?? 0,
      avatarLetter: r['avatar_letter'] as String?,
      timezone: r['timezone'] as String? ?? 'Local',
    );
  }

  @override
  ValueListenable<UserProfile> get profile => _state;

  @override
  Future<UserProfile> get() async => _state.value;

  @override
  Future<void> update(UserProfile p) async {
    await _ldb.db.update('profile', {
      'name': p.name,
      'daily_focus_minutes_target': p.dailyFocusMinutesTarget,
      'focus_streak_days': p.focusStreakDays,
      'avatar_letter': p.avatarLetter,
      'timezone': p.timezone,
    }, where: 'id = ?', whereArgs: [1]);
    await _refresh();
  }
}

class SqliteSettingsRepository implements SettingsRepository {
  final LocalDb _ldb;
  final ValueNotifier<AppSettings> _state =
      ValueNotifier<AppSettings>(const AppSettings());
  SqliteSettingsRepository(this._ldb) {
    _refresh();
  }

  Future<void> _refresh() async {
    final rows = await _ldb.db.query('settings', where: 'id = ?', whereArgs: [1]);
    if (rows.isEmpty) return;
    final r = rows.first;
    _state.value = AppSettings(
      firstDay: _firstDayFromString(r['first_day'] as String? ?? 'monday'),
      alarm: _alarmFromString(r['alarm_sound'] as String? ?? 'softChime'),
      reminderLogging: ((r['reminder_logging'] as int?) ?? 1) == 1,
      dailyFocusMinutes: r['daily_focus_minutes'] as int? ?? 240,
      privacyLockOn: ((r['privacy_lock_on'] as int?) ?? 0) == 1,
      themeMode: _themeFromString(r['theme_mode'] as String? ?? 'system'),
      onboarded: ((r['onboarded'] as int?) ?? 0) == 1,
    );
  }

  @override
  ValueListenable<AppSettings> get settings => _state;

  @override
  Future<AppSettings> get() async => _state.value;

  @override
  Future<void> update(AppSettings s) async {
    await _ldb.db.update('settings', {
      'first_day': s.firstDay.name,
      'alarm_sound': s.alarm.name,
      'reminder_logging': s.reminderLogging ? 1 : 0,
      'daily_focus_minutes': s.dailyFocusMinutes,
      'privacy_lock_on': s.privacyLockOn ? 1 : 0,
      'theme_mode': s.themeMode.name,
      'onboarded': s.onboarded ? 1 : 0,
    }, where: 'id = ?', whereArgs: [1]);
    await _refresh();
  }
}

/// Seed the database. We deliberately do NOT seed habits or focus sessions on
/// first run. The user creates those during onboarding.
Future<void> seedIfFirstRun(LocalDb ldb) async {
  // No-op for now; profile + settings rows are created in onCreate.
  // If the unused import warning becomes a problem later, drop the lucide import.
  // ignore: unused_local_variable
  final _ = LucideIcons.snowflake;
}
