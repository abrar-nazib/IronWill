import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import '../../widgets/quarter_grid.dart';
import '../../widgets/session_active_pill.dart';
import '../../widgets/utilization_legend.dart';
import 'log_block_sheet.dart';
import 'quarter_logger.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  late DateTime _date;
  late Future<DayBlocks> _dayFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _date = AppServices.of(context).time.today.value.date;
    _dayFuture = AppServices.of(context).time.getDay(_date);
  }

  void _setDate(DateTime d) {
    setState(() {
      _date = d;
      _dayFuture = AppServices.of(context).time.getDay(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<DayBlocks>(
          future: _dayFuture,
          builder: (context, snap) {
            final day = snap.data;
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
                        Text('TIME TRACKER',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                        const SizedBox(height: Sp.xs),
                        Text(
                          DateFormat('EEEE, d MMM').format(_date),
                          style: AppText.headline.copyWith(color: t.ink),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(LucideIcons.chevronLeft),
                      tooltip: 'Previous day',
                      onPressed: () => _setDate(_date.subtract(const Duration(days: 1))),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.chevronRight),
                      tooltip: 'Next day',
                      onPressed: () => _setDate(_date.add(const Duration(days: 1))),
                    ),
                    const SizedBox(width: Sp.s),
                  ],
                ),
                if (day == null)
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
                      const Padding(
                        padding: EdgeInsets.only(bottom: Sp.m),
                        child: SessionActivePill(),
                      ),
                      _TopMetrics(day: day),
                      const SizedBox(height: Sp.m),
                      AppCard(
                        padding: const EdgeInsets.all(Sp.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SectionHeader('Legend'),
                            const UtilizationLegend(),
                          ],
                        ),
                      ),
                      const SizedBox(height: Sp.m),
                      _GridCard(day: day, onTap: (i) => _logQuarter(day, i)),
                    ]),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(LucideIcons.bellRing),
        label: const Text('Log this quarter'),
        onPressed: () async {
          final picked = await const SmartQuarterPicker().pick(context);
          if (picked == null || !mounted) return;
          final day = await _dayFuture;
          if (!mounted) return;
          await _logQuarter(day, picked);
        },
      ),
    );
  }

  Future<void> _logQuarter(DayBlocks day, int index) async {
    final svc = AppServices.of(context);
    final picked = await showLogBlockSheet(
      context,
      current: day.quarters[index],
      quarterIndex: index,
    );
    if (picked == null) return;
    await svc.time.logQuarter(_date, index, picked);
    if (!mounted) return;
    setState(() {
      _dayFuture = svc.time.getDay(_date);
    });
  }
}

class _TopMetrics extends StatelessWidget {
  final DayBlocks day;
  const _TopMetrics({required this.day});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final focusMin = day.focusedMinutes;
    final pct = (day.utilizationPercent * 100).round();
    return Row(
      children: [
        Expanded(
          child: AppCard(
            color: t.ink,
            stroked: false,
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FOCUSED', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.bg.withValues(alpha: 0.6))),
                const SizedBox(height: Sp.s),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$focusMin', style: AppText.display.copyWith(color: t.bg)),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('min', style: AppText.label.copyWith(color: t.bg.withValues(alpha: 0.6))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: Sp.m),
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(Sp.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UTILIZATION', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                const SizedBox(height: Sp.s),
                Text('$pct%', style: AppText.display.copyWith(color: t.ink)),
                const SizedBox(height: 4),
                Text('${day.loggedQuarterCount} of 96 quarters logged',
                    style: AppText.label.copyWith(color: t.inkMuted)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final DayBlocks day;
  final void Function(int) onTap;
  const _GridCard({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('24 hour grid'),
          Text('Each row is one hour, four 15 minute quarters.',
              style: AppText.label.copyWith(color: t.inkMuted)),
          const SizedBox(height: Sp.md),
          QuarterGrid(quarters: day.quarters, onTap: onTap),
        ],
      ),
    );
  }
}
