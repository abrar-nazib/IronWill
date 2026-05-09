import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../models/utilization.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/active_session_timer.dart';
import '../../widgets/app_card.dart';
import '../../widgets/quarter_grid.dart';
import '../../widgets/streak_pill.dart';
import '../habits/habit_edit_sheet.dart';
import '../habits/habit_log_sheet.dart';
import '../tracker/log_block_sheet.dart';
import '../tracker/quarter_logger.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          pinned: false,
          backgroundColor: t.bg,
          surfaceTintColor: t.bg,
          toolbarHeight: 76,
          title: ValueListenableBuilder<UserProfile>(
            valueListenable: svc.profile.profile,
            builder: (_, p, __) {
              final today = svc.time.today.value.date;
              return Padding(
                padding: const EdgeInsets.only(top: Sp.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d MMMM').format(today).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted),
                    ),
                    const SizedBox(height: Sp.xs),
                    Text('${_greeting()}, ${p.name}.',
                        style: AppText.headline.copyWith(color: t.ink)),
                  ],
                ),
              );
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Sp.md, top: Sp.md),
              child: GestureDetector(
                onTap: () => context.push('/settings'),
                child: Semantics(
                  button: true,
                  label: 'Open settings',
                  child: ValueListenableBuilder<UserProfile>(
                    valueListenable: svc.profile.profile,
                    builder: (_, p, __) => Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.surfaceAlt,
                        borderRadius: BorderRadius.circular(R.s),
                        border: Border.all(color: t.divider),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (p.avatarLetter ?? p.name.substring(0, 1)).toUpperCase(),
                        style: AppText.bodyStrong.copyWith(color: t.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.x4l),
          sliver: SliverList.list(children: [
            const Padding(
              padding: EdgeInsets.only(bottom: Sp.m),
              child: ActiveSessionTimer(),
            ),
            _HeroFocusCard(),
            const SizedBox(height: Sp.m),
            _StreakCard(),
            const SizedBox(height: Sp.m),
            _LogTrayCard(),
            const SizedBox(height: Sp.m),
            _UpNextCard(),
            const SizedBox(height: Sp.m),
            _TodayHabitsCard(),
            const SizedBox(height: Sp.m),
            _TodaysGridCard(),
          ]),
        ),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Afternoon';
    return 'Evening';
  }
}

class _HeroFocusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return ValueListenableBuilder<DayBlocks>(
      valueListenable: svc.time.today,
      builder: (_, day, __) => ValueListenableBuilder<UserProfile>(
        valueListenable: svc.profile.profile,
        builder: (_, p, __) {
          final focusMin = day.focusedMinutes;
          final target = p.targetForToday();
          final pct = (focusMin / target).clamp(0.0, 1.0);
          return AppCard(
            color: t.ink,
            stroked: false,
            padding: const EdgeInsets.all(Sp.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FOCUS TODAY',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.bg.withValues(alpha: 0.6))),
                const SizedBox(height: Sp.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$focusMin', style: AppText.big.copyWith(color: t.bg, fontSize: 64)),
                    const SizedBox(width: Sp.s),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.s),
                      child: Text('min', style: AppText.title.copyWith(color: t.bg.withValues(alpha: 0.6))),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Sp.s),
                      child: Text('OF $target',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.bg.withValues(alpha: 0.6))),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.xs),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 6,
                    backgroundColor: t.bg.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(t.accent),
                  ),
                ),
                const SizedBox(height: Sp.s),
                Text(
                  pct >= 1
                      ? 'Daily focus minimum cleared. Keep going.'
                      : '${(pct * 100).round()}% of today done. ${(target - focusMin)} min to go.',
                  style: AppText.label.copyWith(color: t.bg.withValues(alpha: 0.7)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: svc.stats.focusStreakDays,
      builder: (_, days, __) => AppCard(
        padding: const EdgeInsets.all(Sp.md),
        child: Row(
          children: [
            StreakPill(days: days, emphasized: true),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(
                "Don't break the chain. $days days of meeting your daily focus minimum.",
                style: AppText.body.copyWith(color: t.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _logCurrentQuarter(BuildContext context) async {
  final svc = AppServices.of(context);
  final size = svc.settings.settings.value.blockSizeMinutes;
  final stride = size == 60 ? 4 : (size == 30 ? 2 : 1);
  final picked = await SmartQuarterPicker(blockSizeMinutes: size).pick(context);
  if (picked == null || !context.mounted) return;
  final today = svc.time.today.value;
  final aggregated = aggregateQuartersInBlock(
    quarters: today.quarters,
    firstQuarterIndex: picked,
    stride: stride,
  );
  final result = await showLogBlockSheet(
    context,
    current: aggregated,
    quarterIndex: picked,
    blockSizeMinutes: size,
  );
  if (result == null || !context.mounted) return;
  for (var i = 0; i < stride; i++) {
    final idx = picked + i;
    if (idx >= 96) break;
    await svc.time.logQuarter(today.date, idx, result);
  }
}

/// The "you can log here" tray. Most prominent action on the home screen so
/// the user always knows where to add an entry.
///
/// Layout intent: keep logging actions and creation actions visually
/// separated so users do not confuse "Log a habit" (mark today's status) with
/// "Add habit" (create a new habit definition). Logging actions go in their
/// own row pair on top; creation actions sit in a single row underneath.
class _LogTrayCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Log now'),
          ValueListenableBuilder<AppSettings>(
            valueListenable: svc.settings.settings,
            builder: (_, settings, __) {
              final size = settings.blockSizeMinutes;
              final title = 'Log a focus block';
              final subtitle = size == 60
                  ? 'Mark how the last hour went'
                  : 'Mark how the last $size minutes went';
              return Row(
                children: [
                  Expanded(
                    child: _BigAction(
                      icon: LucideIcons.bellRing,
                      title: title,
                      subtitle: subtitle,
                      onTap: () => _logCurrentQuarter(context),
                    ),
                  ),
                  const SizedBox(width: Sp.s),
                  Expanded(
                    child: _BigAction(
                      icon: LucideIcons.checkCheck,
                      title: 'Log a habit',
                      subtitle: "Mark today's status",
                      onTap: () => context.go('/habits'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Sp.m),
          Row(
            children: [
              Expanded(
                child: Text('QUICK ADD',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: t.inkMuted)),
              ),
            ],
          ),
          const SizedBox(height: Sp.s),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.calendarPlus),
                  label: const Text('Add focus blocks'),
                  onPressed: () => context.push('/settings/subjects'),
                ),
              ),
              const SizedBox(width: Sp.s),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add habit'),
                  onPressed: () => showHabitEditSheet(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BigAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      borderRadius: BorderRadius.circular(R.s),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: t.surfaceAlt,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: t.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: t.ink, size: IconSize.m),
                const Spacer(),
                Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.m),
              ],
            ),
            const SizedBox(height: Sp.m),
            Text(title, style: AppText.bodyStrong.copyWith(color: t.ink)),
            const SizedBox(height: 2),
            Text(subtitle, style: AppText.label.copyWith(color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}

class _UpNextCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ValueListenableBuilder<List<Subject>>(
      valueListenable: AppServices.of(context).subjects.all,
      builder: (_, subjects, __) {
        final upcoming = _nextUpcomingBlock(subjects, DateTime.now());
        if (upcoming == null) {
          return AppCard(
            padding: const EdgeInsets.all(Sp.md),
            onTap: () => context.go('/time'),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: t.surfaceAlt,
                    borderRadius: BorderRadius.circular(R.s),
                    border: Border.all(color: t.divider),
                  ),
                  alignment: Alignment.center,
                  child: Icon(LucideIcons.target, color: t.inkMuted, size: IconSize.m),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UP NEXT',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                      const SizedBox(height: 2),
                      Text('No subjects scheduled', style: AppText.title.copyWith(color: t.ink)),
                      const SizedBox(height: 2),
                      Text('Add focus blocks under a subject to fill your week.',
                          style: AppText.label.copyWith(color: t.inkMuted)),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.l),
              ],
            ),
          );
        }
        final block = upcoming.block;
        final timeLabel =
            '${block.start.hour.toString().padLeft(2, '0')}:${block.start.minute.toString().padLeft(2, '0')}';
        final dayLabel = upcoming.isToday ? 'Today' : _weekdayName(block.dayOfWeek);
        return AppCard(
          padding: const EdgeInsets.all(Sp.md),
          onTap: () => context.go('/time'),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(R.s),
                  border: Border.all(color: t.divider),
                ),
                alignment: Alignment.center,
                child: Icon(LucideIcons.target, color: t.ink, size: IconSize.m),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UP NEXT',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                    const SizedBox(height: 2),
                    Text(upcoming.subject.name, style: AppText.title.copyWith(color: t.ink)),
                    const SizedBox(height: 2),
                    Text('$dayLabel $timeLabel  ·  ${block.durationMinutes} min planned',
                        style: AppText.label.copyWith(color: t.inkMuted)),
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.l),
            ],
          ),
        );
      },
    );
  }
}

class _UpcomingBlockHit {
  final Subject subject;
  final SubjectBlock block;
  final bool isToday;
  const _UpcomingBlockHit({
    required this.subject,
    required this.block,
    required this.isToday,
  });
}

/// Find the next non-expired block: prefer one that hasn't started today, then
/// scan forward day by day for up to 7 days.
_UpcomingBlockHit? _nextUpcomingBlock(List<Subject> subjects, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  for (var off = 0; off < 7; off++) {
    final day = today.add(Duration(days: off));
    final dow = day.weekday;
    _UpcomingBlockHit? best;
    int? bestStartMin;
    for (final s in subjects) {
      if (!s.isLiveOn(day)) continue;
      for (final b in s.blocks) {
        if (b.dayOfWeek != dow) continue;
        if (off == 0) {
          final blockStart = day.add(Duration(hours: b.start.hour, minutes: b.start.minute));
          if (!blockStart.isAfter(now)) continue;
        }
        if (bestStartMin == null || b.startMinute < bestStartMin) {
          bestStartMin = b.startMinute;
          best = _UpcomingBlockHit(subject: s, block: b, isToday: off == 0);
        }
      }
    }
    if (best != null) return best;
  }
  return null;
}

const List<String> _weekdayNames = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
];
String _weekdayName(int dow) => _weekdayNames[(dow - 1).clamp(0, 6)];

class _TodayHabitsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final svc = AppServices.of(context);
    return ValueListenableBuilder<List<Habit>>(
      valueListenable: svc.habits.active,
      builder: (_, habits, __) => AppCard(
        padding: const EdgeInsets.all(Sp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              "Today's habits",
              trailing: TextButton(
                onPressed: () => context.go('/habits'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 28)),
                child: const Text('All'),
              ),
            ),
            for (final h in habits.take(3))
              _HabitTodayRow(habit: h, onTapLog: () => showHabitLogSheet(context, habit: h)),
          ],
        ),
      ),
    );
  }
}

class _HabitTodayRow extends StatelessWidget {
  final Habit habit;
  final VoidCallback onTapLog;
  const _HabitTodayRow({required this.habit, required this.onTapLog});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = habit.last90.last;
    final colour = today == Utilization.none ? t.surfaceAlt : today.color(t);
    final done = today == Utilization.full || today == Utilization.good;
    return InkWell(
      onTap: onTapLog,
      borderRadius: BorderRadius.circular(R.s),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sp.s, horizontal: Sp.xs),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(R.xs),
                border: today == Utilization.none ? Border.all(color: t.divider) : null,
              ),
              alignment: Alignment.center,
              child: done ? Icon(LucideIcons.check, color: t.accentInk, size: 16) : null,
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name, style: AppText.bodyStrong.copyWith(color: t.ink)),
                  Text(_subtitleFor(habit), style: AppText.label.copyWith(color: t.inkMuted)),
                ],
              ),
            ),
            Text('${habit.currentStreak}',
                style: AppText.mono.copyWith(color: t.ink, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 2),
            Text('d', style: AppText.label.copyWith(color: t.inkMuted)),
            const SizedBox(width: Sp.s),
            Icon(LucideIcons.chevronRight, color: t.inkMuted, size: IconSize.m),
          ],
        ),
      ),
    );
  }

  static String _subtitleFor(Habit h) {
    return switch (h.cadence) {
      HabitCadence.daily => 'Every day',
      HabitCadence.weekdays => 'Weekdays',
      HabitCadence.weekends => 'Weekends',
      HabitCadence.custom => h.customDays
          .map((d) => const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d])
          .join(', '),
    };
  }
}

class _TodaysGridCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final svc = AppServices.of(context);
    return ValueListenableBuilder<DayBlocks>(
      valueListenable: svc.time.today,
      builder: (_, day, __) => ValueListenableBuilder<AppSettings>(
        valueListenable: svc.settings.settings,
        builder: (_, settings, __) {
          final size = settings.blockSizeMinutes;
          return AppCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  "Today's grid",
                  trailing: TextButton(
                    onPressed: () => context.go('/time'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 28)),
                    child: const Text('Open'),
                  ),
                ),
                const SizedBox(height: Sp.s),
                QuarterGrid(
                  quarters: day.quarters,
                  blockSizeMinutes: size,
                  compact: true,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
