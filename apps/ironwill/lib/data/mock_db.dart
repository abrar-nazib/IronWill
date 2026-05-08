import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../models/utilization.dart';

/// In-memory mock backend. The repository layer is the only place that touches
/// this. Switching to a real backend means adding Remote* implementations of
/// the repository interfaces; nothing in the UI layer changes.
class MockDb {
  final DateTime today = DateTime(2026, 5, 4);

  // Mutable backing state. Repositories mutate these and notify listeners.
  late final Map<String, Habit> habits = _seedHabits();
  late final List<Subject> subjects = _seedSubjects();
  late final Map<DateTime, DayBlocks> days = _seedDays(today);

  UserProfile profile = const UserProfile(
    name: 'Abrar',
    weeklyFocusMinutes: [240, 240, 240, 240, 240, 120, 120],
    focusStreakDays: 13,
    avatarLetter: 'A',
  );

  AppSettings settings = const AppSettings();

  static MockDb? _instance;
  static MockDb get instance => _instance ??= MockDb._();
  MockDb._();

  Map<String, Habit> _seedHabits() {
    final base = <Habit>[
      Habit(
        id: 'h1',
        name: 'No social media before noon',
        cadence: HabitCadence.daily,
        glyph: LucideIcons.shieldOff,
        reminder: const TimeOfDay(hour: 5, minute: 30),
        currentStreak: 12,
        bestStreak: 41,
        completionRate: 78,
        last90: _seedHabit(seed: 1, full: 0.7),
        order: 0,
      ),
      Habit(
        id: 'h2',
        name: 'Cold shower',
        cadence: HabitCadence.daily,
        glyph: LucideIcons.snowflake,
        reminder: const TimeOfDay(hour: 6, minute: 15),
        currentStreak: 27,
        bestStreak: 27,
        completionRate: 92,
        last90: _seedHabit(seed: 2, full: 0.9),
        order: 1,
      ),
      Habit(
        id: 'h3',
        name: 'Read 30 minutes',
        cadence: HabitCadence.daily,
        glyph: LucideIcons.bookOpen,
        reminder: const TimeOfDay(hour: 22, minute: 0),
        currentStreak: 5,
        bestStreak: 33,
        completionRate: 64,
        last90: _seedHabit(seed: 3, full: 0.55),
        order: 2,
      ),
      Habit(
        id: 'h4',
        name: 'Strength training',
        cadence: HabitCadence.custom,
        customDays: const [1, 3, 5],
        glyph: LucideIcons.dumbbell,
        reminder: const TimeOfDay(hour: 17, minute: 30),
        currentStreak: 9,
        bestStreak: 18,
        completionRate: 71,
        last90: _seedHabit(seed: 4, full: 0.6),
        order: 3,
      ),
      Habit(
        id: 'h5',
        name: 'Lights out by 11',
        cadence: HabitCadence.daily,
        glyph: LucideIcons.moon,
        reminder: const TimeOfDay(hour: 22, minute: 45),
        currentStreak: 3,
        bestStreak: 22,
        completionRate: 49,
        last90: _seedHabit(seed: 5, full: 0.4),
        order: 4,
      ),
      Habit(
        id: 'ha1',
        name: 'No alcohol on weekdays',
        cadence: HabitCadence.weekdays,
        glyph: LucideIcons.wine,
        reminder: const TimeOfDay(hour: 18, minute: 0),
        currentStreak: 0,
        bestStreak: 12,
        completionRate: 38,
        last90: _seedHabit(seed: 6, full: 0.3),
        archived: true,
        order: 5,
      ),
    ];
    return {for (final h in base) h.id: h};
  }

  /// Seed subjects expire 7 days from `today` so the mock matches the
  /// production TTL behaviour (the user can press "Repeat next week" to extend).
  List<Subject> _seedSubjects() {
    final created = today;
    final expiresAt = today.add(const Duration(days: 7));
    SubjectBlock blk(String id, String subjectId, int day, int sh, int sm, int eh, int em) =>
        SubjectBlock(
          id: id,
          subjectId: subjectId,
          dayOfWeek: day,
          start: TimeOfDay(hour: sh, minute: sm),
          end: TimeOfDay(hour: eh, minute: em),
        );
    return [
      Subject(
        id: 'subj_deep_work',
        name: 'Deep work',
        expiresAt: expiresAt,
        createdAt: created,
        order: 0,
        blocks: [
          for (final d in const [1, 2, 3, 4, 5])
            blk('blk_deep_$d', 'subj_deep_work', d, 6, 0, 9, 0),
        ],
      ),
      Subject(
        id: 'subj_build',
        name: 'Build session',
        expiresAt: expiresAt,
        createdAt: created,
        order: 1,
        blocks: [
          for (final d in const [1, 2, 3, 4, 5])
            blk('blk_build_$d', 'subj_build', d, 14, 0, 16, 0),
        ],
      ),
      Subject(
        id: 'subj_review',
        name: 'Review and journal',
        expiresAt: expiresAt,
        createdAt: created,
        order: 2,
        blocks: [
          for (final d in const [1, 2, 3, 4, 5, 6, 7])
            blk('blk_review_$d', 'subj_review', d, 21, 0, 22, 0),
        ],
      ),
    ];
  }

  Map<DateTime, DayBlocks> _seedDays(DateTime end) {
    final out = <DateTime, DayBlocks>{};
    for (int back = 0; back < 30; back++) {
      final d = DateTime(end.year, end.month, end.day - back);
      out[d] = DayBlocks(date: d, quarters: _seedDay(d, isToday: back == 0));
    }
    return out;
  }

  static List<Utilization> _seedHabit({required int seed, required double full}) {
    final r = Random(seed * 31 + 7);
    return List.generate(90, (i) {
      final v = r.nextDouble();
      if (v < full * 0.85) return Utilization.full;
      if (v < full) return Utilization.good;
      if (v < full + 0.07) return Utilization.mid;
      if (v < full + 0.13) return Utilization.low;
      if (v < full + 0.20) return Utilization.wasted;
      return Utilization.none;
    });
  }

  static List<Utilization> _seedDay(DateTime d, {bool isToday = false}) {
    final r = Random(d.millisecondsSinceEpoch ~/ 86400000);
    final out = List<Utilization>.filled(96, Utilization.none);
    for (int q = 0; q < 24; q++) {
      out[q] = Utilization.notFocus;
    }
    for (int q = 92; q < 96; q++) {
      out[q] = Utilization.notFocus;
    }
    for (int q = 24; q < 36; q++) {
      out[q] = _focusedRoll(r, 0.85);
    }
    for (int q = 36; q < 48; q++) {
      out[q] = _focusedRoll(r, 0.55);
    }
    for (int q = 48; q < 56; q++) {
      out[q] = Utilization.notFocus;
    }
    for (int q = 56; q < 64; q++) {
      out[q] = _focusedRoll(r, 0.5);
    }
    for (int q = 64; q < 72; q++) {
      out[q] = Utilization.notFocus;
    }
    for (int q = 72; q < 88; q++) {
      out[q] = _focusedRoll(r, 0.6);
    }
    for (int q = 88; q < 92; q++) {
      out[q] = Utilization.notFocus;
    }
    if (isToday) {
      for (int q = 76; q < 96; q++) {
        out[q] = Utilization.none;
      }
    }
    return out;
  }

  static Utilization _focusedRoll(Random r, double full) {
    final v = r.nextDouble();
    if (v < full * 0.7) return Utilization.full;
    if (v < full) return Utilization.good;
    if (v < full + 0.10) return Utilization.mid;
    if (v < full + 0.18) return Utilization.low;
    return Utilization.wasted;
  }
}
