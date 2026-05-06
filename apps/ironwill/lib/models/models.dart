import 'package:flutter/material.dart';

import 'utilization.dart';

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
  const HabitLog({required this.day, required this.utilization, this.note = ''});
}

class HabitDraft {
  String name;
  String description;
  HabitCadence cadence;
  List<int> customDays;
  IconData glyph;
  TimeOfDay reminder;
  bool reminderOn;
  HabitDraft({
    this.name = '',
    this.description = '',
    this.cadence = HabitCadence.daily,
    this.customDays = const [],
    required this.glyph,
    required this.reminder,
    this.reminderOn = true,
  });
}

class FocusSession {
  final String id;
  final String name;
  final TimeOfDay start;
  final TimeOfDay end;
  final List<int> daysOfWeek;
  final List<Utilization> quarters;

  const FocusSession({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    required this.quarters,
  });

  int get totalQuarters => quarters.length;
  int get loggedFocusedQuarters =>
      quarters.where((q) => q == Utilization.good || q == Utilization.full).length;
  int get focusedMinutes => loggedFocusedQuarters * 15;
  int get loggedQuarters =>
      quarters.where((q) => q != Utilization.none).length;

  FocusSession copyWith({
    String? name,
    TimeOfDay? start,
    TimeOfDay? end,
    List<int>? daysOfWeek,
    List<Utilization>? quarters,
  }) {
    return FocusSession(
      id: id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      quarters: quarters ?? this.quarters,
    );
  }
}

class FocusSessionDraft {
  String name;
  TimeOfDay start;
  TimeOfDay end;
  List<int> daysOfWeek;
  FocusSessionDraft({
    this.name = '',
    required this.start,
    required this.end,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
  });
}

class DayBlocks {
  final DateTime date;
  final List<Utilization> quarters;

  const DayBlocks({required this.date, required this.quarters})
      : assert(quarters.length == 96 || quarters.length == 0);

  int get focusedMinutes =>
      quarters.where((q) => q == Utilization.good || q == Utilization.full).length * 15;

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
  final int dailyFocusMinutesTarget;
  final int focusStreakDays;
  final String? avatarLetter;
  final String timezone;

  const UserProfile({
    required this.name,
    this.dailyFocusMinutesTarget = 240,
    this.focusStreakDays = 0,
    this.avatarLetter,
    this.timezone = 'Local',
  });

  UserProfile copyWith({
    String? name,
    int? dailyFocusMinutesTarget,
    int? focusStreakDays,
    String? avatarLetter,
    String? timezone,
  }) =>
      UserProfile(
        name: name ?? this.name,
        dailyFocusMinutesTarget: dailyFocusMinutesTarget ?? this.dailyFocusMinutesTarget,
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

  const AppSettings({
    this.firstDay = FirstDayOfWeek.monday,
    this.alarm = AlarmSound.softChime,
    this.reminderLogging = true,
    this.dailyFocusMinutes = 240,
    this.privacyLockOn = false,
    this.themeMode = ThemeChoice.system,
    this.onboarded = false,
  });

  AppSettings copyWith({
    FirstDayOfWeek? firstDay,
    AlarmSound? alarm,
    bool? reminderLogging,
    int? dailyFocusMinutes,
    bool? privacyLockOn,
    ThemeChoice? themeMode,
    bool? onboarded,
  }) =>
      AppSettings(
        firstDay: firstDay ?? this.firstDay,
        alarm: alarm ?? this.alarm,
        reminderLogging: reminderLogging ?? this.reminderLogging,
        dailyFocusMinutes: dailyFocusMinutes ?? this.dailyFocusMinutes,
        privacyLockOn: privacyLockOn ?? this.privacyLockOn,
        themeMode: themeMode ?? this.themeMode,
        onboarded: onboarded ?? this.onboarded,
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

class WeeklyStats {
  final List<int> focusMinutesByDay;
  final List<DayBlocks> days;
  final int totalFocusMinutes;
  final int avgPerDay;
  final int avgHabitCompletion;

  const WeeklyStats({
    required this.focusMinutesByDay,
    required this.days,
    required this.totalFocusMinutes,
    required this.avgPerDay,
    required this.avgHabitCompletion,
  });
}
