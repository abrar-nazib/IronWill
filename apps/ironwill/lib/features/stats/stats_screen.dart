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
                      StatCard(
                        label: 'Habit completion',
                        value: '${stats.avgHabitCompletion}%',
                        trailing: 'across active habits',
                        icon: LucideIcons.target,
                      ),
                      const SizedBox(height: Sp.m),
                      _BarChartCard(stats: stats),
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
