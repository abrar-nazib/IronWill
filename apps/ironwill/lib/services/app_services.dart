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
  final StatsRepository stats;
  final ProfileRepository profile;
  final SettingsRepository settings;
  final BackupService? backup;
  final NotificationsService notifications;

  const AppServices({
    required this.habits,
    required this.time,
    required this.subjects,
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
    return AppServices(
      habits: MockHabitsRepository(db),
      time: MockTimeRepository(db),
      subjects: MockSubjectsRepository(db),
      stats: MockStatsRepository(db),
      profile: MockProfileRepository(db),
      settings: MockSettingsRepository(db),
      notifications: NotificationsService(),
    );
  }

  /// SQLite-backed offline backend. Pass an already-opened [LocalDb] in.
  factory AppServices.live(LocalDb ldb) {
    final habits = SqliteHabitsRepository(ldb);
    final time = SqliteTimeRepository(ldb);
    final subjects = SqliteSubjectsRepository(ldb);
    final profile = SqliteProfileRepository(ldb);
    final settings = SqliteSettingsRepository(ldb);
    final stats = SqliteStatsRepository(habits, time, profile);
    final notifications = NotificationsService();
    final services = AppServices(
      habits: habits,
      time: time,
      subjects: subjects,
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
          subjects: svc.subjects.all.value,
          settings: svc.settings.settings.value,
        );
        await FocusSessionForegroundController.reconcile(svc.subjects.all.value);
      });
    }
    svc.habits.all.addListener(reschedule);
    svc.subjects.all.addListener(reschedule);
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
