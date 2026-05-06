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
  if (kIsWeb) {
    services = AppServices.mock();
  } else {
    final ldb = await LocalDb.open();
    await seedIfFirstRun(ldb);
    services = AppServices.live(ldb);
    await services.notifications.init();
    await services.notifications.requestPermissions();
    FocusSessionForegroundController.init();
    await services.notifications.rescheduleAll(
      habits: services.habits.all.value,
      sessions: services.sessions.all.value,
      settings: services.settings.settings.value,
    );
    await FocusSessionForegroundController.reconcile(services.sessions.all.value);
  }

  runApp(IronWillApp(services: services));
}

class IronWillApp extends StatefulWidget {
  final AppServices services;
  const IronWillApp({super.key, required this.services});

  @override
  State<IronWillApp> createState() => _IronWillAppState();
}

class _IronWillAppState extends State<IronWillApp> with WidgetsBindingObserver {
  late final _router = buildRouter(widget.services);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.services.notifications.rescheduleAll(
        habits: widget.services.habits.all.value,
        sessions: widget.services.sessions.all.value,
        settings: widget.services.settings.settings.value,
      );
      FocusSessionForegroundController.reconcile(widget.services.sessions.all.value);
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
              title: 'IronWill',
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
