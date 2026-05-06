import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../models/utilization.dart';

/// Repository contracts. Every screen reads through these. To switch from the
/// mock backend to a real network backend, swap the implementations injected
/// into AppServices; nothing in the UI layer changes.
///
/// All methods return Futures so the API matches a real network call. Mutations
/// also push updates through ValueListenable streams so widgets that listen
/// rebuild automatically without manual setState plumbing.

abstract class HabitsRepository {
  ValueListenable<List<Habit>> get all;
  ValueListenable<List<Habit>> get active;

  Future<List<Habit>> listAll();
  Future<List<Habit>> listActive();
  Future<List<Habit>> listArchived();
  Future<Habit?> getById(String id);
  Future<Habit> create(HabitDraft draft);
  Future<Habit> update(Habit h);
  Future<void> archive(String id);
  Future<void> unarchive(String id);
  Future<void> reorder(List<String> ids);
  Future<void> logToday(String habitId, Utilization u, {String note});
  Future<void> logDay(String habitId, DateTime day, Utilization u, {String note});
  Future<HabitLog?> getLog(String habitId, DateTime day);
}

abstract class TimeRepository {
  ValueListenable<DayBlocks> get today;
  Future<DayBlocks> getDay(DateTime date);
  Future<List<DayBlocks>> getRange(DateTime start, DateTime endInclusive);
  Future<void> logQuarter(DateTime date, int quarterIndex, Utilization u);
}

abstract class FocusSessionsRepository {
  ValueListenable<List<FocusSession>> get all;

  Future<List<FocusSession>> listAll();
  Future<FocusSession?> getById(String id);
  Future<FocusSession> create(FocusSessionDraft draft);
  Future<FocusSession> update(FocusSession s);
  Future<void> delete(String id);
}

abstract class StatsRepository {
  /// Live focus-minutes streak. Recomputes when time blocks or daily target
  /// change. Reactive so the home screen does not depend on a stale stored
  /// column.
  ValueListenable<int> get focusStreakDays;
  Future<DashboardStats> getDashboard();
  Future<WeeklyStats> getWeekly();
}

abstract class ProfileRepository {
  ValueListenable<UserProfile> get profile;
  Future<UserProfile> get();
  Future<void> update(UserProfile p);
}

abstract class SettingsRepository {
  ValueListenable<AppSettings> get settings;
  Future<AppSettings> get();
  Future<void> update(AppSettings s);
}
