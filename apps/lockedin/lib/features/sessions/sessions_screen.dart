import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import 'edit_session_sheet.dart';
import 'quick_start_session_sheet.dart';

/// Lists every focus session past + present + future. Tap to edit; FAB
/// adds a new one. Sessions are grouped by day so the user can read the
/// schedule at a glance.
class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: const Text('Focus sessions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showQuickStartSessionSheet(context),
        icon: const Icon(LucideIcons.play),
        label: const Text('Start one now'),
      ),
      body: ValueListenableBuilder<List<FocusSession>>(
        valueListenable: svc.focusSessions.all,
        builder: (_, sessions, __) =>
            ValueListenableBuilder<List<Subject>>(
          valueListenable: svc.subjects.all,
          builder: (_, subjects, __) {
            final subjectsById = {for (final s in subjects) s.id: s};
            final groups = _groupByDay(sessions);
            return ListView(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
              children: [
                _PlanRecurringCard(),
                if (sessions.isEmpty) ...[
                  const SizedBox(height: Sp.md),
                  _Empty(),
                ],
                for (final entry in groups)
                  _DayGroup(
                    date: entry.date,
                    sessions: entry.sessions,
                    subjectsById: subjectsById,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<_DayEntry> _groupByDay(List<FocusSession> sessions) {
    final byDay = <DateTime, List<FocusSession>>{};
    for (final s in sessions) {
      final key = DateTime(s.startAt.year, s.startAt.month, s.startAt.day);
      (byDay[key] ??= []).add(s);
    }
    final entries = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries
        .map((e) => _DayEntry(date: e.key, sessions: e.value))
        .toList();
  }
}

class _DayEntry {
  final DateTime date;
  final List<FocusSession> sessions;
  const _DayEntry({required this.date, required this.sessions});
}

class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<FocusSession> sessions;
  final Map<String, Subject> subjectsById;
  const _DayGroup({
    required this.date,
    required this.sessions,
    required this.subjectsById,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final label = isToday
        ? 'Today, ${DateFormat('d MMM').format(date)}'
        : DateFormat('EEE, d MMM').format(date);
    return Padding(
      padding: const EdgeInsets.only(top: Sp.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Sp.s),
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: t.inkMuted, letterSpacing: 1.4),
            ),
          ),
          for (final s in sessions)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.s),
              child: _SessionRow(
                session: s,
                subject: s.subjectId == null
                    ? null
                    : subjectsById[s.subjectId],
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final FocusSession session;
  final Subject? subject;
  const _SessionRow({required this.session, required this.subject});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    final status = session.statusAt(now);
    final timeLabel =
        '${DateFormat('HH:mm').format(session.startAt)} → ${DateFormat('HH:mm').format(session.endAt)}';
    final durMin = session.durationMinutes;
    final durLabel = durMin >= 60
        ? '${(durMin / 60).toStringAsFixed(durMin % 60 == 0 ? 0 : 1)}h'
        : '${durMin}m';
    final accent = status == FocusSessionStatus.active ? t.accent : t.ink;
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      onTap: () => showEditSessionSheet(context, existing: session),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(R.xs),
            ),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject?.name ?? 'Focus session',
                  style: AppText.bodyStrong.copyWith(color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '$timeLabel  ·  $durLabel  ·  ${_statusLabel(status)}',
                  style: AppText.label.copyWith(
                    color: status == FocusSessionStatus.active
                        ? t.accent
                        : t.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.m),
        ],
      ),
    );
  }

  static String _statusLabel(FocusSessionStatus s) => switch (s) {
        FocusSessionStatus.pending => 'Upcoming',
        FocusSessionStatus.active => 'In progress',
        FocusSessionStatus.done => 'Done',
      };
}

class _PlanRecurringCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () => context.push('/settings/sessions/plan'),
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: t.ink, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: t.ink,
                borderRadius: BorderRadius.circular(R.s),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.calendarRange, color: t.bg, size: IconSize.m),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Plan recurring sessions',
                      style: AppText.bodyStrong.copyWith(color: t.ink)),
                  Text('Fan out a weekday schedule across a week, month, or quarter.',
                      style: AppText.label.copyWith(color: t.inkMuted)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.m),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x3l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.calendarClock, color: t.inkMuted, size: 48),
            const SizedBox(height: Sp.m),
            Text(
              'No focus sessions yet.',
              style: AppText.title.copyWith(color: t.ink),
            ),
            const SizedBox(height: Sp.s),
            Text(
              'Tap "New session" to schedule one. A session is a concrete time window you commit to focus.',
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(color: t.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
