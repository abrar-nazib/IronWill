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

enum _ViewMode { list, calendar }

/// Settings → Focus sessions. Two views of the same data:
///   * List: grouped by day, easy to skim chronologically.
///   * Calendar: month grid with ember dots on days that have sessions;
///     tap a date to see that day's sessions in a sheet.
/// Both share the same FAB ("Start one now") and the "Plan recurring
/// sessions" card up top.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  _ViewMode _view = _ViewMode.list;

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
          builder: (_, subjects, ___) {
            final subjectsById = {for (final s in subjects) s.id: s};
            return ListView(
              padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
              children: [
                _PlanRecurringCard(),
                const SizedBox(height: Sp.m),
                _ViewToggle(
                  current: _view,
                  onChange: (v) => setState(() => _view = v),
                ),
                if (_view == _ViewMode.list)
                  ..._listBody(sessions, subjectsById)
                else
                  _CalendarBody(
                    sessions: sessions,
                    subjectsById: subjectsById,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _listBody(
    List<FocusSession> sessions,
    Map<String, Subject> subjectsById,
  ) {
    if (sessions.isEmpty) {
      return [const SizedBox(height: Sp.md), _Empty()];
    }
    final groups = _groupByDay(sessions);
    return [
      for (final entry in groups)
        _DayGroup(
          date: entry.date,
          sessions: entry.sessions,
          subjectsById: subjectsById,
        ),
    ];
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

class _ViewToggle extends StatelessWidget {
  final _ViewMode current;
  final ValueChanged<_ViewMode> onChange;
  const _ViewToggle({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget chip(_ViewMode v, String label, IconData icon) {
      final selected = v == current;
      return Expanded(
        child: InkWell(
          onTap: () => onChange(v),
          borderRadius: BorderRadius.circular(R.s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: Sp.s),
            decoration: BoxDecoration(
              color: selected ? t.ink : t.surface,
              borderRadius: BorderRadius.circular(R.s),
              border: Border.all(color: selected ? t.ink : t.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    color: selected ? t.bg : t.ink, size: IconSize.s),
                const SizedBox(width: Sp.xs),
                Text(label,
                    style: AppText.bodyStrong.copyWith(
                      color: selected ? t.bg : t.ink,
                      fontSize: 13,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(_ViewMode.list, 'List', LucideIcons.list),
        const SizedBox(width: Sp.s),
        chip(_ViewMode.calendar, 'Calendar', LucideIcons.calendar),
      ],
    );
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
                  Text('Fan out a weekday schedule across the week.',
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
              'Tap "Start one now" to schedule one, or use "Plan recurring sessions" above to fan out a weekday template.',
              textAlign: TextAlign.center,
              style: AppText.label.copyWith(color: t.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Month-grid calendar view. Each cell shows the date plus an ember
/// dot (and an optional count badge) when sessions exist on that day.
/// Tap a populated cell to open a bottom sheet with that day's
/// sessions; tap an empty cell to start a fresh session for that date.
class _CalendarBody extends StatefulWidget {
  final List<FocusSession> sessions;
  final Map<String, Subject> subjectsById;
  const _CalendarBody({
    required this.sessions,
    required this.subjectsById,
  });

  @override
  State<_CalendarBody> createState() => _CalendarBodyState();
}

class _CalendarBodyState extends State<_CalendarBody> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  void _prev() {
    setState(() {
      _month = DateTime(_month.year, _month.month - 1, 1);
    });
  }

  void _next() {
    setState(() {
      _month = DateTime(_month.year, _month.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // Bucket sessions by date for O(1) lookup per cell.
    final byDay = <DateTime, List<FocusSession>>{};
    for (final s in widget.sessions) {
      final key = DateTime(s.startAt.year, s.startAt.month, s.startAt.day);
      (byDay[key] ??= []).add(s);
    }

    // Build a grid that always shows full weeks (Mon → Sun). The first
    // cell is the Monday of the week containing the 1st of the month;
    // the grid runs for 6 rows so cells past the month-end stay empty.
    final firstOfMonth = DateTime(_month.year, _month.month, 1);
    final gridStart = firstOfMonth
        .subtract(Duration(days: (firstOfMonth.weekday - 1)));
    final cells = List<DateTime>.generate(
        42, (i) => gridStart.add(Duration(days: i)));
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.only(top: Sp.m),
      child: AppCard(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: _prev,
                  tooltip: 'Previous month',
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month),
                    textAlign: TextAlign.center,
                    style: AppText.bodyStrong.copyWith(color: t.ink),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight),
                  onPressed: _next,
                  tooltip: 'Next month',
                ),
              ],
            ),
            const SizedBox(height: Sp.xs),
            Row(
              children: [
                for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                  Expanded(
                    child: Center(
                      child: Text(w,
                          style: AppText.label.copyWith(
                            color: t.inkMuted,
                            fontSize: 11,
                          )),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Sp.xs),
            for (var row = 0; row < 6; row++) ...[
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _CalendarCell(
                        date: cells[row * 7 + col],
                        inMonth:
                            cells[row * 7 + col].month == _month.month,
                        isToday:
                            cells[row * 7 + col] == todayDate,
                        sessions:
                            byDay[cells[row * 7 + col]] ?? const [],
                        subjectsById: widget.subjectsById,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final DateTime date;
  final bool inMonth;
  final bool isToday;
  final List<FocusSession> sessions;
  final Map<String, Subject> subjectsById;
  const _CalendarCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.sessions,
    required this.subjectsById,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasSessions = sessions.isNotEmpty;
    final color = inMonth ? t.ink : t.inkMuted.withValues(alpha: 0.35);
    final bg = isToday ? t.surfaceAlt : Colors.transparent;
    return InkWell(
      onTap: hasSessions
          ? () => _showDaySheet(context, date, sessions, subjectsById)
          : () => _startForDate(context, date),
      borderRadius: BorderRadius.circular(R.s),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(R.s),
            border: Border.all(
              color: isToday ? t.ink : t.divider,
              width: isToday ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  date.day.toString(),
                  style: AppText.bodyStrong.copyWith(
                    color: color,
                    fontSize: 12,
                  ),
                ),
              ),
              if (hasSessions)
                Positioned(
                  bottom: 4,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: t.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (sessions.length > 1) ...[
                        const SizedBox(width: 3),
                        Text(
                          'x${sessions.length}',
                          style: AppText.label.copyWith(
                            color: t.accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Called when the user taps an empty cell. Opens the quick-start
  /// sheet so they can drop a session on that date without leaving the
  /// calendar. (Quick-start is today-only by design; for past dates we
  /// just open the empty edit-by-date flow via the planner instead — to
  /// keep this iteration small we only act on today/future and ignore
  /// past taps.)
  void _startForDate(BuildContext context, DateTime date) {
    final today = DateTime.now();
    final isPastOrToday = !date.isAfter(DateTime(today.year, today.month, today.day));
    if (!isPastOrToday) {
      // Only today is supported by the quick-start sheet (it forces
      // today). For future cells, send the user to the planner.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Use Plan recurring sessions to schedule ${DateFormat('d MMM').format(date)}.',
        ),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    if (date.day == today.day && date.month == today.month && date.year == today.year) {
      showQuickStartSessionSheet(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'No sessions on ${DateFormat('d MMM').format(date)}.',
        ),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _showDaySheet(
    BuildContext context,
    DateTime date,
    List<FocusSession> sessions,
    Map<String, Subject> subjectsById,
  ) {
    final t = context.tokens;
    final today = DateTime.now();
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final label = isToday
        ? 'Today, ${DateFormat('d MMM').format(date)}'
        : DateFormat('EEEE, d MMM').format(date);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.surface,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, Sp.m, Sp.md, Sp.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.divider,
                    borderRadius: BorderRadius.circular(R.pill),
                  ),
                ),
              ),
              const SizedBox(height: Sp.md),
              Text(label, style: AppText.headline.copyWith(color: t.ink)),
              const SizedBox(height: Sp.s),
              for (final s in sessions)
                Padding(
                  padding: const EdgeInsets.only(top: Sp.s),
                  child: _SessionRow(
                    session: s,
                    subject: s.subjectId == null
                        ? null
                        : subjectsById[s.subjectId],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
