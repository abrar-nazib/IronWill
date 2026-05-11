import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../models/models.dart';
import '../widgets/active_session_timer.dart' show computeBlockTiming;

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
        channelId: 'lockedin_focus_service',
        channelName: 'Active focus block',
        channelDescription: 'Persistent notification while a subject block is in progress.',
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

  /// Reconcile the live state. If a focus session is currently inside
  /// its `[startAt, endAt)` window and the service is not running, start
  /// it. If none is active and the service is running, stop it.
  /// Idempotent on each call. After start/update, the active session's
  /// start, end, subject name, blockSize and pomodoro settings are sent
  /// to the task isolate so its 1Hz tick renders a live timer in the
  /// notification using the same math as the in-app dialog.
  static Future<void> reconcile({
    required List<FocusSession> sessions,
    required List<Subject> subjects,
    required AppSettings settings,
  }) async {
    init();
    final running = await FlutterForegroundTask.isRunningService;
    final active = currentlyActiveSession(sessions, subjects, DateTime.now());
    if (active == null) {
      if (running) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }
    final initialBody = _renderBody(active, DateTime.now(), settings);
    final title = 'Focus: ${active.displayName}';
    if (running) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: initialBody,
      );
    } else {
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: title,
        notificationText: initialBody,
        notificationButtons: const [
          NotificationButton(id: 'log', text: 'Log block'),
        ],
        callback: focusSessionTaskCallback,
      );
    }
    FlutterForegroundTask.sendDataToTask({
      'startMs': active.startAt.millisecondsSinceEpoch,
      'endMs': active.endAt.millisecondsSinceEpoch,
      'name': active.displayName,
      'blockSize': settings.blockSizeMinutes,
      'pomoOn': settings.pomodoroEnabled,
      'pomoPercent': settings.pomodoroPercent,
    });
  }

  /// Render the tray body using the same math as the in-app dialog so the
  /// numbers stay consistent across surfaces. Four formats:
  ///   * before session start:   "Starts in MM:SS"
  ///   * pomodoro off, in-session: "Total HH:MM:SS  ·  Log in MM:SS"
  ///   * pomodoro on, focusing:  "Total HH:MM:SS  ·  Rest in MM:SS"
  ///   * pomodoro on, resting:   "Total HH:MM:SS  ·  Resting"
  static String _renderBody(
    ActiveSession active,
    DateTime now,
    AppSettings settings,
  ) {
    if (now.isBefore(active.startAt)) {
      final toStart = active.startAt.difference(now);
      return 'Starts in ${_ms(toStart)}';
    }
    final timing = computeBlockTiming(
      active,
      now,
      blockSizeMinutes: settings.blockSizeMinutes,
      pomodoroEnabled: settings.pomodoroEnabled,
      pomodoroPercent: settings.pomodoroPercent,
    );
    final total = _hms(timing.totalRemaining);
    if (!settings.pomodoroEnabled) {
      return 'Total $total  ·  Log in ${_ms(timing.toNextLog)}';
    }
    if (timing.inRestPeriod) {
      return 'Total $total  ·  Resting';
    }
    final next = timing.toNextRest ?? timing.toNextLog;
    return 'Total $total  ·  Rest in ${_ms(next)}';
  }

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
  int _blockSize = 15;
  bool _pomoOn = false;
  int _pomoPercent = 15;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    _startMs = (data['startMs'] as num?)?.toInt();
    _endMs = (data['endMs'] as num?)?.toInt();
    _name = (data['name'] as String?) ?? _name;
    _blockSize = (data['blockSize'] as num?)?.toInt() ?? _blockSize;
    _pomoOn = (data['pomoOn'] as bool?) ?? _pomoOn;
    _pomoPercent = (data['pomoPercent'] as num?)?.toInt() ?? _pomoPercent;
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
    final now = DateTime.now();
    // Self-stop guard. Without this, an app process killed mid-session
    // (Samsung battery saver, OOM, force-stop) would leave the task
    // isolate ticking forever with stale start/end. Stop 5 minutes after
    // the block's scheduled end so brief overruns or quick logging still
    // see the timer.
    if (now.isAfter(end.add(const Duration(minutes: 5)))) {
      FlutterForegroundTask.stopService();
      return;
    }
    // Synthesise the inputs the in-app math wants. The task isolate has
    // no AppServices; ActiveSession just needs startAt/endAt for the timer
    // and a stub session/subject to satisfy the type.
    final stubSession = FocusSession(
      id: 'fg',
      subjectId: null,
      startAt: start,
      endAt: end,
      createdAt: start,
    );
    final active = ActiveSession(
      session: stubSession,
      subject: null,
      startAt: start,
      endAt: end,
    );
    final settings = AppSettings(
      blockSizeMinutes: _blockSize,
      pomodoroEnabled: _pomoOn,
      pomodoroPercent: _pomoPercent,
    );
    final body = FocusSessionForegroundController._renderBody(
        active, DateTime.now(), settings);
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
