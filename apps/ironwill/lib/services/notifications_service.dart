import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';

/// Local notifications, fully offline. Three classes of notification:
///
/// 1. **Habit reminders.** One per active habit, scheduled daily (or on the
///    selected weekdays) at the habit reminder time.
/// 2. **Focus session quarter ticks.** While a focus session window is active,
///    one notification fires at every 15 minute mark to remind the user to log
///    the just-finished quarter. Tapping deep links into the time tracker.
/// 3. **Focus session active marker.** A persistent (ongoing) notification at
///    session start, scheduled to time out at session end. Reads "Session
///    active" so the user can see at a glance.
class NotificationsService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Broadcast stream of notification payloads. Fires when the user taps any
  /// scheduled notification while the app is foreground OR resumed. Cold-start
  /// taps are surfaced via [consumeLaunchPayload] instead.
  final StreamController<String> _actions = StreamController<String>.broadcast();
  Stream<String> get onAction => _actions.stream;

  /// Read the payload (if any) of the notification that launched the app from
  /// a cold state. Returns null if the app was opened normally. Call this once
  /// at startup; subsequent calls return null.
  Future<String?> consumeLaunchPayload() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  void _onResponse(NotificationResponse r) {
    final p = r.payload;
    if (p == null || p.isEmpty) return;
    if (!_actions.isClosed) _actions.add(p);
  }

  static const habitChannelName = 'Habit reminders';
  static const sessionChannelName = 'Subject block';

  /// Channel ids vary by chosen sound so a sound change takes effect without
  /// forcing the user to clear notification settings. The channel is created
  /// lazily on first post for that sound.
  String _habitChannel(AlarmSound s) => 'lockedin_habit_${s.name}';
  String _sessionChannel(AlarmSound s) => 'lockedin_session_${s.name}';

  /// Notification id ranges:
  /// - 1000..1999: habit reminders
  /// - 2000..2999: session start (active) markers
  /// - 100000..2^31: session quarter ticks
  ///
  /// Quarter-tick ids are hashed from the full tuple `(sessionId, qIndex)`
  /// across a ~2.1B bucket space to make collisions effectively impossible.
  /// Each FocusSession owns its own id namespace so two sessions back-to-back
  /// (or the same subject on consecutive days) never share a tick id.
  static int habitReminderId(String habitId) => 1000 + (habitId.hashCode & 0x3FF);
  static int sessionActiveId(String sessionId, int day) =>
      2000 + ((sessionId.hashCode + day * 31) & 0x3FF);
  static int sessionTickId(String sessionId, int qIndex) {
    final raw = '$sessionId:$qIndex'.hashCode;
    return 100000 + (raw.abs() % (1 << 30));
  }

  String? _alarmRawResource(AlarmSound s) => switch (s) {
        AlarmSound.softChime => 'soft_chime',
        AlarmSound.gong => 'gong',
        AlarmSound.deepBell => 'deep_bell',
        AlarmSound.bowl => 'singing_bowl',
        AlarmSound.none => null,
      };

  Future<void> init() async {
    if (_ready) return;
    if (!(Platform.isAndroid || Platform.isIOS)) {
      _ready = true;
      return;
    }
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      // Fall back to UTC if the system timezone name is not in the IANA db.
      // The user can set the system tz manually; ticks would then fire in UTC.
    }
    const init = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _onResponse,
    );
    if (Platform.isAndroid) {
      await _ensureChannelsForAllSounds();
      // Cancel any leftover legacy "session active" notifications scheduled
      // by older builds via show() / zonedSchedule. The foreground service
      // owns the persistent notification now, so anything else in the
      // sessionActiveId range is stale.
      for (int id = 2000; id < 3000; id++) {
        await _plugin.cancel(id);
      }
    }
    _ready = true;
  }

  /// Pre-create channels for every alarm sound so notifications can post
  /// without a "no such channel" stall. Channels in Android can't have their
  /// sound changed after creation; we vary the channel id by sound choice.
  Future<void> _ensureChannelsForAllSounds() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    for (final s in AlarmSound.values) {
      final raw = _alarmRawResource(s);
      final sound = raw == null ? null : RawResourceAndroidNotificationSound(raw);
      await android.createNotificationChannel(AndroidNotificationChannel(
        _habitChannel(s),
        habitChannelName,
        importance: Importance.high,
        sound: sound,
        playSound: s != AlarmSound.none,
      ));
      await android.createNotificationChannel(AndroidNotificationChannel(
        _sessionChannel(s),
        sessionChannelName,
        importance: Importance.high,
        sound: sound,
        playSound: s != AlarmSound.none,
      ));
    }
  }

  Future<void> requestPermissions() async {
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    if (Platform.isAndroid) {
      await Permission.notification.request();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Horizon for session-tick pre-scheduling. We only register alarms that
  /// fire within this window; the 30 second reconcile ticker (in
  /// `main.dart`) re-runs `rescheduleAll` to keep the queue topped up.
  ///
  /// Why a short horizon (instead of pre-scheduling the full week):
  ///   * Mid-session settings changes propagate cleanly because the queue
  ///     has at most a handful of alarms to invalidate.
  ///   * No risk of id-namespace collisions piling up across many cycles.
  ///   * If the user kills the app, the last few scheduled alarms still
  ///     fire (AlarmManager survives process death). When the user returns
  ///     within ~2 h, the ticker picks back up.
  static const Duration sessionTickHorizon = Duration(hours: 2);

  Future<void> rescheduleAll({
    required List<Habit> habits,
    required List<FocusSession> sessions,
    required List<Subject> subjects,
    required AppSettings settings,
  }) async {
    if (!_ready || !(Platform.isAndroid || Platform.isIOS)) return;
    // `cancelAll()` proved unreliable in practice on Android: the plugin's
    // internal tracking can drift from the OS AlarmManager (especially
    // after `install -r`), so stale alarms survive into the new schedule.
    // Enumerate pendingNotificationRequests and cancel each by id - this
    // is the same set the plugin would walk internally, but doing it
    // explicitly forces a fresh cycle.
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      await _plugin.cancel(p.id);
    }
    if (settings.reminderLogging) {
      for (final h in habits.where((h) => !h.archived && h.reminderOn)) {
        await _scheduleHabitReminder(h, settings.alarm);
      }
    }
    final subjectsById = {for (final s in subjects) s.id: s};
    final now = DateTime.now();
    final horizon = now.add(sessionTickHorizon);
    // Walk every session whose window overlaps [now, horizon]. Each gets
    // its log/rest ticks scheduled. The reconcile ticker in main.dart
    // re-runs this on a 30 s cadence so a session that starts later in
    // the day will pick up its ticks once it slides into the window.
    for (final session in sessions) {
      if (!session.endAt.isAfter(now)) continue;
      if (session.startAt.isAfter(horizon)) continue;
      final subjectName = session.subjectId == null
          ? 'Focus session'
          : (subjectsById[session.subjectId]?.name ?? 'Focus session');
      await _scheduleSession(session, subjectName, settings, horizon);
    }
    // The persistent "session active" notification is driven by a proper
    // foreground service (see FocusSessionForegroundController) so it
    // persists like the system flashlight notification rather than a
    // regular ongoing notification that Android can dismiss.
  }

  /// User-triggered "send a notification right now" for the test button in
  /// Settings, so they can verify the channel and sound without waiting.
  Future<void> sendTestNotification(AlarmSound alarm) async {
    if (!_ready || !(Platform.isAndroid || Platform.isIOS)) return;
    await _plugin.show(
      9999,
      'LockedIn test notification',
      'If you see this with sound, your reminders are wired correctly.',
      _details(
        channel: _habitChannel(alarm),
        channelName: habitChannelName,
        alarm: alarm,
      ),
    );
  }

  tz.TZDateTime _local(DateTime dt) => tz.TZDateTime.from(dt, tz.local);

  Future<void> _scheduleHabitReminder(Habit h, AlarmSound alarm) async {
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, h.reminder.hour, h.reminder.minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      habitReminderId(h.id),
      h.name,
      h.description.isEmpty ? 'Time to log this habit.' : h.description,
      _local(when),
      _details(channel: _habitChannel(alarm), channelName: habitChannelName, alarm: alarm),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'habit:${h.id}',
    );
  }

  /// Schedule log + (optional) rest ticks across one [FocusSession]. The
  /// session window is split into cycles of `settings.blockSizeMinutes`.
  /// A mandatory log tick fires at each cycle end; when pomodoro is on,
  /// an extra "rest now" tick fires at `cycleEnd - restMinutes` inside
  /// the same cycle.
  Future<void> _scheduleSession(
    FocusSession session,
    String subjectName,
    AppSettings settings,
    DateTime horizon,
  ) async {
    final start = session.startAt;
    final end = session.endAt;
    if (!end.isAfter(start)) return;
    final now = DateTime.now();
    final alarm = settings.alarm;

    final pomoOn = settings.pomodoroEnabled;
    final pomoPercent = settings.pomodoroPercent;
    final blockSize = settings.blockSizeMinutes;
    final cycleStep = Duration(minutes: blockSize);

    var cycleStart = start;
    int qIndex = 0;
    while (cycleStart.isBefore(end)) {
      final naiveCycleEnd = cycleStart.add(cycleStep);
      final cycleEnd = naiveCycleEnd.isAfter(end) ? end : naiveCycleEnd;
      final cycleDurationMin = cycleEnd.difference(cycleStart).inMinutes;

      if (cycleStart.isAfter(horizon)) break;

      if (cycleEnd.isAfter(now)) {
        await _plugin.zonedSchedule(
          sessionTickId(session.id, qIndex * 2),
          _cycleTitle(blockSize, subjectName),
          'How focused were you the past $cycleDurationMin min? Tap to log.',
          _local(cycleEnd),
          _details(
              channel: _sessionChannel(alarm),
              channelName: sessionChannelName,
              alarm: alarm),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'session_tick:${session.id}',
        );
      }

      if (pomoOn) {
        final restMinutes = (cycleDurationMin * pomoPercent / 100).round();
        if (restMinutes > 0 && restMinutes < cycleDurationMin) {
          final restStart =
              cycleEnd.subtract(Duration(minutes: restMinutes));
          if (restStart.isAfter(now)) {
            await _plugin.zonedSchedule(
              sessionTickId(session.id, qIndex * 2 + 1),
              'Rest now  ·  $subjectName',
              'Take a $restMinutes min rest. The log nudge will fire when rest ends.',
              _local(restStart),
              _details(
                  channel: _sessionChannel(alarm),
                  channelName: sessionChannelName,
                  alarm: alarm),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              payload: 'session_tick:${session.id}',
            );
          }
        }
      }

      cycleStart = naiveCycleEnd;
      qIndex++;
    }
  }

  String _cycleTitle(int blockSize, String name) =>
      (blockSize == 60
          ? 'Hour ended  ·  '
          : (blockSize == 30 ? '30 min ended  ·  ' : 'Quarter ended  ·  ')) +
      name;

  NotificationDetails _details({
    required String channel,
    required String channelName,
    required AlarmSound alarm,
    bool ongoing = false,
    bool autoCancel = true,
    int? timeoutAfterMs,
  }) {
    final raw = _alarmRawResource(alarm);
    final sound = raw == null ? null : RawResourceAndroidNotificationSound(raw);
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        playSound: alarm != AlarmSound.none,
        sound: sound,
        ongoing: ongoing,
        autoCancel: autoCancel,
        timeoutAfter: timeoutAfterMs,
        category: ongoing ? AndroidNotificationCategory.progress : AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: alarm != AlarmSound.none,
      ),
    );
  }
}
