import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'app_theme_controller.dart';
import 'data/local_db.dart';
import 'data/sqlite_repositories.dart';
import 'models/models.dart';
import 'router.dart';
import 'services/app_services.dart';
import 'services/focus_session_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
  );
  if (!kIsWeb) {
    FlutterForegroundTask.initCommunicationPort();
  }

  AppServices services;
  String? launchPayload;
  if (kIsWeb) {
    services = AppServices.mock();
  } else {
    final ldb = await LocalDb.open();
    await seedIfFirstRun(ldb);
    services = AppServices.live(ldb);
    await services.notifications.init();
    launchPayload = await services.notifications.consumeLaunchPayload();
    await services.notifications.requestPermissions();
    FocusSessionForegroundController.init();
    await services.notifications.rescheduleAll(
      habits: services.habits.all.value,
      subjects: services.subjects.all.value,
      settings: services.settings.settings.value,
    );
    await FocusSessionForegroundController.reconcile(
      services.subjects.all.value,
      settings: services.settings.settings.value,
    );
  }

  runApp(LockedInApp(services: services, launchPayload: launchPayload));
}

class LockedInApp extends StatefulWidget {
  final AppServices services;
  final String? launchPayload;
  const LockedInApp({super.key, required this.services, this.launchPayload});

  @override
  State<LockedInApp> createState() => _LockedInAppState();
}

class _LockedInAppState extends State<LockedInApp> with WidgetsBindingObserver {
  late final _router = buildRouter(widget.services);
  StreamSubscription<String>? _notifSub;
  Timer? _reconcileTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _notifSub = widget.services.notifications.onAction.listen(_handleAction);
    if (widget.launchPayload != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAction(widget.launchPayload!);
      });
    }
    if (!kIsWeb) {
      FlutterForegroundTask.addTaskDataCallback(_handleForegroundTaskData);
      // Catch session start/end transitions while the app is open across the
      // boundary. Without this, the foreground service only starts when the
      // user re-opens the app or saves a session/habit.
      // Refresh the foreground service AND keep the session-tick alarm
      // queue topped up. With NotificationsService.sessionTickHorizon
      // pegged at ~2 h, this 30 s loop is what slides the window forward
      // through long sessions without ever holding stale alarms past a
      // settings change.
      _reconcileTicker = Timer.periodic(const Duration(seconds: 30), (_) async {
        await widget.services.notifications.rescheduleAll(
          habits: widget.services.habits.all.value,
          subjects: widget.services.subjects.all.value,
          settings: widget.services.settings.settings.value,
        );
        await FocusSessionForegroundController.reconcile(
          widget.services.subjects.all.value,
          settings: widget.services.settings.settings.value,
        );
      });
    }
  }

  @override
  void dispose() {
    _reconcileTicker?.cancel();
    _notifSub?.cancel();
    if (!kIsWeb) {
      FlutterForegroundTask.removeTaskDataCallback(_handleForegroundTaskData);
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleForegroundTaskData(Object data) {
    if (data is String) _handleAction(data);
  }

  /// Maps a notification payload to a route. Today: any session-tick or
  /// log-from-foreground-service tap routes to `/time?log=now`, which the
  /// tracker screen interprets as "open the smart quarter picker now."
  void _handleAction(String payload) {
    if (payload.startsWith('session_tick:') || payload == 'open_log') {
      _router.go('/time?log=now');
    } else if (payload.startsWith('habit:')) {
      _router.go('/habits');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.services.notifications.rescheduleAll(
        habits: widget.services.habits.all.value,
        subjects: widget.services.subjects.all.value,
        settings: widget.services.settings.settings.value,
      );
      FocusSessionForegroundController.reconcile(
        widget.services.subjects.all.value,
        settings: widget.services.settings.settings.value,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppServicesScope(
      services: widget.services,
      child: ValueListenableBuilder<AppSettings>(
        valueListenable: widget.services.settings.settings,
        builder: (context, settings, _) {
          return AppThemeController(
            mode: themeChoiceToMode(settings.themeMode),
            setMode: (m) => widget.services.settings.update(
              settings.copyWith(themeMode: themeModeToChoice(m)),
            ),
            child: MaterialApp.router(
              title: 'LockedIn',
              debugShowCheckedModeBanner: false,
              theme: buildTheme(brightness: Brightness.light),
              darkTheme: buildTheme(brightness: Brightness.dark),
              themeMode: themeChoiceToMode(settings.themeMode),
              routerConfig: _router,
            ),
          );
        },
      ),
    );
  }
}
