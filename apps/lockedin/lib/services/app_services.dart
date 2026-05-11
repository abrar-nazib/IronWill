import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/backup.dart';
import '../data/local_db.dart';
import '../data/mock_db.dart';
import '../data/mock_repositories.dart';
import '../data/repositories.dart';
import '../data/sqlite_repositories.dart';
import 'focus_session_service.dart';
import 'notifications_service.dart';

/// Stores the subject the user last applied when logging a time block.
/// "Last applied" includes an explicit "No subject" pick (i.e. `null`
/// can be a meaningful value, distinct from "never picked"). The
/// notifier lives in [AppServices] and survives across logging actions
/// in the same app session.
class LastPickedLog {
  final String? subjectId;
  final bool isSet;
  const LastPickedLog._({this.subjectId, this.isSet = false});

  /// Initial state: the user hasn't logged anything yet in this session.
  /// Call sites fall through to other inference sources (existing block
  /// tag, overlapping focus session, etc.).
  const LastPickedLog.empty() : this._();

  /// The user just logged with this subject (which may be null,
  /// meaning "No subject" was explicitly chosen).
  const LastPickedLog.value(String? id) : this._(subjectId: id, isSet: true);
}

/// Service container. Wraps every repository the app needs. Bind it once at
/// the top of the widget tree via [AppServicesScope] and read it from any
/// widget via `AppServices.of(context)`.
class AppServices {
  final HabitsRepository habits;
  final TimeRepository time;
  final SubjectsRepository subjects;
  final FocusSessionsRepository focusSessions;
  final StatsRepository stats;
  final ProfileRepository profile;
  final SettingsRepository settings;
  final BackupService? backup;
  final NotificationsService notifications;

  /// Tracks the user's most recent subject pick when logging a time
  /// block. Reset between app launches. The log sheet uses this when
  /// the block has no existing subject tag, so repeated logging in a
  /// row defaults to the same subject the user chose last time
  /// (including "No subject").
  final ValueNotifier<LastPickedLog> lastPickedLogSubject =
      ValueNotifier<LastPickedLog>(const LastPickedLog.empty());

  /// Which date the Time tab is currently showing. Lifted out of
  /// [TrackerScreen]'s State so it survives tab switches. Without
  /// this, every tap on the Time tab from the bottom nav threw the
  /// user back to today, which mis-routed past-day logs into today
  /// (the user navigated to yesterday, switched tabs, came back, then
  /// tapped a block expecting yesterday but the State had reset).
  ///
  /// Initialised to today exactly once when AppServices is built. We
  /// deliberately do NOT auto-snap to today on every rebuild: the
  /// modal log sheet triggers didChangeDependencies, which would
  /// otherwise flip the date out from under an in-flight log call
  /// and silently route past-day writes into today. The "BACK TO
  /// TODAY" pill in the tracker AppBar is the user-facing escape.
  final ValueNotifier<DateTime> trackerDate =
      ValueNotifier<DateTime>(_todayMidnight());

  static DateTime _todayMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  AppServices({
    required this.habits,
    required this.time,
    required this.subjects,
    required this.focusSessions,
    required this.stats,
    required this.profile,
    required this.settings,
    required this.notifications,
    this.backup,
  });

  /// In-memory mock backend. Used during early UI iteration and fallback when
  /// the platform cannot host SQLite (e.g. web).
  factory AppServices.mock() {
    final db = MockDb.instance;
    final subjects = MockSubjectsRepository(db);
    final focusSessions = MockFocusSessionsRepository(db);
    final time = MockTimeRepository(db);
    final habits = MockHabitsRepository(db);
    final profile = MockProfileRepository(db);
    final settings = MockSettingsRepository(db);
    return AppServices(
      habits: habits,
      time: time,
      subjects: subjects,
      focusSessions: focusSessions,
      stats: MockStatsRepository(db),
      profile: profile,
      settings: settings,
      notifications: NotificationsService(),
    );
  }

  /// SQLite-backed offline backend. Pass an already-opened [LocalDb] in.
  factory AppServices.live(LocalDb ldb) {
    final habits = SqliteHabitsRepository(ldb);
    final time = SqliteTimeRepository(ldb);
    final subjects = SqliteSubjectsRepository(ldb);
    final focusSessions = SqliteFocusSessionsRepository(ldb);
    final profile = SqliteProfileRepository(ldb);
    final settings = SqliteSettingsRepository(ldb);
    final stats =
        SqliteStatsRepository(habits, time, profile, subjects, focusSessions);
    final notifications = NotificationsService();
    final services = AppServices(
      habits: habits,
      time: time,
      subjects: subjects,
      focusSessions: focusSessions,
      stats: stats,
      profile: profile,
      settings: settings,
      backup: BackupService(ldb),
      notifications: notifications,
    );
    _wireNotificationReschedule(services);
    return services;
  }

  static void _wireNotificationReschedule(AppServices svc) {
    Timer? debounce;
    void reschedule() {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 250), () async {
        await svc.notifications.rescheduleAll(
          habits: svc.habits.all.value,
          sessions: svc.focusSessions.all.value,
          subjects: svc.subjects.all.value,
          settings: svc.settings.settings.value,
        );
        await FocusSessionForegroundController.reconcile(
          sessions: svc.focusSessions.all.value,
          subjects: svc.subjects.all.value,
          settings: svc.settings.settings.value,
        );
      });
    }
    svc.habits.all.addListener(reschedule);
    svc.subjects.all.addListener(reschedule);
    svc.focusSessions.all.addListener(reschedule);
    svc.settings.settings.addListener(reschedule);
  }

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppServicesScope>();
    assert(scope != null, 'AppServicesScope missing in widget tree');
    return scope!.services;
  }
}

class AppServicesScope extends InheritedWidget {
  final AppServices services;
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) =>
      oldWidget.services != services;
}
