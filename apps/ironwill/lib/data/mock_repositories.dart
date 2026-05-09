import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/utilization.dart';
import 'mock_db.dart';
import 'repositories.dart';

DateTime _truncate(DateTime d) => DateTime(d.year, d.month, d.day);

const Duration _ioLatency = Duration(milliseconds: 30);

class MockHabitsRepository implements HabitsRepository {
  final MockDb _db;
  final ValueNotifier<List<Habit>> _all;
  final ValueNotifier<List<Habit>> _active;

  MockHabitsRepository(this._db)
      : _all = ValueNotifier<List<Habit>>(_sortByOrder(_db.habits.values.toList())),
        _active = ValueNotifier<List<Habit>>(
            _sortByOrder(_db.habits.values.where((h) => !h.archived).toList()));

  static List<Habit> _sortByOrder(List<Habit> list) {
    final out = [...list];
    out.sort((a, b) => a.order.compareTo(b.order));
    return out;
  }

  void _publish() {
    _all.value = _sortByOrder(_db.habits.values.toList());
    _active.value = _sortByOrder(_db.habits.values.where((h) => !h.archived).toList());
  }

  @override
  ValueListenable<List<Habit>> get all => _all;

  @override
  ValueListenable<List<Habit>> get active => _active;

  @override
  Future<List<Habit>> listAll() async {
    await Future.delayed(_ioLatency);
    return _all.value;
  }

  @override
  Future<List<Habit>> listActive() async {
    await Future.delayed(_ioLatency);
    return _active.value;
  }

  @override
  Future<List<Habit>> listArchived() async {
    await Future.delayed(_ioLatency);
    return _db.habits.values.where((h) => h.archived).toList();
  }

  @override
  Future<Habit?> getById(String id) async {
    await Future.delayed(_ioLatency);
    return _db.habits[id];
  }

  @override
  Future<Habit> create(HabitDraft draft) async {
    await Future.delayed(_ioLatency);
    final id = 'h${DateTime.now().microsecondsSinceEpoch}';
    final order = _db.habits.values.fold<int>(-1, (a, h) => h.order > a ? h.order : a) + 1;
    final h = Habit(
      id: id,
      name: draft.name,
      cadence: draft.cadence,
      customDays: draft.customDays,
      glyph: draft.glyph,
      reminder: draft.reminder,
      reminderOn: draft.reminderOn,
      currentStreak: 0,
      bestStreak: 0,
      completionRate: 0,
      last90: List<Utilization>.filled(90, Utilization.none),
      order: order,
    );
    _db.habits[id] = h;
    _publish();
    return h;
  }

  @override
  Future<Habit> update(Habit h) async {
    await Future.delayed(_ioLatency);
    _db.habits[h.id] = h;
    _publish();
    return h;
  }

  @override
  Future<void> archive(String id) async {
    await Future.delayed(_ioLatency);
    final h = _db.habits[id];
    if (h == null) return;
    _db.habits[id] = h.copyWith(archived: true);
    _publish();
  }

  @override
  Future<void> unarchive(String id) async {
    await Future.delayed(_ioLatency);
    final h = _db.habits[id];
    if (h == null) return;
    _db.habits[id] = h.copyWith(archived: false);
    _publish();
  }

  @override
  Future<void> reorder(List<String> ids) async {
    await Future.delayed(_ioLatency);
    for (int i = 0; i < ids.length; i++) {
      final h = _db.habits[ids[i]];
      if (h != null) _db.habits[ids[i]] = h.copyWith(order: i);
    }
    _publish();
  }

  @override
  Future<void> logToday(String habitId, Utilization u,
      {String note = '', Map<String, Object?> metadata = const {}}) async {
    await Future.delayed(_ioLatency);
    final h = _db.habits[habitId];
    if (h == null) return;
    final l = [...h.last90];
    l[l.length - 1] = u;
    final newStreak = (u == Utilization.full || u == Utilization.good)
        ? h.currentStreak + 1
        : 0;
    _db.habits[habitId] = h.copyWith(
      last90: l,
      currentStreak: newStreak,
      bestStreak: newStreak > h.bestStreak ? newStreak : h.bestStreak,
    );
    _publish();
  }

  @override
  Future<void> logDay(String habitId, DateTime day, Utilization u,
      {String note = '', Map<String, Object?> metadata = const {}}) async {
    await Future.delayed(_ioLatency);
    final h = _db.habits[habitId];
    if (h == null) return;
    final daysAgo = _db.today.difference(_truncate(day)).inDays;
    if (daysAgo < 0 || daysAgo >= 90) return;
    final l = [...h.last90];
    l[89 - daysAgo] = u;
    _db.habits[habitId] = h.copyWith(last90: l);
    _publish();
  }

  @override
  Future<HabitLog?> getLog(String habitId, DateTime day) async => null;
}

class MockTimeRepository implements TimeRepository {
  final MockDb _db;
  final ValueNotifier<DayBlocks> _today;

  MockTimeRepository(this._db)
      : _today = ValueNotifier(_db.days[_db.today]!);

  @override
  ValueListenable<DayBlocks> get today => _today;

  @override
  Future<DayBlocks> getDay(DateTime date) async {
    await Future.delayed(_ioLatency);
    final key = _truncate(date);
    return _db.days[key] ??
        DayBlocks(date: key, quarters: List<Utilization>.filled(96, Utilization.none));
  }

  @override
  Future<List<DayBlocks>> getRange(DateTime start, DateTime endInclusive) async {
    await Future.delayed(_ioLatency);
    final out = <DayBlocks>[];
    var d = _truncate(start);
    final last = _truncate(endInclusive);
    while (!d.isAfter(last)) {
      out.add(_db.days[d] ??
          DayBlocks(date: d, quarters: List<Utilization>.filled(96, Utilization.none)));
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  @override
  Future<void> logQuarter(DateTime date, int quarterIndex, Utilization u) async {
    await Future.delayed(_ioLatency);
    final key = _truncate(date);
    final cur = _db.days[key] ??
        DayBlocks(date: key, quarters: List<Utilization>.filled(96, Utilization.none));
    final q = [...cur.quarters];
    q[quarterIndex] = u;
    final updated = DayBlocks(date: key, quarters: q);
    _db.days[key] = updated;
    if (key == _db.today) {
      _today.value = updated;
    }
  }
}

class MockSubjectsRepository implements SubjectsRepository {
  final MockDb _db;
  final ValueNotifier<List<Subject>> _all;

  MockSubjectsRepository(this._db)
      : _all = ValueNotifier(List<Subject>.from(_db.subjects));

  void _publish() => _all.value = List<Subject>.from(_db.subjects);

  @override
  ValueListenable<List<Subject>> get all => _all;

  @override
  Future<List<Subject>> listAll() async {
    await Future.delayed(_ioLatency);
    return _all.value;
  }

  @override
  Future<Subject?> getById(String id) async {
    await Future.delayed(_ioLatency);
    return _all.value.cast<Subject?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
  }

  @override
  Future<Subject> create(SubjectDraft draft) async {
    await Future.delayed(_ioLatency);
    final id = 'subj_${DateTime.now().microsecondsSinceEpoch}';
    final blocks = <SubjectBlock>[
      for (var i = 0; i < draft.blocks.length; i++)
        SubjectBlock(
          id: 'blk_${DateTime.now().microsecondsSinceEpoch}_$i',
          subjectId: id,
          dayOfWeek: draft.blocks[i].dayOfWeek,
          start: draft.blocks[i].start,
          end: draft.blocks[i].end,
          pomodoroEnabled: draft.blocks[i].pomodoroEnabled,
          pomodoroPercent: draft.blocks[i].pomodoroPercent,
        ),
    ];
    final s = Subject(
      id: id,
      name: draft.name,
      expiresAt: draft.expiresAt,
      createdAt: DateTime.now(),
      order: _db.subjects.length,
      blocks: blocks,
    );
    _db.subjects.add(s);
    _publish();
    return s;
  }

  @override
  Future<Subject> update(Subject s) async {
    await Future.delayed(_ioLatency);
    final idx = _db.subjects.indexWhere((x) => x.id == s.id);
    if (idx >= 0) {
      // Preserve existing blocks; update mutates only subject-level fields.
      _db.subjects[idx] = s.copyWith(blocks: _db.subjects[idx].blocks);
      _publish();
    }
    return s;
  }

  @override
  Future<void> delete(String id) async {
    await Future.delayed(_ioLatency);
    _db.subjects.removeWhere((s) => s.id == id);
    _publish();
  }

  @override
  Future<SubjectBlock> addBlock(String subjectId, SubjectBlockDraft draft) async {
    await Future.delayed(_ioLatency);
    final idx = _db.subjects.indexWhere((s) => s.id == subjectId);
    if (idx < 0) throw StateError('Subject $subjectId not found');
    final id = 'blk_${DateTime.now().microsecondsSinceEpoch}';
    final block = SubjectBlock(
      id: id,
      subjectId: subjectId,
      dayOfWeek: draft.dayOfWeek,
      start: draft.start,
      end: draft.end,
      pomodoroEnabled: draft.pomodoroEnabled,
      pomodoroPercent: draft.pomodoroPercent,
    );
    final next = [..._db.subjects[idx].blocks, block];
    _db.subjects[idx] = _db.subjects[idx].copyWith(blocks: next);
    _publish();
    return block;
  }

  @override
  Future<SubjectBlock> updateBlock(SubjectBlock block) async {
    await Future.delayed(_ioLatency);
    final si = _db.subjects.indexWhere((s) => s.id == block.subjectId);
    if (si < 0) return block;
    final blocks = [..._db.subjects[si].blocks];
    final bi = blocks.indexWhere((b) => b.id == block.id);
    if (bi >= 0) blocks[bi] = block;
    _db.subjects[si] = _db.subjects[si].copyWith(blocks: blocks);
    _publish();
    return block;
  }

  @override
  Future<void> deleteBlock(String blockId) async {
    await Future.delayed(_ioLatency);
    for (var i = 0; i < _db.subjects.length; i++) {
      final blocks = _db.subjects[i].blocks.where((b) => b.id != blockId).toList();
      if (blocks.length != _db.subjects[i].blocks.length) {
        _db.subjects[i] = _db.subjects[i].copyWith(blocks: blocks);
      }
    }
    _publish();
  }

  @override
  Future<Subject> repeatNextWeek(String subjectId) async {
    await Future.delayed(_ioLatency);
    final idx = _db.subjects.indexWhere((s) => s.id == subjectId);
    if (idx < 0) throw StateError('Subject $subjectId not found');
    final s = _db.subjects[idx];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final base = s.expiresAt.isBefore(todayDate) ? todayDate : s.expiresAt;
    final extended = s.copyWith(expiresAt: base.add(const Duration(days: 7)));
    _db.subjects[idx] = extended;
    _publish();
    return extended;
  }
}

class MockStatsRepository implements StatsRepository {
  final MockDb _db;
  late final ValueNotifier<int> _focusStreakDays =
      ValueNotifier<int>(_db.profile.focusStreakDays);
  MockStatsRepository(this._db);

  @override
  ValueListenable<int> get focusStreakDays => _focusStreakDays;

  @override
  Future<DashboardStats> getDashboard() async {
    await Future.delayed(_ioLatency);
    final today = _db.days[_db.today]!;
    final activeHabits = _db.habits.values.where((h) => !h.archived).toList();
    final completedToday = activeHabits.where((h) {
      final t = h.last90.last;
      return t == Utilization.full || t == Utilization.good;
    }).length;
    return DashboardStats(
      focusMinutesToday: today.focusedMinutes,
      dailyFocusTarget: _db.profile.targetForToday(_db.today),
      focusStreakDays: _db.profile.focusStreakDays,
      habitsDueToday: activeHabits.length,
      habitsCompletedToday: completedToday,
    );
  }

  @override
  Future<WeeklyStats> getWeekly() async {
    await Future.delayed(_ioLatency);
    final days = <DayBlocks>[];
    for (int i = 6; i >= 0; i--) {
      final d = DateTime(_db.today.year, _db.today.month, _db.today.day - i);
      days.add(_db.days[d]!);
    }
    final mins = days.map((d) => d.focusedMinutes).toList();
    final total = mins.fold<int>(0, (a, b) => a + b);
    final activeHabits = _db.habits.values.where((h) => !h.archived).toList();
    final avgCompletion = activeHabits.isEmpty
        ? 0
        : (activeHabits.fold<int>(0, (a, h) => a + h.completionRate) ~/ activeHabits.length);

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

    var goalHit = 0;
    var evaluated = 0;
    for (var i = 0; i < days.length; i++) {
      final target = _db.profile.targetForWeekday(days[i].date.weekday);
      if (target <= 0) continue;
      evaluated++;
      if (mins[i] >= target) goalHit++;
    }

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

    final hourly = List<int>.filled(24, 0);
    for (final d in days) {
      for (var q = 0; q < d.quarters.length; q++) {
        final p = d.quarters[q].percent;
        if (p == null) continue;
        hourly[q ~/ 4] += (p * 15 / 100).round();
      }
    }

    final habitRows = <HabitWeeklyRow>[];
    for (final h in activeHabits) {
      var hit = 0;
      var seen = 0;
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
      avgPerDay: total ~/ max(1, days.length),
      avgHabitCompletion: avgCompletion,
      bestDayIndex: bestIdx,
      worstDayIndex: worstIdx,
      goalHitDays: goalHit,
      evaluatedTargetDays: evaluated,
      avgUtilizationPct: avgUtil,
      hourlyMinutes: hourly,
      unloggedFocusQuarters: 0,
      habitRows: habitRows,
      subjectRows: const [],
    );
  }
}

class MockProfileRepository implements ProfileRepository {
  final MockDb _db;
  final ValueNotifier<UserProfile> _state;
  MockProfileRepository(this._db) : _state = ValueNotifier(_db.profile);

  @override
  ValueListenable<UserProfile> get profile => _state;

  @override
  Future<UserProfile> get() async {
    await Future.delayed(_ioLatency);
    return _state.value;
  }

  @override
  Future<void> update(UserProfile p) async {
    await Future.delayed(_ioLatency);
    _db.profile = p;
    _state.value = p;
  }
}

class MockSettingsRepository implements SettingsRepository {
  final MockDb _db;
  final ValueNotifier<AppSettings> _state;
  MockSettingsRepository(this._db) : _state = ValueNotifier(_db.settings);

  @override
  ValueListenable<AppSettings> get settings => _state;

  @override
  Future<AppSettings> get() async {
    await Future.delayed(_ioLatency);
    return _state.value;
  }

  @override
  Future<void> update(AppSettings s) async {
    await Future.delayed(_ioLatency);
    _db.settings = s;
    _state.value = s;
  }
}
