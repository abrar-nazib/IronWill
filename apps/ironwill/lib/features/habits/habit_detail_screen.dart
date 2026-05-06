import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/models.dart';
import '../../services/app_services.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/habit_calendar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/utilization_legend.dart';
import 'habit_edit_sheet.dart';
import 'habit_log_sheet.dart';

class HabitDetailScreen extends StatelessWidget {
  final String habitId;
  const HabitDetailScreen({super.key, required this.habitId});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final svc = AppServices.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('HABIT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
        actions: [
          ValueListenableBuilder<List<Habit>>(
            valueListenable: svc.habits.all,
            builder: (_, list, __) {
              final h = list.firstWhere(
                (x) => x.id == habitId,
                orElse: () => list.first,
              );
              return IconButton(
                tooltip: 'Edit habit',
                icon: const Icon(LucideIcons.pencil),
                onPressed: () => showHabitEditSheet(context, existing: h),
              );
            },
          ),
          const SizedBox(width: Sp.s),
        ],
      ),
      body: ValueListenableBuilder<List<Habit>>(
        valueListenable: svc.habits.all,
        builder: (_, list, __) {
          final habit = list.firstWhere(
            (h) => h.id == habitId,
            orElse: () => list.first,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.x4l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(habit: habit),
                const SizedBox(height: Sp.lg),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Current streak',
                        value: '${habit.currentStreak}',
                        trailing: 'days',
                        icon: LucideIcons.flame,
                        emphasized: true,
                      ),
                    ),
                    const SizedBox(width: Sp.m),
                    Expanded(
                      child: StatCard(
                        label: 'Best streak',
                        value: '${habit.bestStreak}',
                        trailing: 'days',
                        icon: LucideIcons.medal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.m),
                StatCard(
                  label: 'Completion',
                  value: '${habit.completionRate}%',
                  trailing: 'last 90 days',
                  icon: LucideIcons.percent,
                ),
                const SizedBox(height: Sp.m),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(LucideIcons.checkCheck, size: 18),
                    label: const Text('Log today'),
                    onPressed: () => showHabitLogSheet(context, habit: habit),
                  ),
                ),
                const SizedBox(height: Sp.lg),
                AppCard(
                  padding: const EdgeInsets.all(Sp.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader('Last 90 days'),
                      Text('Tap a day to log retroactively.',
                          style: AppText.label.copyWith(color: t.inkMuted)),
                      const SizedBox(height: Sp.md),
                      HabitCalendar(
                        values: habit.last90,
                        endDate: AppServices.of(context).time.today.value.date,
                        onTapDay: (date, _) => showHabitLogSheet(context, habit: habit, day: date),
                      ),
                      const SizedBox(height: Sp.md),
                      const UtilizationLegend(),
                    ],
                  ),
                ),
                const SizedBox(height: Sp.lg),
                _Reminders(habit: habit),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Habit habit;
  const _Header({required this.habit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(R.s),
            border: Border.all(color: t.divider),
          ),
          alignment: Alignment.center,
          child: Icon(habit.glyph, color: t.ink, size: IconSize.l),
        ),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(habit.name, style: AppText.headline.copyWith(color: t.ink)),
              const SizedBox(height: 2),
              Text(habit.cadence.label, style: AppText.body.copyWith(color: t.inkMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Reminders extends StatelessWidget {
  final Habit habit;
  const _Reminders({required this.habit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hh = habit.reminder.hour.toString().padLeft(2, '0');
    final mm = habit.reminder.minute.toString().padLeft(2, '0');
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: t.surfaceAlt,
              borderRadius: BorderRadius.circular(R.s),
              border: Border.all(color: t.divider),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.bellRing, color: t.ink, size: IconSize.m),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('REMINDER', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted)),
                Text('$hh:$mm  ·  ${habit.cadence.label}',
                    style: AppText.bodyStrong.copyWith(color: t.ink)),
              ],
            ),
          ),
          Switch(
            value: habit.reminderOn,
            onChanged: (v) => AppServices.of(context).habits.update(habit.copyWith(reminderOn: v)),
            activeThumbColor: t.accent,
          ),
        ],
      ),
    );
  }
}
