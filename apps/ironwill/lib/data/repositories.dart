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
  Future<void> logToday(String habitId, Utilization u,
      {String note, Map<String, Object?> metadata});
  Future<void> logDay(String habitId, DateTime day, Utilization u,
      {String note, Map<String, Object?> metadata});
  Future<HabitLog?> getLog(String habitId, DateTime day);
}

abstract class TimeRepository {
  ValueListenable<DayBlocks> get today;
  Future<DayBlocks> getDay(DateTime date);
  Future<List<DayBlocks>> getRange(DateTime start, DateTime endInclusive);

  /// Log a single 15-min quarter with optional subject attribution.
  /// Pass [clearSubjectId] = true to wipe the existing tag (e.g. on
  /// re-log without a subject). When omitted, the existing tag is
  /// preserved unless the row is being created fresh.
  Future<void> logQuarter(
    DateTime date,
    int quarterIndex,
    Utilization u, {
    String? subjectId,
    bool clearSubjectId = false,
  });
}

abstract class SubjectsRepository {
  /// All subjects, sorted by `ord` ascending. Includes "expired" subjects:
  /// since v6 expiry is a soft hint and does not gate sessions, every
  /// subject stays selectable everywhere.
  ValueListenable<List<Subject>> get all;

  Future<List<Subject>> listAll();
  Future<Subject?> getById(String id);

  Future<Subject> create(SubjectDraft draft);
  Future<Subject> update(Subject s);
  Future<void> delete(String id);

  /// Extend a subject's expiry by [LocalDb.defaultExpiryDays] days.
  /// Idempotent in the sense that pressing it twice extends twice.
  Future<Subject> repeatNextWeek(String subjectId);
}

/// Thrown by [FocusSessionsRepository] when the requested window overlaps
/// an existing session (other than `excludeId`).
class FocusSessionCollisionException implements Exception {
  final FocusSession existing;
  FocusSessionCollisionException(this.existing);
  @override
  String toString() => 'FocusSessionCollisionException(${existing.id})';
}

abstract class FocusSessionsRepository {
  /// All focus sessions, ordered by [FocusSession.startAt] ascending. The
  /// notifier fires when any session is created, updated, or deleted.
  ValueListenable<List<FocusSession>> get all;

  Future<List<FocusSession>> listAll();
  Future<FocusSession?> getById(String id);

  /// Sessions overlapping the half-open `[from, to)` window. Used by
  /// notification scheduling, the logging-grace inference, and the home
  /// "up next" / "active" widgets.
  Future<List<FocusSession>> listInWindow(DateTime from, DateTime to);

  /// The session active at [now], if any. With collision detection on
  /// create/update there is at most one.
  FocusSession? activeAt(DateTime now);

  /// Synchronous overlap query against the in-memory snapshot. Returns
  /// every session whose `[startAt, endAt)` intersects the given window.
  /// Used by the logging UX to ask "which session does this block belong
  /// to?" when more than one matches.
  List<FocusSession> overlapping(DateTime start, DateTime end);

  /// Throws [FocusSessionCollisionException] when the draft overlaps an
  /// existing session.
  Future<FocusSession> create(FocusSessionDraft draft);

  /// Throws [FocusSessionCollisionException] when the new window overlaps
  /// another session (the session being updated is excluded from the
  /// collision check).
  Future<FocusSession> update(FocusSession session);

  Future<void> delete(String id);
}

/// Periods supported by [StatsRepository.getRange]. Week is the default
/// shown on the Stats screen; Month / Year are surfaced through the
/// header chips.
enum StatsRange { week, month, year }

abstract class StatsRepository {
  /// Live focus-minutes streak. Recomputes when time blocks or daily target
  /// change. Reactive so the home screen does not depend on a stale stored
  /// column.
  ValueListenable<int> get focusStreakDays;
  Future<DashboardStats> getDashboard();

  /// Convenience: `getRange(StatsRange.week)`. Kept for the home screen
  /// which only ever wants the weekly view.
  Future<WeeklyStats> getWeekly();

  /// Stats for the last 7 / 30 / 365 days ending today. The
  /// [WeeklyStats.days] list still contains 7 entries for week, 30 for
  /// month, etc.
  Future<WeeklyStats> getRange(StatsRange range);
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
