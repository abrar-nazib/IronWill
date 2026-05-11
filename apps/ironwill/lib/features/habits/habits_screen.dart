import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../models/utilization.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/app_card.dart';
import 'habit_edit_sheet.dart';
import 'habit_log_sheet.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ValueListenableBuilder<List<Habit>>(
          valueListenable: svc.habits.active,
          builder: (_, habits, __) => CustomScrollView(
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
                      Text(
                        '${habits.length} ACTIVE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted),
                      ),
                      const SizedBox(height: Sp.xs),
                      Text('Habits', style: AppText.headline.copyWith(color: t.ink)),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Archived',
                    icon: const Icon(LucideIcons.archive),
                    onPressed: () => context.push('/settings/archived'),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(LucideIcons.settings),
                    onPressed: () => context.push('/settings'),
                  ),
                  const SizedBox(width: Sp.s),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
                sliver: SliverToBoxAdapter(child: _AddHabitTile()),
              ),
              if (habits.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.x4l),
                  sliver: SliverToBoxAdapter(child: _EmptyHabits()),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.x4l),
                  sliver: SliverList.separated(
                    itemCount: habits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: Sp.s),
                    itemBuilder: (_, i) => _HabitRow(habit: habits[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(LucideIcons.plus),
        label: const Text('New habit'),
        onPressed: () => showHabitEditSheet(context),
      ),
    );
  }
}

class _AddHabitTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: () => showHabitEditSheet(context),
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
              child: Icon(LucideIcons.plus, color: t.bg, size: IconSize.m),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add a new habit',
                      style: AppText.bodyStrong.copyWith(color: t.ink)),
                  Text('Name, cadence, glyph, reminder',
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

class _HabitRow extends StatelessWidget {
  final Habit habit;
  const _HabitRow({required this.habit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final last7 = habit.last90.sublist(habit.last90.length - 7);
    final today = habit.last90.last;
    final done = today == Utilization.full || today == Utilization.good;
    return AppCard(
      onTap: () => context.push('/habits/${habit.id}'),
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: t.surfaceAlt,
                  borderRadius: BorderRadius.circular(R.s),
                  border: Border.all(color: t.divider),
                ),
                alignment: Alignment.center,
                child: Icon(habit.glyph, color: t.ink, size: IconSize.m),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(habit.name, style: AppText.bodyStrong.copyWith(color: t.ink)),
                    const SizedBox(height: 2),
                    Text(_subtitle(habit), style: AppText.label.copyWith(color: t.inkMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${habit.currentStreak}',
                      style: AppText.mono.copyWith(color: t.ink, fontSize: 20, fontWeight: FontWeight.w700)),
                  Text('DAY STREAK',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              for (int i = 0; i < 7; i++) ...[
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: last7[i] == Utilization.none ? t.surfaceAlt : last7[i].color(t),
                      borderRadius: BorderRadius.circular(R.xs),
                    ),
                  ),
                ),
                if (i < 6) const SizedBox(width: 3),
              ],
            ],
          ),
          const SizedBox(height: Sp.md),
          Row(
            children: [
              Icon(LucideIcons.percent, color: t.inkMuted, size: IconSize.s),
              const SizedBox(width: Sp.xs),
              Text('${habit.completionRate}% completion',
                  style: AppText.label.copyWith(color: t.inkMuted)),
              const Spacer(),
              if (done)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: Sp.s, vertical: Sp.xs),
                  decoration: BoxDecoration(
                    color: t.uFull.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(R.xs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.check, color: t.uFull, size: IconSize.s),
                      const SizedBox(width: Sp.xs),
                      Text('Logged today',
                          style: AppText.label.copyWith(color: t.uFull, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => showHabitLogSheet(context, habit: habit),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: Sp.m),
                    textStyle: AppText.label.copyWith(fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(LucideIcons.checkCheck, size: 16),
                  label: const Text('Log today'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _subtitle(Habit h) {
    return switch (h.cadence) {
      HabitCadence.daily => 'Every day  ·  ${h.reminder.format24()}',
      HabitCadence.weekdays => 'Weekdays  ·  ${h.reminder.format24()}',
      HabitCadence.weekends => 'Weekends  ·  ${h.reminder.format24()}',
      HabitCadence.custom =>
        '${h.customDays.map((d) => const ['', 'M', 'T', 'W', 'T', 'F', 'S', 'S'][d]).join(' ')}  ·  ${h.reminder.format24()}',
    };
  }
}

extension on TimeOfDay {
  String format24() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _EmptyHabits extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: Sp.x3l),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(R.s),
        border: Border.all(color: t.divider),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.checkCheck, color: t.inkMuted, size: 36),
          const SizedBox(height: Sp.m),
          Text('No habits yet', style: AppText.title.copyWith(color: t.ink)),
          const SizedBox(height: Sp.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            child: Text(
              'Pick something small you can do every day. Cold shower, journaling, no scrolling before noon. Add the first one and it appears here.',
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: t.inkMuted),
            ),
          ),
        ],
      ),
    );
  }
}
