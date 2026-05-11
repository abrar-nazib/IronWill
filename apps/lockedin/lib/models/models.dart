import 'package:flutter/material.dart';

import 'utilization.dart';

/// Sum of focused minutes across the given quarters, weighted by each block's
/// utilization. A 100% quarter contributes 15 min, 75% → 11.25, 50% → 7.5,
/// 25% → 3.75, 0% (wasted) → 0. Unlogged and non-focus quarters contribute
/// nothing. The fractional sum is rounded to int at the end so partial credit
/// accumulates honestly across many quarters instead of vanishing per block.
int _weightedFocusedMinutes(List<Utilization> quarters) {
  double mins = 0;
  for (final q in quarters) {
    final pct = q.percent;
    if (pct == null) continue;
    mins += pct * 15 / 100;
  }
  return mins.round();
}

enum HabitCadence {
  daily,
  weekdays,
  weekends,
  custom,
}

extension HabitCadenceX on HabitCadence {
  String get label => switch (this) {
        HabitCadence.daily => 'Every day',
        HabitCadence.weekdays => 'Weekdays',
        HabitCadence.weekends => 'Weekends',
        HabitCadence.custom => 'Custom days',
      };
}

class Habit {
  final String id;
  final String name;
  final String description;

  /// Structured key/value pairs for tracking habit-specific data (e.g. exercise
  /// reps: `{'PU': [15, 12, 10], 'BC': [20, 12, 10]}`). Values can be any
  /// JSON-encodable shape: `String`, `num`, `bool`, `List`, or nested `Map`.
  /// The editor exposes a typed picker per key so users don't hand-edit JSON.
  final Map<String, Object?> metadata;
  final HabitCadence cadence;
  final List<int> customDays;
  final IconData glyph;
  final TimeOfDay reminder;
  final bool reminderOn;
  final int currentStreak;
  final int bestStreak;
  final int completionRate;
  final List<Utilization> last90;
  final bool archived;
  final int order;

  const Habit({
    required this.id,
    required this.name,
    this.description = '',
    this.metadata = const <String, Object?>{},
    required this.cadence,
    this.customDays = const [],
    required this.glyph,
    required this.reminder,
    this.reminderOn = true,
    required this.currentStreak,
    required this.bestStreak,
    required this.completionRate,
    required this.last90,
    this.archived = false,
    required this.order,
  });

  Habit copyWith({
    String? name,
    String? description,
    Map<String, Object?>? metadata,
    HabitCadence? cadence,
    List<int>? customDays,
    IconData? glyph,
    TimeOfDay? reminder,
    bool? reminderOn,
    int? currentStreak,
    int? bestStreak,
    int? completionRate,
    List<Utilization>? last90,
    bool? archived,
    int? order,
  }) {
    return Habit(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      metadata: metadata ?? this.metadata,
      cadence: cadence ?? this.cadence,
      customDays: customDays ?? this.customDays,
      glyph: glyph ?? this.glyph,
      reminder: reminder ?? this.reminder,
      reminderOn: reminderOn ?? this.reminderOn,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      completionRate: completionRate ?? this.completionRate,
      last90: last90 ?? this.last90,
      archived: archived ?? this.archived,
      order: order ?? this.order,
    );
  }
}

class HabitLog {
  final DateTime day;
  final Utilization utilization;
  final String note;

  /// Structured values for the habit's tracking fields on this specific day.
  /// Keys match `Habit.fields[].key`; values can be `String`, `int`, `bool`,
  /// `List<int>`, `List<bool>`, `List<String>`. Persisted as JSON in the
  /// habit_logs.metadata column.
  final Map<String, Object?> metadata;
  const HabitLog({
    required this.day,
    required this.utilization,
    this.note = '',
    this.metadata = const <String, Object?>{},
  });
}

/// Type of a habit's structured tracking field. Each habit can declare its
/// own list of fields so the user records the right shape per day (e.g.,
/// pushup reps as a list of ints, "did warmup" as a bool).
enum HabitFieldType {
  text,
  number,
  boolean,
  intList,
  boolList,
}

extension HabitFieldTypeX on HabitFieldType {
  String get label => switch (this) {
        HabitFieldType.text => 'Text',
        HabitFieldType.number => 'Number',
        HabitFieldType.boolean => 'Yes / No',
        HabitFieldType.intList => 'List of numbers',
        HabitFieldType.boolList => 'List of yes / no',
      };

  String get hint => switch (this) {
        HabitFieldType.text => 'e.g. "Felt strong"',
        HabitFieldType.number => 'e.g. 25',
        HabitFieldType.boolean => 'true or false',
        HabitFieldType.intList => 'e.g. 15, 12, 10',
        HabitFieldType.boolList => 'e.g. yes, yes, no',
      };
}

/// One tracking field declared on a [Habit]. The user defines these once on
/// the habit, then records values for them on each [HabitLog].
class HabitField {
  final String key;
  final HabitFieldType type;
  const HabitField({required this.key, required this.type});

  Map<String, Object?> toJson() => {'key': key, 'type': type.name};

  static HabitField? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final k = raw['key'];
    final t = raw['type'];
    if (k is! String || t is! String) return null;
    final type = HabitFieldType.values.firstWhere(
      (e) => e.name == t,
      orElse: () => HabitFieldType.text,
    );
    return HabitField(key: k, type: type);
  }
}

/// Read the `fields` list out of a habit's metadata map. Returns an empty
/// list when malformed; the editor seeds the metadata with the right shape.
List<HabitField> parseHabitFields(Map<String, Object?> metadata) {
  final raw = metadata['fields'];
  if (raw is! List) return const [];
  return raw
      .map(HabitField.fromJson)
      .whereType<HabitField>()
      .toList();
}

/// Build a habit metadata map from the user's field list.
Map<String, Object?> habitMetadataFromFields(List<HabitField> fields) =>
    {'fields': fields.map((f) => f.toJson()).toList()};

class HabitDraft {
  String name;
  String description;
  Map<String, Object?> metadata;
  HabitCadence cadence;
  List<int> customDays;
  IconData glyph;
  TimeOfDay reminder;
  bool reminderOn;
  HabitDraft({
    this.name = '',
    this.description = '',
    Map<String, Object?>? metadata,
    this.cadence = HabitCadence.daily,
    this.customDays = const [],
    required this.glyph,
    required this.reminder,
    this.reminderOn = true,
  }) : metadata = metadata ?? <String, Object?>{};
}

/// A "Subject" is the umbrella term for what the user is locking in on:
/// "Math", "Workout", a side project. It's just a name + an order. The
/// concrete time windows for working on that subject live on
/// [FocusSession] rows (one-shot schedule with explicit start/end), not
/// on a weekly recurrence template.
///
/// [expiresAt] is kept for now to drive the soft "schedule decays after a
/// week" UX hint on the Subjects screen, but it no longer gates whether
/// any session can run. The user can always start a session under any
/// subject regardless of expiry.
class Subject {
  final String id;
  final String name;

  /// Soft expiry. Used for sorting and a "Repeat next week" affordance on
  /// the subjects list. Does NOT prevent a focus session from running.
  final DateTime expiresAt;
  final DateTime createdAt;
  final int order;

  const Subject({
    required this.id,
    required this.name,
    required this.expiresAt,
    required this.createdAt,
    required this.order,
  });

  /// True if today is within (or before) the subject's soft expiry date.
  bool isLiveOn(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiresAt.year, expiresAt.month, expiresAt.day);
    return !today.isAfter(exp);
  }

  Subject copyWith({
    String? name,
    DateTime? expiresAt,
    int? order,
  }) =>
      Subject(
        id: id,
        name: name ?? this.name,
        expiresAt: expiresAt ?? this.expiresAt,
        createdAt: createdAt,
        order: order ?? this.order,
      );
}

class SubjectDraft {
  String name;
  DateTime expiresAt;
  SubjectDraft({
    this.name = '',
    required this.expiresAt,
  });
}

/// Derived status of a [FocusSession] relative to a moment in time.
enum FocusSessionStatus { pending, active, done }

/// One concrete time window during which the user committed to focus.
/// Replaces the old weekly-recurring [SubjectBlock] model: the user
/// schedules a session with explicit start and end DateTimes, optionally
/// under a Subject. A recurring "every Mon/Wed/Fri 9-10" is implemented
/// as N FocusSession rows from the frontend, not as one row with a
/// recurrence rule. The collision check is enforced at the repo layer.
class FocusSession {
  final String id;

  /// Optional. A session can stand alone (just "focus from 9-10") or be
  /// attributed to a subject (`Math`, `Workout`). When non-null, time
  /// blocks logged inside this session inherit the subject id.
  final String? subjectId;
  final DateTime startAt;
  final DateTime endAt;
  final DateTime createdAt;

  const FocusSession({
    required this.id,
    required this.subjectId,
    required this.startAt,
    required this.endAt,
    required this.createdAt,
  });

  Duration get duration => endAt.difference(startAt);
  int get durationMinutes => duration.inMinutes;

  FocusSessionStatus statusAt(DateTime now) {
    if (now.isBefore(startAt)) return FocusSessionStatus.pending;
    if (now.isBefore(endAt)) return FocusSessionStatus.active;
    return FocusSessionStatus.done;
  }

  /// True iff [now] falls inside [startAt, endAt).
  bool isActiveAt(DateTime now) =>
      !now.isBefore(startAt) && now.isBefore(endAt);

  /// True iff [otherStart, otherEnd) overlaps with this session's window.
  /// Touching boundaries (one ends exactly when the next starts) do NOT
  /// count as overlap, so back-to-back sessions are allowed.
  bool overlapsWith(DateTime otherStart, DateTime otherEnd) =>
      otherStart.isBefore(endAt) && startAt.isBefore(otherEnd);

  FocusSession copyWith({
    String? subjectId,
    bool clearSubjectId = false,
    DateTime? startAt,
    DateTime? endAt,
  }) =>
      FocusSession(
        id: id,
        subjectId: clearSubjectId ? null : (subjectId ?? this.subjectId),
        startAt: startAt ?? this.startAt,
        endAt: endAt ?? this.endAt,
        createdAt: createdAt,
      );
}

class FocusSessionDraft {
  String? subjectId;
  DateTime startAt;
  DateTime endAt;
  FocusSessionDraft({
    this.subjectId,
    required this.startAt,
    required this.endAt,
  });

  Duration get duration => endAt.difference(startAt);
}

/// A live focus session at the current moment. Returned by
/// [currentlyActiveSession] when "now" falls inside the [startAt, endAt)
/// window of any session.
class ActiveSession {
  final FocusSession session;

  /// May be null when the session was created without a subject. The UI
  /// renders "Focus" in that case instead of a subject name.
  final Subject? subject;
  final DateTime startAt;
  final DateTime endAt;
  const ActiveSession({
    required this.session,
    required this.subject,
    required this.startAt,
    required this.endAt,
  });

  String get displayName => subject?.name ?? 'Focus session';
}

/// Find the (single) session currently active, if any. Picks the first
/// session whose [startAt, endAt) contains [now]; in practice the repo
/// collision check guarantees at most one is live at a time.
ActiveSession? currentlyActiveSession(
  List<FocusSession> sessions,
  List<Subject> subjects,
  DateTime now,
) {
  for (final s in sessions) {
    if (s.isActiveAt(now)) {
      final subject = s.subjectId == null
          ? null
          : subjects.cast<Subject?>().firstWhere(
                (x) => x?.id == s.subjectId,
                orElse: () => null,
              );
      return ActiveSession(
        session: s,
        subject: subject,
        startAt: s.startAt,
        endAt: s.endAt,
      );
    }
  }
  return null;
}

class DayBlocks {
  final DateTime date;
  final List<Utilization> quarters;

  /// Parallel array to [quarters]. `subjectIds[q]` is the subject this
  /// quarter was attributed to at log time, or null when the quarter is
  /// unlogged / wasn't tagged. Empty list means "no subject info known"
  /// (older code paths that didn't populate it).
  final List<String?> subjectIds;

  const DayBlocks({
    required this.date,
    required this.quarters,
    this.subjectIds = const [],
  }) : assert(quarters.length == 96 || quarters.length == 0);

  int get focusedMinutes => _weightedFocusedMinutes(quarters);

  int get plannedFocusedMinutes =>
      quarters.where((q) => q != Utilization.notFocus && q != Utilization.none).length * 15;

  double get utilizationPercent {
    final scored = quarters
        .map((q) => switch (q) {
              Utilization.none => null,
              Utilization.notFocus => null,
              Utilization.wasted => 0.0,
              Utilization.low => 0.25,
              Utilization.mid => 0.5,
              Utilization.good => 0.75,
              Utilization.full => 1.0,
            })
        .whereType<double>()
        .toList();
    if (scored.isEmpty) return 0;
    return scored.reduce((a, b) => a + b) / scored.length;
  }

  int get loggedQuarterCount =>
      quarters.where((q) => q != Utilization.none).length;
}

class UserProfile {
  final String name;

  /// Per-weekday focus targets in minutes. Always length 7, indexed Mon..Sun
  /// (i.e. `weeklyFocusMinutes[0]` is Monday, matching `DateTime.weekday - 1`).
  /// Each value is clamped 0..1440 by the editor; a 0 means "no target today",
  /// the streak counter treats it as a free day.
  final List<int> weeklyFocusMinutes;
  final int focusStreakDays;
  final String? avatarLetter;
  final String timezone;

  const UserProfile({
    required this.name,
    this.weeklyFocusMinutes = const [240, 240, 240, 240, 240, 240, 240],
    this.focusStreakDays = 0,
    this.avatarLetter,
    this.timezone = 'Local',
  });

  /// Today's target. `dow` follows `DateTime.weekday` (1=Mon..7=Sun). Falls
  /// back to the first entry if the list is malformed.
  int targetForWeekday(int dow) {
    final idx = (dow - 1).clamp(0, 6);
    if (weeklyFocusMinutes.length != 7) {
      return weeklyFocusMinutes.isNotEmpty ? weeklyFocusMinutes.first : 240;
    }
    return weeklyFocusMinutes[idx];
  }

  /// Convenience: the current weekday's target.
  int targetForToday([DateTime? now]) =>
      targetForWeekday((now ?? DateTime.now()).weekday);

  UserProfile copyWith({
    String? name,
    List<int>? weeklyFocusMinutes,
    int? focusStreakDays,
    String? avatarLetter,
    String? timezone,
  }) =>
      UserProfile(
        name: name ?? this.name,
        weeklyFocusMinutes: weeklyFocusMinutes ?? this.weeklyFocusMinutes,
        focusStreakDays: focusStreakDays ?? this.focusStreakDays,
        avatarLetter: avatarLetter ?? this.avatarLetter,
        timezone: timezone ?? this.timezone,
      );
}

enum FirstDayOfWeek { monday, sunday, saturday }

enum AlarmSound { softChime, gong, deepBell, bowl, none }

extension AlarmSoundX on AlarmSound {
  String get label => switch (this) {
        AlarmSound.softChime => 'Soft chime',
        AlarmSound.gong => 'Gong',
        AlarmSound.deepBell => 'Deep bell',
        AlarmSound.bowl => 'Singing bowl',
        AlarmSound.none => 'Silent (vibrate only)',
      };
}

enum ThemeChoice { light, dark, system }

class AppSettings {
  final FirstDayOfWeek firstDay;
  final AlarmSound alarm;
  final bool reminderLogging;
  final int dailyFocusMinutes;
  final bool privacyLockOn;
  final ThemeChoice themeMode;
  final bool onboarded;

  /// Display granularity in the time tracker. Storage is always 15 minutes
  /// (96 quarters per day) regardless: this is purely how blocks are rolled
  /// up when rendering, so toggling between 15/30/60 is non-destructive.
  /// Allowed values: 15, 30, 60. Default 30.
  final int blockSizeMinutes;

  /// Per-block default. Each [SubjectBlock] also has its own override; this
  /// global default is what gets remembered for new blocks and is the floor
  /// the floating-window toggle starts from.
  final bool pomodoroEnabled;

  /// Percent of a block reserved as pomodoro rest. Default 15. Clamped 5..50.
  final int pomodoroPercent;

  const AppSettings({
    this.firstDay = FirstDayOfWeek.monday,
    this.alarm = AlarmSound.softChime,
    this.reminderLogging = true,
    this.dailyFocusMinutes = 240,
    this.privacyLockOn = false,
    this.themeMode = ThemeChoice.system,
    this.onboarded = false,
    this.blockSizeMinutes = 30,
    this.pomodoroEnabled = false,
    this.pomodoroPercent = 15,
  });

  AppSettings copyWith({
    FirstDayOfWeek? firstDay,
    AlarmSound? alarm,
    bool? reminderLogging,
    int? dailyFocusMinutes,
    bool? privacyLockOn,
    ThemeChoice? themeMode,
    bool? onboarded,
    int? blockSizeMinutes,
    bool? pomodoroEnabled,
    int? pomodoroPercent,
  }) =>
      AppSettings(
        firstDay: firstDay ?? this.firstDay,
        alarm: alarm ?? this.alarm,
        reminderLogging: reminderLogging ?? this.reminderLogging,
        dailyFocusMinutes: dailyFocusMinutes ?? this.dailyFocusMinutes,
        privacyLockOn: privacyLockOn ?? this.privacyLockOn,
        themeMode: themeMode ?? this.themeMode,
        onboarded: onboarded ?? this.onboarded,
        blockSizeMinutes: blockSizeMinutes ?? this.blockSizeMinutes,
        pomodoroEnabled: pomodoroEnabled ?? this.pomodoroEnabled,
        pomodoroPercent: pomodoroPercent ?? this.pomodoroPercent,
      );
}

class DashboardStats {
  final int focusMinutesToday;
  final int dailyFocusTarget;
  final int focusStreakDays;
  final int habitsDueToday;
  final int habitsCompletedToday;

  const DashboardStats({
    required this.focusMinutesToday,
    required this.dailyFocusTarget,
    required this.focusStreakDays,
    required this.habitsDueToday,
    required this.habitsCompletedToday,
  });
}

/// Per-subject focus breakdown used inside [WeeklyStats]. Attribution is
/// tag-based: each logged quarter carries a nullable `subject_id` in
/// `time_blocks`, set at log time from the active focus session (or
/// picked manually). Quarters with no subject id are not attributed
/// (they still count toward the global focused total).
class SubjectStatsRow {
  final String id;
  final String name;

  /// Weighted focus minutes (utilization-aware). 100% quarter contributes
  /// 15 min, 75% → 11.25, etc. Same convention as [DayBlocks.focusedMinutes].
  final int focusedMinutes;

  /// Count of 15-min quarters tagged with this subject that have a
  /// non-none, non-notFocus utilization stamp.
  final int loggedQuarters;

  /// Avg utilization percent of LOGGED quarters tagged with this subject
  /// (0..100). Null when nothing was logged.
  final int? avgUtilizationPct;
  const SubjectStatsRow({
    required this.id,
    required this.name,
    required this.focusedMinutes,
    required this.loggedQuarters,
    required this.avgUtilizationPct,
  });
}

/// Per-habit row used inside [WeeklyStats] so the user can see which habit is
/// pulling the average up or down without leaving the Stats screen.
class HabitWeeklyRow {
  final String id;
  final String name;
  final IconData glyph;
  final int hitDays;
  final int evaluatedDays;
  final int currentStreak;
  const HabitWeeklyRow({
    required this.id,
    required this.name,
    required this.glyph,
    required this.hitDays,
    required this.evaluatedDays,
    required this.currentStreak,
  });

  int get completionPct =>
      evaluatedDays == 0 ? 0 : ((hitDays / evaluatedDays) * 100).round();
}

/// Detail data for one subject across a stats range. Produced by
/// [StatsRepository.getSubjectDetail]. Only time_blocks tagged with
/// this subject contribute. The detail screen reuses the existing
/// QuarterGrid for the per-day strip by re-emitting DayBlocks where
/// only this subject's quarters carry a utilization value.
class SubjectDetailStats {
  final String id;
  final String name;

  /// One DayBlocks per day in the range (ascending). Quarters that did
  /// NOT belong to this subject are masked to [Utilization.none] so
  /// the existing renderers show only this subject's slice.
  final List<DayBlocks> days;

  /// Weighted focus minutes contributed by this subject across the range.
  final int focusedMinutes;

  /// Count of 15-min quarters tagged with this subject.
  final int loggedQuarters;

  /// Average utilization percent of LOGGED quarters of this subject
  /// (0..100). Null when nothing is logged in the range.
  final int? avgUtilizationPct;

  /// 24-bin hour-of-day minute distribution, restricted to this subject.
  final List<int> hourlyMinutes;

  /// Per-day weighted focus minutes (length == days.length).
  final List<int> focusMinutesByDay;

  /// Best / worst day indices into [days]. -1 when nothing logged.
  final int bestDayIndex;
  final int worstDayIndex;

  const SubjectDetailStats({
    required this.id,
    required this.name,
    required this.days,
    required this.focusedMinutes,
    required this.loggedQuarters,
    required this.avgUtilizationPct,
    required this.hourlyMinutes,
    required this.focusMinutesByDay,
    required this.bestDayIndex,
    required this.worstDayIndex,
  });
}

class WeeklyStats {
  final List<int> focusMinutesByDay;
  final List<DayBlocks> days;
  final int totalFocusMinutes;
  final int avgPerDay;
  final int avgHabitCompletion;

  /// Index of the day in [days] with the most focused minutes. -1 when the
  /// whole week has zero minutes.
  final int bestDayIndex;

  /// Same shape as [bestDayIndex] but for the lowest non-zero day. -1 when
  /// the entire week is zeros.
  final int worstDayIndex;

  /// Number of days in the period that hit (or beat) the per-weekday focus
  /// target. Days with a 0-target ("rest day") are excluded from the
  /// denominator so the metric isn't gamed by setting Sunday to zero.
  final int goalHitDays;

  /// Denominator for [goalHitDays] - days in range with a non-zero target.
  final int evaluatedTargetDays;

  /// Average utilization of LOGGED blocks (0..100). A pure "wasted" log
  /// pulls this down, a "full" log pulls it up. Skips unlogged quarters.
  final int avgUtilizationPct;

  /// 24 ints. `[h]` is the total minutes focused at hour-of-day h across
  /// the entire period. Drives the "when do you actually focus" heatmap.
  final List<int> hourlyMinutes;

  /// Total focused-but-unlogged quarters in the period - the quarters that
  /// fell inside a scheduled subject block but never got a utilization
  /// stamp. Surfaced so the user sees where their data is missing.
  final int unloggedFocusQuarters;

  /// One row per active habit with hit/evaluated counts so the UI can
  /// sort, color, and rank.
  final List<HabitWeeklyRow> habitRows;

  /// One row per subject that had at least one scheduled block in the
  /// period. Subjects with no schedule overlap the period are skipped.
  final List<SubjectStatsRow> subjectRows;

  const WeeklyStats({
    required this.focusMinutesByDay,
    required this.days,
    required this.totalFocusMinutes,
    required this.avgPerDay,
    required this.avgHabitCompletion,
    required this.bestDayIndex,
    required this.worstDayIndex,
    required this.goalHitDays,
    required this.evaluatedTargetDays,
    required this.avgUtilizationPct,
    required this.hourlyMinutes,
    required this.unloggedFocusQuarters,
    required this.habitRows,
    required this.subjectRows,
  });
}
