import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../models/utilization.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/utilization_legend.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

enum _Range { week, month, year }

class _StatsScreenState extends State<StatsScreen> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<WeeklyStats>(
          future: svc.stats.getWeekly(),
          builder: (context, snap) {
            final stats = snap.data;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  backgroundColor: t.bg,
                  surfaceTintColor: t.bg,
                  toolbarHeight: 76,
                  title: Padding(
                    padding: const EdgeInsets.only(top: Sp.s),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LAST 7 DAYS',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                        const SizedBox(height: Sp.xs),
                        Text('Stats', style: AppText.headline.copyWith(color: t.ink)),
                      ],
                    ),
                  ),
                ),
                if (stats == null)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(Sp.x4l),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.x4l),
                    sliver: SliverList.list(children: [
                      _RangePicker(current: _range, onChange: (r) => setState(() => _range = r)),
                      const SizedBox(height: Sp.m),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Focused',
                              value: '${(stats.totalFocusMinutes / 60).toStringAsFixed(1)}h',
                              trailing: '${stats.totalFocusMinutes} min total',
                              icon: LucideIcons.brain,
                              emphasized: true,
                            ),
                          ),
                          const SizedBox(width: Sp.m),
                          Expanded(
                            child: StatCard(
                              label: 'Daily average',
                              value: '${stats.avgPerDay}',
                              trailing: 'min per day',
                              icon: LucideIcons.activity,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Sp.m),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Goal hit',
                              value: stats.evaluatedTargetDays == 0
                                  ? '–'
                                  : '${stats.goalHitDays} / ${stats.evaluatedTargetDays}',
                              trailing: stats.evaluatedTargetDays == 0
                                  ? 'no targets set'
                                  : 'days at or above target',
                              icon: LucideIcons.flag,
                            ),
                          ),
                          const SizedBox(width: Sp.m),
                          Expanded(
                            child: StatCard(
                              label: 'Avg utilization',
                              value: '${stats.avgUtilizationPct}%',
                              trailing: 'of logged blocks',
                              icon: LucideIcons.gauge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Sp.m),
                      _HighlightsCard(stats: stats),
                      const SizedBox(height: Sp.m),
                      StatCard(
                        label: 'Habit completion',
                        value: '${stats.avgHabitCompletion}%',
                        trailing: 'across active habits',
                        icon: LucideIcons.target,
                      ),
                      const SizedBox(height: Sp.m),
                      _BarChartCard(stats: stats),
                      const SizedBox(height: Sp.m),
                      _HourlyHeatmapCard(stats: stats),
                      const SizedBox(height: Sp.m),
                      _PerHabitCard(stats: stats),
                      const SizedBox(height: Sp.m),
                      _WeekGridCard(stats: stats),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RangePicker extends StatelessWidget {
  final _Range current;
  final ValueChanged<_Range> onChange;
  const _RangePicker({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget chip(_Range r, String label) {
      final selected = current == r;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChange(r),
          child: Container(
            margin: const EdgeInsets.all(Sp.xs),
            padding: const EdgeInsets.symmetric(vertical: Sp.s),
            decoration: BoxDecoration(
              color: selected ? t.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(R.xs),
            ),
            alignment: Alignment.center,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? t.bg : t.inkMuted,
                  ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(R.s),
        border: Border.all(color: t.divider),
      ),
      child: Row(children: [
        chip(_Range.week, 'Week'),
        chip(_Range.month, 'Month'),
        chip(_Range.year, 'Year'),
      ]),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  final WeeklyStats stats;
  const _BarChartCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxMin = stats.focusMinutesByDay.fold<int>(0, (a, b) => b > a ? b : a);
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Focused minutes by day'),
          const SizedBox(height: Sp.s),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < stats.focusMinutesByDay.length; i++) ...[
                  Expanded(
                    child: _Bar(
                      minutes: stats.focusMinutesByDay[i],
                      max: maxMin,
                      label: DateFormat('E').format(stats.days[i].date),
                    ),
                  ),
                  if (i < stats.focusMinutesByDay.length - 1) const SizedBox(width: Sp.s),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final int minutes;
  final int max;
  final String label;
  const _Bar({required this.minutes, required this.max, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ratio = max == 0 ? 0.0 : minutes / max;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('$minutes', style: AppText.mono.copyWith(color: t.inkMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: ratio.clamp(0.04, 1.0),
              widthFactor: 0.7,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.ink,
                  borderRadius: BorderRadius.circular(R.xs),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Sp.s),
        Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
      ],
    );
  }
}

class _WeekGridCard extends StatelessWidget {
  final WeeklyStats stats;
  const _WeekGridCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('7 day grid'),
          Text('Each column is one day, top to bottom is 00:00 to 24:00.',
              style: AppText.label.copyWith(color: t.inkMuted)),
          const SizedBox(height: Sp.md),
          SizedBox(
            height: 320,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < stats.days.length; i++) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Text(DateFormat('E').format(stats.days[i].date).toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                        const SizedBox(height: Sp.xs),
                        Expanded(child: _DayColumn(quarters: stats.days[i].quarters)),
                      ],
                    ),
                  ),
                  if (i < stats.days.length - 1) const SizedBox(width: 3),
                ],
              ],
            ),
          ),
          const SizedBox(height: Sp.md),
          const UtilizationLegend(),
        ],
      ),
    );
  }
}

/// Headline-style "best / worst day, peak hour, unlogged blocks" panel. Quick
/// at-a-glance signal users actually look at when opening Stats.
class _HighlightsCard extends StatelessWidget {
  final WeeklyStats stats;
  const _HighlightsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final entries = <_HighlightEntry>[];

    if (stats.bestDayIndex >= 0) {
      final day = stats.days[stats.bestDayIndex];
      entries.add(_HighlightEntry(
        icon: LucideIcons.trophy,
        label: 'Best day',
        value: DateFormat('EEEE').format(day.date),
        sub: '${stats.focusMinutesByDay[stats.bestDayIndex]} min focused',
      ));
    }
    if (stats.worstDayIndex >= 0 &&
        stats.worstDayIndex != stats.bestDayIndex) {
      final day = stats.days[stats.worstDayIndex];
      entries.add(_HighlightEntry(
        icon: LucideIcons.cloudDrizzle,
        label: 'Quietest',
        value: DateFormat('EEEE').format(day.date),
        sub: '${stats.focusMinutesByDay[stats.worstDayIndex]} min focused',
      ));
    }

    // Peak hour-of-day: the highest entry in hourlyMinutes.
    var peakIdx = -1;
    var peakMin = 0;
    for (var i = 0; i < stats.hourlyMinutes.length; i++) {
      if (stats.hourlyMinutes[i] > peakMin) {
        peakMin = stats.hourlyMinutes[i];
        peakIdx = i;
      }
    }
    if (peakIdx >= 0) {
      final h = peakIdx.toString().padLeft(2, '0');
      final next = ((peakIdx + 1) % 24).toString().padLeft(2, '0');
      entries.add(_HighlightEntry(
        icon: LucideIcons.alarmClock,
        label: 'Peak window',
        value: '$h:00 – $next:00',
        sub: '$peakMin min in this hour, last 7 days',
      ));
    }

    if (stats.unloggedFocusQuarters > 0) {
      entries.add(_HighlightEntry(
        icon: LucideIcons.circleAlert,
        label: 'Unlogged',
        value: '${stats.unloggedFocusQuarters} block${stats.unloggedFocusQuarters == 1 ? '' : 's'}',
        sub: 'inside scheduled subject windows',
      ));
    }

    if (entries.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(Sp.md),
        child: Row(
          children: [
            Icon(LucideIcons.chartLine, color: t.inkMuted, size: IconSize.l),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(
                'Log some quarters to populate stats.',
                style: AppText.body.copyWith(color: t.inkMuted),
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Highlights'),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) Divider(color: t.divider, height: Sp.lg, thickness: 1),
            Row(
              children: [
                Icon(entries[i].icon, color: t.ink, size: IconSize.l),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entries[i].label.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: t.inkMuted)),
                      Text(entries[i].value,
                          style: AppText.title.copyWith(color: t.ink)),
                      Text(entries[i].sub,
                          style: AppText.label.copyWith(color: t.inkMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HighlightEntry {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  const _HighlightEntry({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
  });
}

/// 24-bar hour-of-day strip showing the minutes the user actually focused at
/// each hour across the period. Helps users spot their natural work window.
class _HourlyHeatmapCard extends StatelessWidget {
  final WeeklyStats stats;
  const _HourlyHeatmapCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxMin = stats.hourlyMinutes.fold<int>(0, (a, b) => b > a ? b : a);
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('When you focus'),
          Text(
            'Total minutes focused at each hour-of-day across the last 7 days.',
            style: AppText.label.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: Sp.m),
          SizedBox(
            height: 88,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var h = 0; h < 24; h++) ...[
                  Expanded(
                    child: _HourBar(
                      hour: h,
                      minutes: stats.hourlyMinutes[h],
                      max: maxMin,
                    ),
                  ),
                  if (h < 23) const SizedBox(width: 1),
                ],
              ],
            ),
          ),
          const SizedBox(height: Sp.s),
          Row(
            children: [
              Text('00', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
              const Spacer(),
              Text('06', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
              const Spacer(),
              Text('12', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
              const Spacer(),
              Text('18', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
              const Spacer(),
              Text('24', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourBar extends StatelessWidget {
  final int hour;
  final int minutes;
  final int max;
  const _HourBar({
    required this.hour,
    required this.minutes,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ratio = max == 0 ? 0.0 : minutes / max;
    return Tooltip(
      message: '${hour.toString().padLeft(2, '0')}:00  ·  $minutes min',
      child: FractionallySizedBox(
        heightFactor: ratio.clamp(0.04, 1.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: minutes == 0 ? t.divider : t.accent,
            borderRadius: BorderRadius.circular(R.xs),
          ),
        ),
      ),
    );
  }
}

/// One row per active habit so the user can see exactly which habit dragged
/// the average down or held it up.
class _PerHabitCard extends StatelessWidget {
  final WeeklyStats stats;
  const _PerHabitCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (stats.habitRows.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(Sp.md),
        child: Row(
          children: [
            Icon(LucideIcons.target, color: t.inkMuted, size: IconSize.l),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text('No active habits to compare.',
                  style: AppText.body.copyWith(color: t.inkMuted)),
            ),
          ],
        ),
      );
    }
    final sorted = [...stats.habitRows]
      ..sort((a, b) => b.completionPct.compareTo(a.completionPct));
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Per habit, last 7 days'),
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0) Divider(color: t.divider, height: Sp.m, thickness: 1),
            _HabitStatRow(row: sorted[i]),
          ],
        ],
      ),
    );
  }
}

class _HabitStatRow extends StatelessWidget {
  final HabitWeeklyRow row;
  const _HabitStatRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ratio = (row.evaluatedDays == 0 ? 0.0 : row.hitDays / row.evaluatedDays).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Sp.s),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(R.s),
              border: Border.all(color: t.divider),
            ),
            alignment: Alignment.center,
            child: Icon(row.glyph, color: t.ink, size: IconSize.m),
          ),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name, style: AppText.bodyStrong.copyWith(color: t.ink)),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.xs),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: t.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(t.accent),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Sp.m),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${row.completionPct}%',
                  style: AppText.mono.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  )),
              Text('${row.hitDays}/${row.evaluatedDays} days',
                  style: AppText.label.copyWith(color: t.inkMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  final List<Utilization> quarters;
  const _DayColumn({required this.quarters});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return LayoutBuilder(builder: (ctx, c) {
      final cellH = c.maxHeight / 24;
      return Column(
        children: [
          for (int hour = 0; hour < 24; hour++)
            SizedBox(
              height: cellH,
              child: Row(
                children: [
                  for (int q = 0; q < 4; q++) ...[
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.5, vertical: 0.5),
                        decoration: BoxDecoration(
                          color: quarters[hour * 4 + q] == Utilization.none
                              ? t.surfaceAlt
                              : quarters[hour * 4 + q].color(t),
                          borderRadius: BorderRadius.circular(1.0),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      );
    });
  }
}
