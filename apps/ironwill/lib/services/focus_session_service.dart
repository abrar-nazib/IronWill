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
        // 1 second so the persistent notification can re-render the dual timer
        // (HH:MM:SS total + MM:SS to next quarter) live.
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: false,
        allowWifiLock: false,
      ),
    );
    _initialised = true;
  }

  /// Reconcile the live state. If a session is active and the service is not
  /// running, start it. If no session is active and the service is running,
  /// stop it. Idempotent on each call. After start/update, the active
  /// session's start and end (epoch ms) are sent to the task isolate so its
  /// 1Hz repeat tick can render a live dual timer in the notification.
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.add(Duration(hours: active.start.hour, minutes: active.start.minute));
    final end = today.add(Duration(hours: active.end.hour, minutes: active.end.minute));
    final initialBody = _renderBody(start, end, now);
    if (running) {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Focus: ${active.name}',
        notificationText: initialBody,
      );
    } else {
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: 'Focus: ${active.name}',
        notificationText: initialBody,
        notificationButtons: const [
          NotificationButton(id: 'log', text: 'Log quarter'),
        ],
        callback: focusSessionTaskCallback,
      );
    }
    FlutterForegroundTask.sendDataToTask({
      'startMs': start.millisecondsSinceEpoch,
      'endMs': end.millisecondsSinceEpoch,
      'name': active.name,
    });
  }

  /// Same dual-timer string the in-app pill renders. Kept here as a static so
  /// both isolates can render the same shape on first paint.
  static String _renderBody(DateTime start, DateTime end, DateTime now) {
    final total = _max(end.difference(now), Duration.zero);
    final since = now.difference(start).inSeconds.clamp(0, 1 << 31);
    final secondsToNext = 900 - (since % 900);
    var toNext = Duration(seconds: secondsToNext);
    if (toNext > total) toNext = total;
    return 'Total ${_hms(total)}  ·  Log in ${_ms(toNext)}';
  }

  static Duration _max(Duration a, Duration b) => a > b ? a : b;
  static String _hms(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  static String _ms(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
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
  int? _startMs;
  int? _endMs;
  String _name = 'Focus session';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    _startMs = (data['startMs'] as num?)?.toInt();
    _endMs = (data['endMs'] as num?)?.toInt();
    _name = (data['name'] as String?) ?? _name;
    _refreshNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _refreshNotification();
  }

  void _refreshNotification() {
    if (_startMs == null || _endMs == null) return;
    final start = DateTime.fromMillisecondsSinceEpoch(_startMs!);
    final end = DateTime.fromMillisecondsSinceEpoch(_endMs!);
    final body = FocusSessionForegroundController._renderBody(start, end, DateTime.now());
    FlutterForegroundTask.updateService(
      notificationTitle: 'Focus: $_name',
      notificationText: body,
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'log') {
      FlutterForegroundTask.launchApp('/time');
      FlutterForegroundTask.sendDataToMain('open_log');
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/time');
    FlutterForegroundTask.sendDataToMain('open_log');
  }
}
