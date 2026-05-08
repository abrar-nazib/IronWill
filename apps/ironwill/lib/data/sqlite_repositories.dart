import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../models/models.dart';
import '../models/utilization.dart';
import 'local_db.dart';
import 'repositories.dart';

const _dailyFocusFallback = 240;

Map<String, Object?> _decodeMetadata(String raw) {
  if (raw.isEmpty) return <String, Object?>{};
  try {
    final parsed = jsonDecode(raw);
    if (parsed is Map) return parsed.cast<String, Object?>();
  } catch (_) {}
  return <String, Object?>{};
}

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
      'metadata': jsonEncode(h.metadata),
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
        metadata: _decodeMetadata((row['metadata'] as String?) ?? '{}'),
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
      metadata: draft.metadata,
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
    // Field-cascade: when the user removes a tracking field from the habit,
    // strip its key from every historical habit_logs.metadata so the data
    // doesn't linger as orphan JSON. Adding a new field is a no-op for old
    // logs (they simply don't have the key); only delete cascades.
    final removed = _removedFieldKeys(h);
    await _ldb.db.update('habits', _habitToRow(h), where: 'id = ?', whereArgs: [h.id]);
    if (removed.isNotEmpty) {
      await _stripFieldKeysFromLogs(h.id, removed);
    }
    await _refresh();
    return _all.value.firstWhere((x) => x.id == h.id);
  }

  /// Set of field keys that existed on the previous version of [h] but are
  /// missing from the new metadata. Empty when the previous habit isn't
  /// known yet (first refresh) or when nothing was removed.
  Set<String> _removedFieldKeys(Habit h) {
    final prev = _all.value.where((x) => x.id == h.id);
    if (prev.isEmpty) return const <String>{};
    final oldKeys = parseHabitFields(prev.first.metadata).map((f) => f.key).toSet();
    final newKeys = parseHabitFields(h.metadata).map((f) => f.key).toSet();
    return oldKeys.difference(newKeys);
  }

  Future<void> _stripFieldKeysFromLogs(
      String habitId, Set<String> keys) async {
    if (keys.isEmpty) return;
    final rows = await _ldb.db.query(
      'habit_logs',
      where: 'habit_id = ?',
      whereArgs: [habitId],
    );
    final batch = _ldb.db.batch();
    for (final r in rows) {
      final dateIso = r['date_iso'] as String;
      final raw = (r['metadata'] as String?) ?? '{}';
      final decoded = _decodeMetadata(raw);
      var changed = false;
      for (final k in keys) {
        if (decoded.remove(k) != null) changed = true;
      }
      if (changed) {
        batch.update(
          'habit_logs',
          {'metadata': jsonEncode(decoded)},
          where: 'habit_id = ? AND date_iso = ?',
          whereArgs: [habitId, dateIso],
        );
      }
    }
    await batch.commit(noResult: true);
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
  Future<void> logToday(String habitId, Utilization u,
          {String note = '', Map<String, Object?> metadata = const {}}) =>
      logDay(habitId, _now(), u, note: note, metadata: metadata);

  @override
  Future<void> logDay(String habitId, DateTime day, Utilization u,
      {String note = '', Map<String, Object?> metadata = const {}}) async {
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
        {
          'habit_id': habitId,
          'date_iso': key,
          'utilization': u.index,
          'note': note,
          'metadata': jsonEncode(metadata),
        },
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
      metadata: _decodeMetadata((r['metadata'] as String?) ?? '{}'),
    );
  }

  /// Range query for the habit detail screen's per-field stats. Returns the
  /// last [days] daily logs (most recent first) including their structured
  /// metadata. Skips days with no log row.
  Future<List<HabitLog>> recentLogs(String habitId, int days) async {
    final today = truncate(_now());
    final from = today.subtract(Duration(days: days - 1));
    final rows = await _ldb.db.query(
      'habit_logs',
      where: 'habit_id = ? AND date_iso >= ?',
      whereArgs: [habitId, iso(from)],
      orderBy: 'date_iso DESC',
    );
    return rows
        .map((r) => HabitLog(
              day: parseIso(r['date_iso'] as String),
              utilization: Utilization.values[r['utilization'] as int],
              note: (r['note'] as String?) ?? '',
              metadata: _decodeMetadata((r['metadata'] as String?) ?? '{}'),
            ))
        .toList();
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

class SqliteSubjectsRepository implements SubjectsRepository {
  final LocalDb _ldb;
  final ValueNotifier<List<Subject>> _all = ValueNotifier<List<Subject>>([]);
  SqliteSubjectsRepository(this._ldb) {
    _refresh();
  }

  Future<void> _refresh() async {
    final subjectRows = await _ldb.db.query('subjects', orderBy: 'ord ASC');
    final blockRows = await _ldb.db.query('subject_blocks',
        orderBy: 'day_of_week ASC, start_hour ASC, start_minute ASC');
    final blocksBySubject = <String, List<SubjectBlock>>{};
    for (final br in blockRows) {
      final sid = br['subject_id'] as String;
      blocksBySubject.putIfAbsent(sid, () => <SubjectBlock>[]).add(SubjectBlock(
            id: br['id'] as String,
            subjectId: sid,
            dayOfWeek: br['day_of_week'] as int,
            start: TimeOfDay(
                hour: br['start_hour'] as int, minute: br['start_minute'] as int),
            end: TimeOfDay(
                hour: br['end_hour'] as int, minute: br['end_minute'] as int),
            pomodoroEnabled: (br['pomodoro_enabled'] as int) == 1,
            pomodoroPercent: br['pomodoro_percent'] as int,
          ));
    }
    _all.value = subjectRows
        .map((r) => Subject(
              id: r['id'] as String,
              name: r['name'] as String,
              expiresAt: parseIso(r['expires_at'] as String),
              createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
              order: r['ord'] as int,
              blocks: blocksBySubject[r['id'] as String] ?? const [],
            ))
        .toList();
  }

  @override
  ValueListenable<List<Subject>> get all => _all;
  @override
  Future<List<Subject>> listAll() async => _all.value;
  @override
  Future<Subject?> getById(String id) async {
    try { return _all.value.firstWhere((s) => s.id == id); } catch (_) { return null; }
  }

  @override
  Future<Subject> create(SubjectDraft draft) async {
    final id = 'subj_${DateTime.now().microsecondsSinceEpoch}';
    final orderRow = await _ldb.db.rawQuery('SELECT MAX(ord) AS m FROM subjects');
    final nextOrd = ((orderRow.first['m'] as int?) ?? -1) + 1;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _ldb.db.transaction((txn) async {
      await txn.insert('subjects', {
        'id': id,
        'name': draft.name.trim(),
        'expires_at': iso(draft.expiresAt),
        'created_at': nowMs,
        'ord': nextOrd,
      });
      for (var i = 0; i < draft.blocks.length; i++) {
        final b = draft.blocks[i];
        await txn.insert('subject_blocks', {
          'id': 'blk_${nowMs}_${i}_${b.dayOfWeek}',
          'subject_id': id,
          'day_of_week': b.dayOfWeek,
          'start_hour': b.start.hour,
          'start_minute': b.start.minute,
          'end_hour': b.end.hour,
          'end_minute': b.end.minute,
          'pomodoro_enabled': b.pomodoroEnabled ? 1 : 0,
          'pomodoro_percent': b.pomodoroPercent,
        });
      }
    });
    await _refresh();
    return _all.value.firstWhere((s) => s.id == id);
  }

  @override
  Future<Subject> update(Subject s) async {
    await _ldb.db.update('subjects', {
      'name': s.name.trim(),
      'expires_at': iso(s.expiresAt),
      'ord': s.order,
    }, where: 'id = ?', whereArgs: [s.id]);
    await _refresh();
    return _all.value.firstWhere((x) => x.id == s.id);
  }

  @override
  Future<void> delete(String id) async {
    // ON DELETE CASCADE on subject_blocks handles the children.
    await _ldb.db.delete('subjects', where: 'id = ?', whereArgs: [id]);
    await _refresh();
  }

  @override
  Future<SubjectBlock> addBlock(String subjectId, SubjectBlockDraft draft) async {
    final nowMs = DateTime.now().microsecondsSinceEpoch;
    final id = 'blk_${nowMs}_${draft.dayOfWeek}';
    await _ldb.db.insert('subject_blocks', {
      'id': id,
      'subject_id': subjectId,
      'day_of_week': draft.dayOfWeek,
      'start_hour': draft.start.hour,
      'start_minute': draft.start.minute,
      'end_hour': draft.end.hour,
      'end_minute': draft.end.minute,
      'pomodoro_enabled': draft.pomodoroEnabled ? 1 : 0,
      'pomodoro_percent': draft.pomodoroPercent,
    });
    await _refresh();
    return _all.value
        .firstWhere((s) => s.id == subjectId)
        .blocks
        .firstWhere((b) => b.id == id);
  }

  @override
  Future<SubjectBlock> updateBlock(SubjectBlock block) async {
    await _ldb.db.update('subject_blocks', {
      'day_of_week': block.dayOfWeek,
      'start_hour': block.start.hour,
      'start_minute': block.start.minute,
      'end_hour': block.end.hour,
      'end_minute': block.end.minute,
      'pomodoro_enabled': block.pomodoroEnabled ? 1 : 0,
      'pomodoro_percent': block.pomodoroPercent,
    }, where: 'id = ?', whereArgs: [block.id]);
    await _refresh();
    return block;
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    await _ldb.db.delete('subject_blocks', where: 'id = ?', whereArgs: [blockId]);
    await _refresh();
  }

  @override
  Future<Subject> repeatNextWeek(String subjectId) async {
    final s = await getById(subjectId);
    if (s == null) throw StateError('Subject $subjectId not found');
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    // If already-expired, set the new expiry relative to today; otherwise extend
    // from the current expiry so consecutive presses stack cleanly.
    final base = s.expiresAt.isBefore(todayDate) ? todayDate : s.expiresAt;
    final extended = base.add(Duration(days: LocalDb.defaultExpiryDays));
    return update(s.copyWith(expiresAt: extended));
  }
}

class SqliteStatsRepository implements StatsRepository {
  final HabitsRepository _habits;
  final TimeRepository _time;
  final ProfileRepository _profile;
  final SubjectsRepository _subjects;
  final DateTime Function() _now;
  final ValueNotifier<int> _focusStreakDays = ValueNotifier<int>(0);
  SqliteStatsRepository(
    this._habits,
    this._time,
    this._profile,
    this._subjects, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _time.today.addListener(_recomputeStreak);
    _profile.profile.addListener(_recomputeStreak);
    _recomputeStreak();
  }

  Future<void> _recomputeStreak() async {
    final p = await _profile.get();
    _focusStreakDays.value = await _focusStreak(p);
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
    final todaysTarget = profile.targetForToday(_now());
    return DashboardStats(
      focusMinutesToday: today.focusedMinutes,
      dailyFocusTarget: todaysTarget,
      focusStreakDays: await _focusStreak(profile),
      habitsDueToday: habits.length,
      habitsCompletedToday: completed,
    );
  }

  /// Walk back from today, comparing each day's focused minutes to that
  /// weekday's target. A 0-target day (rest day) auto-passes; the streak
  /// continues across it.
  Future<int> _focusStreak(UserProfile profile) async {
    final today = truncate(_now());
    int streak = 0;
    for (int back = 0; back < 365; back++) {
      final d = today.subtract(Duration(days: back));
      final day = await _time.getDay(d);
      final target = profile.targetForWeekday(d.weekday);
      if (target == 0) {
        // Rest day: doesn't break the streak, doesn't add to it either.
        continue;
      }
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

    // Best / worst day indices.
    var bestIdx = -1;
    var bestMin = -1;
    var worstIdx = -1;
    var worstMin = 1 << 30;
    for (var i = 0; i < mins.length; i++) {
      final m = mins[i];
      if (m > bestMin) {
        bestMin = m;
        bestIdx = i;
      }
      if (m > 0 && m < worstMin) {
        worstMin = m;
        worstIdx = i;
      }
    }
    if (bestMin == 0) bestIdx = -1;

    // Per-day target hit rate.
    final profile = await _profile.get();
    var goalHit = 0;
    var evaluated = 0;
    for (var i = 0; i < days.length; i++) {
      final target = profile.targetForWeekday(days[i].date.weekday);
      if (target <= 0) continue;
      evaluated++;
      if (mins[i] >= target) goalHit++;
    }

    // Average utilization of logged blocks.
    var pctSum = 0;
    var pctCount = 0;
    for (final d in days) {
      for (final q in d.quarters) {
        final p = q.percent;
        if (p != null) {
          pctSum += p;
          pctCount++;
        }
      }
    }
    final avgUtil = pctCount == 0 ? 0 : (pctSum / pctCount).round();

    // Minutes per hour-of-day (24 ints). 100% quarter = 15 min, 75% = 11.25,
    // etc. Sum across all 7 days.
    final hourly = List<int>.filled(24, 0);
    for (final d in days) {
      for (var q = 0; q < d.quarters.length; q++) {
        final p = d.quarters[q].percent;
        if (p == null) continue;
        final hour = q ~/ 4;
        hourly[hour] += (p * 15 / 100).round();
      }
    }

    // Unlogged focus quarters: quarters that fell in a scheduled block but
    // were never stamped. Pull subjects to find scheduled windows.
    final allSubjects = await _subjects.listAll();
    final blocksByDow = <int, List<({int startQ, int endQ})>>{};
    for (final s in allSubjects) {
      for (final b in s.blocks) {
        final startQ = b.startMinute ~/ 15;
        final endQ = b.endMinute ~/ 15;
        (blocksByDow[b.dayOfWeek] ??= []).add((startQ: startQ, endQ: endQ));
      }
    }
    var unlogged = 0;
    for (final d in days) {
      final ranges = blocksByDow[d.date.weekday] ?? const [];
      for (final r in ranges) {
        for (var q = r.startQ; q < r.endQ && q < 96; q++) {
          if (d.quarters[q] == Utilization.none) unlogged++;
        }
      }
    }

    // Per-habit hit / evaluated rows for the period (last 7 days).
    final habitRows = <HabitWeeklyRow>[];
    for (final h in habits) {
      var hit = 0;
      var seen = 0;
      // last90 is indexed 0..89 oldest..newest. Take the last 7.
      for (var i = h.last90.length - 7; i < h.last90.length; i++) {
        final v = h.last90[i];
        if (v == Utilization.none || v == Utilization.notFocus) continue;
        seen++;
        if (v == Utilization.full || v == Utilization.good) hit++;
      }
      habitRows.add(HabitWeeklyRow(
        id: h.id,
        name: h.name,
        glyph: h.glyph,
        hitDays: hit,
        evaluatedDays: seen,
        currentStreak: h.currentStreak,
      ));
    }

    return WeeklyStats(
      focusMinutesByDay: mins,
      days: days,
      totalFocusMinutes: total,
      avgPerDay: total ~/ days.length,
      avgHabitCompletion: avgCompletion,
      bestDayIndex: bestIdx,
      worstDayIndex: worstIdx,
      goalHitDays: goalHit,
      evaluatedTargetDays: evaluated,
      avgUtilizationPct: avgUtil,
      hourlyMinutes: hourly,
      unloggedFocusQuarters: unlogged,
      habitRows: habitRows,
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
    final csv = r['weekly_focus_minutes_csv'] as String? ?? LocalDb.defaultWeeklyFocusCsv;
    final daily =
        r['daily_focus_minutes_target'] as int? ?? _dailyFocusFallback;
    _state.value = UserProfile(
      name: r['name'] as String,
      weeklyFocusMinutes: _parseWeeklyCsv(csv, fallback: daily),
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
    final csv = p.weeklyFocusMinutes.length == 7
        ? p.weeklyFocusMinutes.join(',')
        : LocalDb.defaultWeeklyFocusCsv;
    // Keep the legacy `daily_focus_minutes_target` column populated as the
    // max of the weekly schedule. It's no longer the source of truth, but old
    // exports / external readers may still inspect it.
    final legacyDaily = p.weeklyFocusMinutes.fold<int>(0, (a, b) => a > b ? a : b);
    await _ldb.db.update('profile', {
      'name': p.name,
      'weekly_focus_minutes_csv': csv,
      'daily_focus_minutes_target': legacyDaily == 0 ? _dailyFocusFallback : legacyDaily,
      'focus_streak_days': p.focusStreakDays,
      'avatar_letter': p.avatarLetter,
      'timezone': p.timezone,
    }, where: 'id = ?', whereArgs: [1]);
    await _refresh();
  }
}

/// Parse the `weekly_focus_minutes_csv` column. Falls back to a 7-element
/// list of [fallback] minutes if the CSV is malformed (e.g. legacy export
/// shape that didn't include the column at all).
List<int> _parseWeeklyCsv(String csv, {required int fallback}) {
  final parts = csv.split(',').map((s) => int.tryParse(s.trim()) ?? -1).toList();
  if (parts.length != 7 || parts.any((v) => v < 0)) {
    return List<int>.filled(7, fallback);
  }
  return parts.map((v) => v.clamp(0, 1440)).toList();
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
      blockSizeMinutes: r['block_size_minutes'] as int? ?? 30,
      pomodoroEnabled: ((r['pomodoro_enabled'] as int?) ?? 0) == 1,
      pomodoroPercent: r['pomodoro_percent'] as int? ?? 15,
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
      'block_size_minutes': s.blockSizeMinutes,
      'pomodoro_enabled': s.pomodoroEnabled ? 1 : 0,
      'pomodoro_percent': s.pomodoroPercent,
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
