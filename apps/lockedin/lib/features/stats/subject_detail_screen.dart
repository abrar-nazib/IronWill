import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/repositories.dart';
import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_card.dart';

/// Drill-down stats for one subject. Reached by tapping a row in the
/// "Focus by subject" card on the main Stats screen. Same range chip is
/// honoured (week/month/year). Reuses [QuarterGrid] etc. by feeding a
/// masked DayBlocks where only this subject's quarters carry colour.
class SubjectDetailScreen extends StatefulWidget {
  final String subjectId;
  final StatsRange initialRange;
  const SubjectDetailScreen({
    super.key,
    required this.subjectId,
    this.initialRange = StatsRange.week,
  });

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  late StatsRange _range = widget.initialRange;

  String get _rangeLabel => switch (_range) {
        StatsRange.week => 'LAST 7 DAYS',
        StatsRange.month => 'LAST 30 DAYS',
        StatsRange.year => 'LAST 365 DAYS',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        title: const Text('Subject detail'),
        backgroundColor: t.bg,
        surfaceTintColor: t.bg,
      ),
      body: FutureBuilder<SubjectDetailStats?>(
        future: svc.stats.getSubjectDetail(widget.subjectId, _range),
        builder: (context, snap) {
          if (!snap.hasData && snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final detail = snap.data;
          if (detail == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Sp.x3l),
                child: Text(
                  'Subject not found.',
                  style: AppText.body.copyWith(color: t.inkMuted),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(Sp.md, Sp.s, Sp.md, Sp.x4l),
            children: [
              _Header(name: detail.name, rangeLabel: _rangeLabel),
              const SizedBox(height: Sp.m),
              _RangePicker(
                current: _range,
                onChange: (r) => setState(() => _range = r),
              ),
              const SizedBox(height: Sp.m),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Focused',
                      value:
                          '${(detail.focusedMinutes / 60).toStringAsFixed(1)}h',
                      trailing: '${detail.focusedMinutes} min total',
                      icon: LucideIcons.brain,
                      emphasized: true,
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: StatCard(
                      label: 'Avg utilization',
                      value: detail.avgUtilizationPct == null
                          ? '–'
                          : '${detail.avgUtilizationPct}%',
                      trailing: 'of logged blocks',
                      icon: LucideIcons.gauge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.m),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Quarters logged',
                      value: '${detail.loggedQuarters}',
                      trailing: '${detail.loggedQuarters * 15} min raw',
                      icon: LucideIcons.layoutGrid,
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: StatCard(
                      label: 'Best day',
                      value: detail.bestDayIndex < 0
                          ? '–'
                          : '${detail.focusMinutesByDay[detail.bestDayIndex]}m',
                      trailing: detail.bestDayIndex < 0
                          ? 'nothing logged'
                          : _shortDate(detail.days[detail.bestDayIndex].date),
                      icon: LucideIcons.trophy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Sp.m),
              _DailyBarsCard(detail: detail),
              const SizedBox(height: Sp.m),
              _HourlyHeatmapCard(hourlyMinutes: detail.hourlyMinutes),
            ],
          );
        },
      ),
    );
  }
}

String _shortDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day} ${months[d.month - 1]}';
}

class _Header extends StatelessWidget {
  final String name;
  final String rangeLabel;
  const _Header({required this.name, required this.rangeLabel});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rangeLabel,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: t.inkMuted)),
        const SizedBox(height: Sp.xs),
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: t.accent,
                borderRadius: BorderRadius.circular(R.s),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.target,
                  color: t.accentInk, size: IconSize.m),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(name,
                  style: AppText.headline.copyWith(color: t.ink),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ],
    );
  }
}

class _RangePicker extends StatelessWidget {
  final StatsRange current;
  final ValueChanged<StatsRange> onChange;
  const _RangePicker({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget chip(StatsRange r, String label) {
      final selected = r == current;
      return Expanded(
        child: InkWell(
          onTap: () => onChange(r),
          borderRadius: BorderRadius.circular(R.s),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: Sp.s),
            decoration: BoxDecoration(
              color: selected ? t.ink : t.surface,
              borderRadius: BorderRadius.circular(R.s),
              border: Border.all(color: selected ? t.ink : t.divider),
            ),
            alignment: Alignment.center,
            child: Text(label,
                style: AppText.bodyStrong.copyWith(
                  color: selected ? t.bg : t.ink,
                  fontSize: 13,
                )),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(StatsRange.week, 'Week'),
        const SizedBox(width: Sp.s),
        chip(StatsRange.month, 'Month'),
        const SizedBox(width: Sp.s),
        chip(StatsRange.year, 'Year'),
      ],
    );
  }
}

class _DailyBarsCard extends StatelessWidget {
  final SubjectDetailStats detail;
  const _DailyBarsCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxMin = detail.focusMinutesByDay.fold<int>(0, (a, b) => b > a ? b : a);
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Minutes per day'),
          const SizedBox(height: Sp.s),
          SizedBox(
            height: 90,
            child: LayoutBuilder(
              builder: (ctx, c) {
                final cellW = c.maxWidth / detail.focusMinutesByDay.length;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < detail.focusMinutesByDay.length; i++)
                      SizedBox(
                        width: cellW,
                        height: 90,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: maxMin == 0
                                  ? 0
                                  : (detail.focusMinutesByDay[i] / maxMin)
                                      .clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: i == detail.bestDayIndex
                                      ? t.accent
                                      : t.ink,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: Sp.xs),
          Text(
            maxMin == 0
                ? 'Nothing logged for this subject yet.'
                : 'Tallest bar = best day. ${maxMin} min peak.',
            style: AppText.label.copyWith(color: t.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _HourlyHeatmapCard extends StatelessWidget {
  final List<int> hourlyMinutes;
  const _HourlyHeatmapCard({required this.hourlyMinutes});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final maxMin = hourlyMinutes.fold<int>(0, (a, b) => b > a ? b : a);
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Hour of day'),
          const SizedBox(height: Sp.s),
          SizedBox(
            height: 64,
            child: LayoutBuilder(
              builder: (ctx, c) {
                final cellW = c.maxWidth / 24;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var h = 0; h < 24; h++)
                      SizedBox(
                        width: cellW,
                        height: 64,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0.5),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: maxMin == 0
                                  ? 0
                                  : (hourlyMinutes[h] / maxMin)
                                      .clamp(0.0, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: t.ink,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: Sp.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
              Text('06', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
              Text('12', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
              Text('18', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
              Text('23', style: AppText.label.copyWith(color: t.inkMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
