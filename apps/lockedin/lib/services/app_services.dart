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

  const AppServices({
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
