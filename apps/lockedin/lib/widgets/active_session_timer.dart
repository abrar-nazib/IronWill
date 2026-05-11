import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../services/app_services.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Live dual timer for the currently active focus block under any subject.
///
/// Header style: compact ember pill that fits in a Today / Time screen sliver.
/// Shows the subject name, total remaining (HH:MM:SS) and time to the next
/// 15-minute accountability tick (MM:SS). Updates every second.
///
/// Tap the timer to open a floating dialog that keeps the screen awake (via
/// wakelock_plus) while it is open. Useful for tracking the remaining time at
/// a glance without the device locking.
class ActiveSessionTimer extends StatefulWidget {
  const ActiveSessionTimer({super.key});

  @override
  State<ActiveSessionTimer> createState() => _ActiveSessionTimerState();
}

class _ActiveSessionTimerState extends State<ActiveSessionTimer> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = AppServices.of(context);
    return ValueListenableBuilder<List<FocusSession>>(
      valueListenable: svc.focusSessions.all,
      builder: (_, sessions, __) => ValueListenableBuilder<List<Subject>>(
        valueListenable: svc.subjects.all,
        builder: (_, subjects, __) => ValueListenableBuilder<AppSettings>(
          valueListenable: svc.settings.settings,
          builder: (_, settings, __) {
            final active = currentlyActiveSession(sessions, subjects, _now);
            if (active == null) return const SizedBox.shrink();
            final timing = computeBlockTiming(
              active,
              _now,
              blockSizeMinutes: settings.blockSizeMinutes,
              pomodoroEnabled: settings.pomodoroEnabled,
              pomodoroPercent: settings.pomodoroPercent,
            );
            return _Header(
              active: active,
              timing: timing,
              onTap: () => _openFloating(context, active),
            );
          },
        ),
      ),
    );
  }

  Future<void> _openFloating(BuildContext context, ActiveSession active) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _FloatingTimerDialog(sessionId: active.session.id),
    );
  }
}

/// Pure data: time math for an active block, computed off [now]. The UI
/// reads block-size and pomodoro state from the user's settings, so this
/// recomputes from scratch each tick. Three independent countdowns are
/// surfaced so the dialog can render up to three timers without merging.
class BlockTiming {
  /// Time left until the block ends.
  final Duration totalRemaining;

  /// Time until the next accountability log boundary (15 / 30 / 60 min,
  /// driven by the user's block-size setting). Capped at [totalRemaining]
  /// so the last partial bucket doesn't overshoot.
  final Duration toNextLog;

  /// Time until pomodoro rest starts. `null` when pomodoro is off, when
  /// the rest window doesn't fit (would be 0 or full block), or when we
  /// are already inside the rest window.
  final Duration? toNextRest;

  /// True if pomodoro is on for this block AND `now` has crossed the
  /// rest-start boundary. Drives the "you're resting" tint and label.
  final bool inRestPeriod;

  /// The minute boundary used for [toNextLog] (15 / 30 / 60). Surfaced
  /// so the UI can label "to next 30 min" instead of always "to log".
  final int boundaryMinutes;

  /// Computed rest-start. Null when pomodoro is off or the rest window
  /// does not fit. Stable reference so the UI can show "Rest at 09:51".
  final DateTime? restStartAt;
  const BlockTiming({
    required this.totalRemaining,
    required this.toNextLog,
    required this.toNextRest,
    required this.inRestPeriod,
    required this.boundaryMinutes,
    this.restStartAt,
  });
}

/// Per-cycle pomodoro: each logging cycle of [blockSizeMinutes] is treated
/// as one pomodoro slot. The slot is split into a focus phase and a rest
/// phase at [pomodoroPercent]. Example: blockSize 30 + pomo 15% gives focus
/// 25 min then rest 5 min, repeated until session end.
///
/// Returns three independent countdowns so the floating dialog can show
/// them as separate cards:
///   * [BlockTiming.totalRemaining] — until the subject session ends.
///   * [BlockTiming.toNextLog] — until the current cycle boundary
///     (always end-of-cycle, regardless of pomodoro).
///   * [BlockTiming.toNextRest] — until rest starts inside the current
///     cycle, or null when pomodoro is off / already inside rest.
BlockTiming computeBlockTiming(
  ActiveSession active,
  DateTime now, {
  int blockSizeMinutes = 15,
  bool pomodoroEnabled = false,
  int pomodoroPercent = 15,
}) {
  var total = active.endAt.difference(now);
  if (total.isNegative) total = Duration.zero;

  // Locate the current cycle. A cycle starts every blockSizeMinutes counted
  // from the subject session's startAt. The very last cycle may be cut
  // short when (endAt - cycleStart) < cycleSeconds.
  final cycleSeconds = blockSizeMinutes * 60;
  final secondsSinceStart =
      now.difference(active.startAt).inSeconds.clamp(0, 1 << 31);
  final cycleIndex = secondsSinceStart ~/ cycleSeconds;
  final cycleStart = active.startAt
      .add(Duration(seconds: cycleIndex * cycleSeconds));
  final naiveCycleEnd =
      cycleStart.add(Duration(seconds: cycleSeconds));
  final cycleEnd =
      naiveCycleEnd.isAfter(active.endAt) ? active.endAt : naiveCycleEnd;

  var toNextLog = cycleEnd.difference(now);
  if (toNextLog.isNegative) toNextLog = Duration.zero;

  bool inRest = false;
  DateTime? restStartAt;
  Duration? toNextRest;
  if (pomodoroEnabled) {
    final cycleDurationSeconds =
        cycleEnd.difference(cycleStart).inSeconds;
    final restSeconds =
        (cycleDurationSeconds * pomodoroPercent / 100).round();
    if (restSeconds > 0 && restSeconds < cycleDurationSeconds) {
      final restStart = cycleEnd.subtract(Duration(seconds: restSeconds));
      restStartAt = restStart;
      if (!now.isBefore(restStart)) {
        inRest = true;
        toNextRest = null;
      } else {
        toNextRest = restStart.difference(now);
      }
    }
  }

  return BlockTiming(
    totalRemaining: total,
    toNextLog: toNextLog,
    toNextRest: toNextRest,
    inRestPeriod: inRest,
    boundaryMinutes: blockSizeMinutes,
    restStartAt: restStartAt,
  );
}

String _hms(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return '${h.toString().padLeft(2, '0')}:'
      '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}';
}

String _ms(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

class _Header extends StatelessWidget {
  final ActiveSession active;
  final BlockTiming timing;
  final VoidCallback onTap;
  const _Header({
    required this.active,
    required this.timing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // During pomodoro rest the pill switches from ember to a calmer steel
    // tone so the user sees at a glance that they're in a break, not a
    // focus block. The header always shows two timers (total + to-next-log);
    // rest countdown lives only in the floating dialog per the simplified
    // surface contract.
    final pillBg = timing.inRestPeriod ? t.steel : t.accent;
    final pillFg = timing.inRestPeriod ? t.bg : t.accentInk;
    final secondaryLabel = timing.inRestPeriod ? 'rest' : 'to log';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: BorderRadius.circular(R.s),
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: pillFg,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Sp.s),
              Icon(
                timing.inRestPeriod ? LucideIcons.coffee : LucideIcons.target,
                color: pillFg,
                size: IconSize.s,
              ),
              const SizedBox(width: Sp.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      active.displayName,
                      style: AppText.bodyStrong.copyWith(
                        color: pillFg,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _hms(timing.totalRemaining),
                          style: AppText.mono.copyWith(
                            color: pillFg,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: Sp.s),
                        Text('total',
                            style: AppText.label.copyWith(
                              color: pillFg.withValues(alpha: 0.75),
                              fontSize: 10,
                            )),
                        const SizedBox(width: Sp.m),
                        Text(
                          _ms(timing.toNextLog),
                          style: AppText.mono.copyWith(
                            color: pillFg,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: Sp.s),
                        Text(secondaryLabel,
                            style: AppText.label.copyWith(
                              color: pillFg.withValues(alpha: 0.75),
                              fontSize: 10,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.maximize2,
                  color: pillFg.withValues(alpha: 0.85), size: IconSize.s),
            ],
          ),
        ),
      ),
    );
  }
}

class _FloatingTimerDialog extends StatefulWidget {
  final String sessionId;
  const _FloatingTimerDialog({required this.sessionId});

  @override
  State<_FloatingTimerDialog> createState() => _FloatingTimerDialogState();
}

class _FloatingTimerDialogState extends State<_FloatingTimerDialog> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _wakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    _enableWakelock();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
      _wakelockEnabled = true;
    } catch (_) {
      // Wakelock unavailable on this platform; the dialog still works.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_wakelockEnabled) {
      WakelockPlus.disable();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Dialog(
      backgroundColor: t.bg,
      insetPadding: const EdgeInsets.all(Sp.m),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(R.m)),
      child: ValueListenableBuilder<List<FocusSession>>(
        valueListenable: svc.focusSessions.all,
        builder: (_, sessions, __) => ValueListenableBuilder<List<Subject>>(
          valueListenable: svc.subjects.all,
          builder: (_, subjects, ___) => ValueListenableBuilder<AppSettings>(
            valueListenable: svc.settings.settings,
            builder: (_, settings, ____) {
              final active = currentlyActiveSession(sessions, subjects, _now);
              if (active == null || active.session.id != widget.sessionId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop();
              });
              return const SizedBox.shrink();
            }
            final size = settings.blockSizeMinutes;
            final pomodoroOn = settings.pomodoroEnabled;
            final timing = computeBlockTiming(
              active,
              _now,
              blockSizeMinutes: size,
              pomodoroEnabled: pomodoroOn,
              pomodoroPercent: settings.pomodoroPercent,
            );
            final logLabel = size == 60
                ? 'Log this hour'
                : (size == 30 ? 'Log this 30 min' : 'Log this 15 min');
            final logCardLabel = size == 60
                ? 'NEXT LOG (HOURLY)'
                : (size == 30 ? 'NEXT LOG (30 MIN)' : 'NEXT LOG (15 MIN)');
            return Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          active.displayName,
                          style: AppText.headline.copyWith(color: t.ink),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Text(
                    timing.inRestPeriod
                        ? 'Rest period.  Take it. Log the focus you just did.'
                        : 'Screen stays on while this is open.',
                    style: AppText.label.copyWith(
                      color: timing.inRestPeriod ? t.accent : t.inkMuted,
                      fontWeight: timing.inRestPeriod
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: Sp.lg),
                  // Timer 1: time left in this session.
                  _BigTimerBlock(
                    label: 'TIME LEFT IN SESSION',
                    value: _hms(timing.totalRemaining),
                    emphasized: true,
                    restMode: timing.inRestPeriod,
                  ),
                  const SizedBox(height: Sp.md),
                  // Timer 2: time left to next accountability log.
                  _BigTimerBlock(
                    label: logCardLabel,
                    value: _ms(timing.toNextLog),
                    emphasized: false,
                    restMode: timing.inRestPeriod,
                  ),
                  // Timer 3 (pomodoro only): time left to next rest, OR
                  // time left in the current rest window. Rest ends when
                  // the cycle's log tick fires, so during rest the
                  // remaining time IS `toNextLog`, NOT the whole-session
                  // remaining `totalRemaining` (which the user reported
                  // as "rest timer pulling session-timer numbers").
                  if (pomodoroOn) ...[
                    const SizedBox(height: Sp.md),
                    _BigTimerBlock(
                      label: timing.inRestPeriod ? 'REST ENDS IN' : 'NEXT REST IN',
                      value: timing.inRestPeriod
                          ? _ms(timing.toNextLog)
                          : _ms(timing.toNextRest ?? timing.totalRemaining),
                      emphasized: false,
                      restMode: timing.inRestPeriod,
                    ),
                  ],
                  const SizedBox(height: Sp.lg),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(LucideIcons.bellRing),
                          label: Text(logLabel),
                          onPressed: () {
                            Navigator.of(context).pop();
                            context.go('/time?log=now');
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
            },
          ),
        ),
      ),
    );
  }
}

class _BigTimerBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  /// During pomodoro rest the emphasized block flips from ink to ember so the
  /// user gets a strong visual signal that they're in a break.
  final bool restMode;
  const _BigTimerBlock({
    required this.label,
    required this.value,
    required this.emphasized,
    this.restMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Color bg;
    final Color fg;
    if (restMode && emphasized) {
      bg = t.accent;
      fg = t.accentInk;
    } else if (emphasized) {
      bg = t.ink;
      fg = t.bg;
    } else {
      bg = t.surfaceAlt;
      fg = t.ink;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Sp.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(R.s),
        border: Border.all(color: t.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg.withValues(alpha: 0.7),
                  )),
          const SizedBox(height: Sp.s),
          Text(value,
              style: AppText.display.copyWith(
                color: fg,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ],
      ),
    );
  }
}

