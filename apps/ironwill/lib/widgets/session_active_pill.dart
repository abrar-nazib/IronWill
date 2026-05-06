import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/models.dart';
import '../services/app_services.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Shown when "now" falls inside any focus session window. The widget
/// re-evaluates its state every minute on a timer so the pill appears and
/// disappears at the right time without relying on a setState somewhere else.
class SessionActivePill extends StatefulWidget {
  final VoidCallback? onTap;
  const SessionActivePill({super.key, this.onTap});

  @override
  State<SessionActivePill> createState() => _SessionActivePillState();
}

class _SessionActivePillState extends State<SessionActivePill> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
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
        return _Pill(session: active, onTap: widget.onTap);
      },
    );
  }
}

FocusSession? currentlyActiveSession(List<FocusSession> sessions) {
  final now = DateTime.now();
  final today = now.weekday;
  final mins = now.hour * 60 + now.minute;
  for (final s in sessions) {
    if (!s.daysOfWeek.contains(today)) continue;
    final start = s.start.hour * 60 + s.start.minute;
    final end = s.end.hour * 60 + s.end.minute;
    if (mins >= start && mins < end) return s;
  }
  return null;
}

class _Pill extends StatelessWidget {
  final FocusSession session;
  final VoidCallback? onTap;
  const _Pill({required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    final mins = now.hour * 60 + now.minute;
    final endMin = session.end.hour * 60 + session.end.minute;
    final remaining = endMin - mins;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(R.s),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: Text(
                'Session active  ·  ${session.name}',
                style: AppText.bodyStrong.copyWith(color: t.accentInk, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Sp.s),
            Text('${remaining}m left',
                style: AppText.mono.copyWith(color: t.accentInk.withValues(alpha: 0.85), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
