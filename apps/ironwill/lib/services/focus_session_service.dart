import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/models.dart';
import '../widgets/session_active_pill.dart' show currentlyActiveSession;

/// Foreground service that anchors a system-tray persistent notification while
/// any focus session is in its scheduled window. Behaves like the flashlight
/// notification: it stays as long as the service runs and disappears when the
/// service stops. This is materially different from a regular ongoing
/// notification, which Android can dismiss when the process gets reaped.
///
/// The notification text is a short summary of the live session (name and
/// remaining minutes) plus a "Log quarter" action button that deep-links into
/// the time tracker.
class FocusSessionForegroundController {
  static const int _serviceId = 256;
  static bool _initialised = false;

  static void init() {
    if (_initialised) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'manup_focus_service',
        channelName: 'Focus session (active)',
        channelDescription: 'Persistent notification while a focus session is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(60000), // 1 min
        autoRunOnBoot: false,
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );
    _initialised = true;
  }

  /// Reconcile the live state. If a session is active and the service is not
  /// running, start it. If no session is active and the service is running,
  /// stop it. Idempotent on each call.
  static Future<void> reconcile(List<FocusSession> sessions) async {
    init();
    final running = await FlutterForegroundTask.isRunningService;
    final active = currentlyActiveSession(sessions);
    if (active == null) {
      if (running) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }
    final endMin = active.end.hour * 60 + active.end.minute;
    final now = DateTime.now();
    final remaining = endMin - (now.hour * 60 + now.minute);
    final body = remaining > 0
        ? 'Stay on it. ${remaining}m left. Tap to log a quarter.'
        : 'Wrapping up.';
    if (running) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Focus: ${active.name}',
        notificationText: body,
      );
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Focus: ${active.name}',
      notificationText: body,
      notificationButtons: const [
        NotificationButton(id: 'log', text: 'Log quarter'),
      ],
      callback: focusSessionTaskCallback,
    );
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

@pragma('vm:entry-point')
void focusSessionTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_FocusSessionTaskHandler());
}

class _FocusSessionTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    // The handler isolate has no DB access. We just keep the service alive so
    // the persistent notification stays. The main isolate's reconcile() call
    // (from app resume / data change) does the actual stop when the session
    // window ends.
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'log') {
      FlutterForegroundTask.launchApp('/time');
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/time');
  }
}
