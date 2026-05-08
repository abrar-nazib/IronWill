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
    return ValueListenableBuilder<List<Subject>>(
      valueListenable: svc.subjects.all,
      builder: (_, subjects, __) => ValueListenableBuilder<AppSettings>(
        valueListenable: svc.settings.settings,
        builder: (_, settings, __) {
          final active = currentlyActiveBlock(subjects, _now);
          if (active == null) return const SizedBox.shrink();
          final timing = computeBlockTiming(
            active,
            _now,
            blockSizeMinutes: settings.blockSizeMinutes,
          );
          return _Header(
            active: active,
            timing: timing,
            onTap: () => _openFloating(context, active),
          );
        },
      ),
    );
  }

  Future<void> _openFloating(BuildContext context, ActiveBlock active) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _FloatingTimerDialog(blockId: active.block.id),
    );
  }
}

/// Pure data: time math for an active block, computed off [now]. Includes
/// pomodoro context so the UI can tint the rest period and the "next log"
/// label can flip to "rest in" when pomodoro is enabled.
class BlockTiming {
  final Duration totalRemaining;

  /// Time until the next [blockSizeMinutes] boundary, OR the start of the
  /// pomodoro rest if that comes first (when pomodoro is enabled).
  final Duration toNextQuarter;

  /// True if pomodoro is on for this block AND `now` has crossed the rest
  /// boundary. Drives the "you're resting" tint and label.
  final bool inRestPeriod;

  /// The countdown the timer should display next. When pomodoro is on and
  /// we have NOT yet reached rest, this is the time until rest starts.
  /// Otherwise it's the same as [toNextQuarter].
  final Duration toNextSignal;

  /// The minute boundary used for [toNextQuarter] (15 / 30 / 60). Surfaced
  /// so the UI can label "to next 30 min" instead of always "to log".
  final int boundaryMinutes;

  /// Computed rest-start. Null when pomodoro is off or the rest window does
  /// not fit. Surfaced so the floating dialog can render the correct
  /// "rest in N min" copy regardless of whether toggled mid-block.
  final DateTime? restStartAt;
  const BlockTiming({
    required this.totalRemaining,
    required this.toNextQuarter,
    required this.inRestPeriod,
    required this.toNextSignal,
    required this.boundaryMinutes,
    this.restStartAt,
  });
}

/// Map of `blockId -> when the user toggled pomodoro on mid-flight`. Lets
/// `computeBlockTiming` size the rest window to the *remaining* time at
/// toggle, rather than retroactively eating into focus the user already did.
/// The map is in-memory only (resets on app restart). When pomodoro is on
/// from the start of the block, the entry is missing and we fall back to
/// the block's full duration as the reference.
final Map<String, DateTime> _pomodoroToggleTimes = <String, DateTime>{};

void notePomodoroToggle(String blockId, bool enabled, DateTime now) {
  if (enabled) {
    _pomodoroToggleTimes[blockId] = now;
  } else {
    _pomodoroToggleTimes.remove(blockId);
  }
}

BlockTiming computeBlockTiming(
  ActiveBlock active,
  DateTime now, {
  int blockSizeMinutes = 15,
}) {
  var total = active.endAt.difference(now);
  if (total.isNegative) total = Duration.zero;
  final sinceStart = now.difference(active.startAt);
  final secondsSinceStart = sinceStart.inSeconds.clamp(0, 1 << 31);
  final tickSeconds = blockSizeMinutes * 60;
  final secondsToNextQuarter = tickSeconds - (secondsSinceStart % tickSeconds);
  var toNext = Duration(seconds: secondsToNextQuarter);
  if (toNext > total) toNext = total;

  Duration toNextSignal = toNext;
  bool inRest = false;
  DateTime? restStartAt;
  if (active.block.pomodoroEnabled) {
    // Reference point for the rest window: if the user toggled pomodoro
    // mid-flight, size the rest from THAT moment forward instead of the
    // block start. Otherwise rest scales with the full block duration.
    final toggledAt = _pomodoroToggleTimes[active.block.id];
    final ref = (toggledAt != null && toggledAt.isAfter(active.startAt))
        ? toggledAt
        : active.startAt;
    final remainingMinutes = active.endAt.difference(ref).inMinutes;
    final restMinutes =
        (remainingMinutes * active.block.pomodoroPercent / 100).round();
    if (restMinutes > 0 && restMinutes < remainingMinutes) {
      final restStart =
          active.endAt.subtract(Duration(minutes: restMinutes));
      restStartAt = restStart;
      if (!now.isBefore(restStart)) {
        inRest = true;
        toNextSignal = total;
      } else {
        final toRest = restStart.difference(now);
        if (toRest < toNextSignal) toNextSignal = toRest;
      }
    }
  }

  return BlockTiming(
    totalRemaining: total,
    toNextQuarter: toNext,
    inRestPeriod: inRest,
    toNextSignal: toNextSignal,
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
  final ActiveBlock active;
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
    // During pomodoro rest the pill switches from ember to a calmer steel tone
    // so the user sees at a glance that they're in a break, not a focus block.
    final pillBg = timing.inRestPeriod ? t.steel : t.accent;
    final pillFg = timing.inRestPeriod ? t.bg : t.accentInk;
    final secondaryLabel = timing.inRestPeriod
        ? 'rest'
        : (active.block.pomodoroEnabled ? 'to rest' : 'to log');
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
                      active.subject.name,
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
                          _ms(timing.toNextSignal),
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
  final String blockId;
  const _FloatingTimerDialog({required this.blockId});

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
      child: ValueListenableBuilder<List<Subject>>(
        valueListenable: svc.subjects.all,
        builder: (_, subjects, __) => ValueListenableBuilder<AppSettings>(
          valueListenable: svc.settings.settings,
          builder: (_, settings, __) {
            final active = currentlyActiveBlock(subjects, _now);
            if (active == null || active.block.id != widget.blockId) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) Navigator.of(context).pop();
              });
              return const SizedBox.shrink();
            }
            final size = settings.blockSizeMinutes;
            final timing = computeBlockTiming(
              active,
              _now,
              blockSizeMinutes: size,
            );
            final block = active.block;
            // Rest-minutes copy in the pomodoro row mirrors the same
            // "from-toggle" reference so users see realistic numbers when
            // they enable pomodoro mid-flight.
            final toggledAt = _pomodoroToggleTimes[block.id];
            final ref = (toggledAt != null && toggledAt.isAfter(active.startAt))
                ? toggledAt
                : active.startAt;
            final restMinutes =
                ((active.endAt.difference(ref).inMinutes) *
                        block.pomodoroPercent /
                        100)
                    .round();
            final logLabel = size == 60
                ? 'Log this hour'
                : (size == 30 ? 'Log this 30 min' : 'Log this 15 min');
            final restLabel = size == 60
                ? 'NEXT LOG (HOURLY)'
                : (size == 30 ? 'NEXT LOG (30 MIN)' : 'NEXT LOG (15 MIN)');
            final secondaryLabel = timing.inRestPeriod
                ? 'REST PERIOD'
                : (block.pomodoroEnabled ? 'REST IN' : restLabel);
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
                          active.subject.name,
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
                  _BigTimerBlock(
                    label: 'TIME LEFT IN BLOCK',
                    value: _hms(timing.totalRemaining),
                    emphasized: true,
                    restMode: timing.inRestPeriod,
                  ),
                  const SizedBox(height: Sp.md),
                  _BigTimerBlock(
                    label: secondaryLabel,
                    value: _ms(timing.toNextSignal),
                    emphasized: false,
                    restMode: timing.inRestPeriod,
                  ),
                  const SizedBox(height: Sp.md),
                  _PomodoroRow(
                    block: block,
                    restMinutes: restMinutes,
                    onToggle: (v) async {
                      // Track the toggle moment so rest is sized from the
                      // remaining time, not the full block.
                      notePomodoroToggle(block.id, v, DateTime.now());
                      final svc = AppServices.of(context);
                      await svc.subjects.updateBlock(
                          block.copyWith(pomodoroEnabled: v));
                    },
                  ),
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

/// Per-block pomodoro switch shown inside the floating dialog. Toggling
/// updates the block via [SubjectsRepository.updateBlock] which cascades into
/// the schedule rebuild and notification reschedule via the wired listeners.
class _PomodoroRow extends StatelessWidget {
  final SubjectBlock block;
  final int restMinutes;
  final ValueChanged<bool> onToggle;
  const _PomodoroRow({
    required this.block,
    required this.restMinutes,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(R.s),
        border: Border.all(color: t.divider),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.coffee, color: t.ink, size: IconSize.m),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Pomodoro',
                    style: AppText.bodyStrong.copyWith(color: t.ink)),
                Text(
                  block.pomodoroEnabled
                      ? 'Last $restMinutes min of this block is rest (${block.pomodoroPercent}%).'
                      : 'No rest. The full block counts as focus.',
                  style: AppText.label.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: block.pomodoroEnabled,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}
