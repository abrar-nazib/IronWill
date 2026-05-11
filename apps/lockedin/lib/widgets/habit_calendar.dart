import 'package:flutter/material.dart';

import '../models/utilization.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 90 day grid for one habit, ordered oldest to newest, 7 columns wide.
class HabitCalendar extends StatelessWidget {
  final List<Utilization> values;
  final DateTime endDate;
  final void Function(DateTime, int indexFromEnd)? onTapDay;

  const HabitCalendar({
    super.key,
    required this.values,
    required this.endDate,
    this.onTapDay,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final start = endDate.subtract(Duration(days: values.length - 1));
    const dows = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final firstWeekdayIndex = (start.weekday - 1) % 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final d in dows)
              SizedBox(
                width: 28,
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: AppText.label.copyWith(color: t.inkMuted),
                ),
              ),
          ],
        ),
        const SizedBox(height: Sp.s),
        ..._weekRows(firstWeekdayIndex, t, start),
      ],
    );
  }

  List<Widget> _weekRows(int firstIndex, AppTokens t, DateTime start) {
    final padded = <Utilization?>[
      ...List<Utilization?>.filled(firstIndex, null),
      ...values,
    ];
    while (padded.length % 7 != 0) {
      padded.add(null);
    }

    final rows = <Widget>[];
    for (int row = 0; row < padded.length / 7; row++) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int col = 0; col < 7; col++)
              _cell(padded[row * 7 + col], t, row, col, firstIndex, start),
          ],
        ),
      ));
    }
    return rows;
  }

  Widget _cell(Utilization? u, AppTokens t, int row, int col, int firstIndex, DateTime start) {
    if (u == null) {
      return const SizedBox(width: 28, height: 28);
    }
    final flatIndex = row * 7 + col - firstIndex;
    final date = start.add(Duration(days: flatIndex));
    final indexFromEnd = values.length - 1 - flatIndex;
    final empty = u == Utilization.none;
    final cell = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: empty ? Colors.transparent : u.color(t),
        borderRadius: BorderRadius.circular(R.xs),
        border: empty ? Border.all(color: t.divider) : null,
      ),
    );
    if (onTapDay == null) return cell;
    return InkWell(
      borderRadius: BorderRadius.circular(R.xs),
      onTap: () => onTapDay!(date, indexFromEnd),
      child: cell,
    );
  }
}
