import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/models.dart';
import '../services/app_services.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'session_active_pill.dart' show currentlyActiveSession;

/// Live dual timer for the currently active focus session.
///
/// Header style: compact ember pill that fits in a Today / Time screen sliver.
/// Shows the session name, total remaining (HH:MM:SS) and time to the next
/// 15-minute accountability tick (MM:SS). Updates every second.
///
/// Tap the timer to open a full-screen floating timer that keeps the screen
/// awake (via wakelock_plus) while it is open. Useful for tracking the
/// remaining time at a glance without the device locking.
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
      valueListenable: svc.sessions.all,
      builder: (_, sessions, __) {
        final active = currentlyActiveSession(sessions);
        if (active == null) return const SizedBox.shrink();
        final timing = computeSessionTiming(active, _now);
        return _Header(
          session: active,
          timing: timing,
          onTap: () => _openFloating(context, active),
        );
      },
    );
  }

  Future<void> _openFloating(BuildContext context, FocusSession session) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _FloatingTimerDialog(sessionId: session.id),
    );
  }
}

/// Pure data: time math for an active session, computed off [now].
class SessionTiming {
  final Duration totalRemaining;
  final Duration toNextQuarter;
  const SessionTiming({
    required this.totalRemaining,
    required this.toNextQuarter,
  });
}

SessionTiming computeSessionTiming(FocusSession s, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = today.add(Duration(hours: s.start.hour, minutes: s.start.minute));
  final end = today.add(Duration(hours: s.end.hour, minutes: s.end.minute));
  var total = end.difference(now);
  if (total.isNegative) total = Duration.zero;
  final sinceStart = now.difference(start);
  final secondsSinceStart = sinceStart.inSeconds.clamp(0, 1 << 31);
  final secondsToNextQuarter =
      900 - (secondsSinceStart % 900);
  var toNext = Duration(seconds: secondsToNextQuarter);
  if (toNext > total) toNext = total;
  return SessionTiming(totalRemaining: total, toNextQuarter: toNext);
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
  final FocusSession session;
  final SessionTiming timing;
  final VoidCallback onTap;
  const _Header({
    required this.session,
    required this.timing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(R.s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.s),
          decoration: BoxDecoration(
            color: t.accent,
            borderRadius: BorderRadius.circular(R.s),
          ),
          child: Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: t.accentInk,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Sp.s),
              Icon(LucideIcons.target, color: t.accentInk, size: IconSize.s),
              const SizedBox(width: Sp.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      session.name,
                      style: AppText.bodyStrong.copyWith(
                        color: t.accentInk,
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
                            color: t.accentInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: Sp.s),
                        Text('total',
                            style: AppText.label.copyWith(
                              color: t.accentInk.withValues(alpha: 0.75),
                              fontSize: 10,
                            )),
                        const SizedBox(width: Sp.m),
                        Text(
                          _ms(timing.toNextQuarter),
                          style: AppText.mono.copyWith(
                            color: t.accentInk,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: Sp.s),
                        Text('to log',
                            style: AppText.label.copyWith(
                              color: t.accentInk.withValues(alpha: 0.75),
                              fontSize: 10,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(LucideIcons.maximize2,
                  color: t.accentInk.withValues(alpha: 0.85), size: IconSize.s),
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
        valueListenable: svc.sessions.all,
        builder: (_, sessions, __) {
          final session = sessions.where((s) => s.id == widget.sessionId).firstOrNull;
          if (session == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }
          final timing = computeSessionTiming(session, _now);
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
                        session.name,
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
                  'Screen stays on while this is open.',
                  style: AppText.label.copyWith(color: t.inkMuted),
                ),
                const SizedBox(height: Sp.lg),
                _BigTimerBlock(
                  label: 'TIME LEFT IN SESSION',
                  value: _hms(timing.totalRemaining),
                  emphasized: true,
                ),
                const SizedBox(height: Sp.md),
                _BigTimerBlock(
                  label: 'NEXT LOG IN',
                  value: _ms(timing.toNextQuarter),
                  emphasized: false,
                ),
                const SizedBox(height: Sp.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.bellRing),
                        label: const Text('Log this quarter'),
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
    );
  }
}

class _BigTimerBlock extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;
  const _BigTimerBlock({
    required this.label,
    required this.value,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = emphasized ? t.ink : t.surfaceAlt;
    final fg = emphasized ? t.bg : t.ink;
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
