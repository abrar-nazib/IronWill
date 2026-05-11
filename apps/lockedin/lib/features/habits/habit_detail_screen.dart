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
                _FieldStatsSection(habit: habit),
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

/// Per-habit-field summary across the last N daily logs. Skips habits with no
/// fields. Each field renders a tiny table of the most recent 7 days, plus a
/// total/avg row when the values are numeric.
class _FieldStatsSection extends StatelessWidget {
  final Habit habit;
  const _FieldStatsSection({required this.habit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fields = parseHabitFields(habit.metadata);
    if (fields.isEmpty) return const SizedBox.shrink();
    final svc = AppServices.of(context);
    return AppCard(
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader('Tracking fields'),
          Text('Last 14 days, most recent first.',
              style: AppText.label.copyWith(color: t.inkMuted)),
          const SizedBox(height: Sp.md),
          FutureBuilder<List<HabitLog>>(
            future: _loadRecentLogs(svc, habit.id, 14),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: Sp.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final logs = snap.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in fields) ...[
                    _FieldStatBlock(field: f, logs: logs),
                    const SizedBox(height: Sp.md),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// Pull the last [days] habit logs. Falls back to scanning the in-memory
  /// list one day at a time when the SQLite-only `recentLogs` is unavailable
  /// (e.g. on web/mock).
  Future<List<HabitLog>> _loadRecentLogs(
    AppServices svc,
    String habitId,
    int days,
  ) async {
    // SqliteHabitsRepository exposes a fast `recentLogs` method; mock impls
    // don't, so we fall back to per-day getLog calls.
    try {
      final dyn = svc.habits as dynamic;
      final res = await dyn.recentLogs(habitId, days);
      if (res is List<HabitLog>) return res;
    } catch (_) {}
    final today = svc.time.today.value.date;
    final out = <HabitLog>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(today.year, today.month, today.day - i);
      final log = await svc.habits.getLog(habitId, d);
      if (log != null) out.add(log);
    }
    return out;
  }
}

class _FieldStatBlock extends StatelessWidget {
  final HabitField field;
  final List<HabitLog> logs;
  const _FieldStatBlock({required this.field, required this.logs});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final values = <(DateTime, Object?)>[];
    for (final log in logs) {
      final v = log.metadata[field.key];
      if (v == null) continue;
      values.add((log.day, v));
    }
    final summary = _summary(values.map((e) => e.$2).toList());
    return Container(
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(R.xs),
                  border: Border.all(color: t.divider),
                ),
                child: Text(field.key,
                    style: AppText.mono.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              const SizedBox(width: Sp.s),
              Expanded(
                child: Text(field.type.label,
                    style: AppText.label.copyWith(color: t.inkMuted)),
              ),
              if (summary.isNotEmpty)
                Text(summary,
                    style: AppText.bodyStrong.copyWith(color: t.ink)),
            ],
          ),
          const SizedBox(height: Sp.s),
          if (values.isEmpty)
            Text('No data yet.',
                style: AppText.label.copyWith(color: t.inkMuted))
          else
            Column(
              children: [
                for (final (date, val) in values.take(7))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(_dateLabel(date),
                              style: AppText.mono
                                  .copyWith(color: t.inkMuted, fontSize: 12)),
                        ),
                        const SizedBox(width: Sp.s),
                        Expanded(
                          child: Text(_valueLabel(val),
                              style:
                                  AppText.body.copyWith(color: t.ink, fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _dateLabel(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  static String _valueLabel(Object? v) {
    if (v is List) return v.join(', ');
    if (v is bool) return v ? 'yes' : 'no';
    return v.toString();
  }

  /// Bottom-line summary: total/avg for numeric fields, true count for
  /// booleans, hidden for text. Returns '' when not meaningful.
  String _summary(List<Object?> values) {
    if (values.isEmpty) return '';
    if (field.type == HabitFieldType.number) {
      final ints = values.whereType<int>().toList();
      if (ints.isEmpty) return '';
      final sum = ints.fold<int>(0, (a, b) => a + b);
      return 'avg ${(sum / ints.length).toStringAsFixed(1)}';
    }
    if (field.type == HabitFieldType.intList) {
      var total = 0;
      var count = 0;
      for (final v in values) {
        if (v is List) {
          for (final x in v) {
            if (x is int) {
              total += x;
              count += 1;
            }
          }
        }
      }
      if (count == 0) return '';
      return 'total $total reps';
    }
    if (field.type == HabitFieldType.boolean) {
      final yesCount = values.whereType<bool>().where((b) => b).length;
      return '$yesCount/${values.length} yes';
    }
    return '';
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
