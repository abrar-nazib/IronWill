import 'package:flutter/material.dart';

import '../models/utilization.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 24 hour day grid. Storage is always 15-minute quarters (96 per day) but
/// the rendering granularity is controlled by [blockSizeMinutes]: 15 shows
/// every quarter, 30 pairs them up, 60 collapses each hour into a single
/// cell. Aggregated cells show the rounded average of their underlying
/// quarter utilizations.
class QuarterGrid extends StatelessWidget {
  final List<Utilization> quarters;

  /// 15 / 30 / 60. Other values fall back to 15.
  final int blockSizeMinutes;

  /// Callback fires with the FIRST 15-minute quarter index in the tapped
  /// block. The caller writes the same utilization to all sub-blocks.
  final void Function(int quarterIndex)? onTap;
  final bool compact;

  const QuarterGrid({
    super.key,
    required this.quarters,
    this.blockSizeMinutes = 15,
    this.onTap,
    this.compact = false,
  })  : assert(quarters.length == 96);

  int get _stride {
    switch (blockSizeMinutes) {
      case 30:
        return 2;
      case 60:
        return 4;
      default:
        return 1;
    }
  }

  int get _cellsPerRow => 4 ~/ _stride;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cellRadius = compact ? 2.0 : R.xs;
    final cellGap = compact ? 2.0 : 3.0;
    final rowGap = compact ? 5.0 : Sp.xs;
    final hourLabelWidth = compact ? 22.0 : 30.0;
    final stride = _stride;
    final cellsPerRow = _cellsPerRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int hour = 0; hour < 24; hour++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: hourLabelWidth,
                child: Text(
                  hour.toString().padLeft(2, '0'),
                  style: AppText.mono.copyWith(
                    color: t.inkMuted,
                    fontSize: compact ? 10 : 11,
                  ),
                ),
              ),
              SizedBox(width: cellGap),
              Expanded(
                child: Row(
                  children: [
                    for (int c = 0; c < cellsPerRow; c++) ...[
                      Expanded(
                        child: _Cell(
                          util: aggregateQuartersInBlock(
                            quarters: quarters,
                            firstQuarterIndex: hour * 4 + c * stride,
                            stride: stride,
                          ),
                          radius: cellRadius,
                          height: compact ? 8 : 14,
                          onTap: onTap == null
                              ? null
                              : () => onTap!(hour * 4 + c * stride),
                        ),
                      ),
                      if (c < cellsPerRow - 1) SizedBox(width: cellGap),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: rowGap),
        ],
      ],
    );
  }
}

/// Average of `stride` consecutive quarters starting at [firstQuarterIndex],
/// rounded to the nearest utilization tier. If every constituent quarter is
/// `none`, returns `none`. If all are `notFocus`, returns `notFocus`.
/// Otherwise mid-tier averages snap to the nearest of {wasted, low, mid,
/// good, full}. `notFocus` quarters in a partly-logged block are skipped
/// from the percent average.
Utilization aggregateQuartersInBlock({
  required List<Utilization> quarters,
  required int firstQuarterIndex,
  required int stride,
}) {
  if (stride <= 1) return quarters[firstQuarterIndex];
  final slice = quarters.sublist(
    firstQuarterIndex,
    (firstQuarterIndex + stride).clamp(0, quarters.length),
  );
  // All none => none. All notFocus => notFocus. Otherwise compute %.
  if (slice.every((q) => q == Utilization.none)) return Utilization.none;
  if (slice.every((q) => q == Utilization.notFocus)) return Utilization.notFocus;
  final percents = <int>[];
  for (final q in slice) {
    final p = q.percent;
    if (p != null) percents.add(p);
  }
  if (percents.isEmpty) return Utilization.none;
  final avg = percents.reduce((a, b) => a + b) / percents.length;
  // Snap to the nearest tier among 0/25/50/75/100.
  const tiers = <(double, Utilization)>[
    (0, Utilization.wasted),
    (25, Utilization.low),
    (50, Utilization.mid),
    (75, Utilization.good),
    (100, Utilization.full),
  ];
  Utilization best = Utilization.wasted;
  double bestDistance = double.infinity;
  for (final (pct, util) in tiers) {
    final d = (pct - avg).abs();
    if (d < bestDistance) {
      bestDistance = d;
      best = util;
    }
  }
  return best;
}

class _Cell extends StatelessWidget {
  final Utilization util;
  final double radius;
  final double height;
  final VoidCallback? onTap;
  const _Cell({
    required this.util,
    required this.radius,
    required this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = util.color(t);
    final empty = util == Utilization.none;
    final box = Container(
      height: height,
      decoration: BoxDecoration(
        color: empty ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(radius),
        border: empty ? Border.all(color: t.divider, width: 1) : null,
      ),
    );
    if (onTap == null) return box;
    return Semantics(
      button: true,
      label: '${util.label} block. Tap to log.',
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: SizedBox(
          height: height < 28 ? 28 : height,
          child: Center(child: box),
        ),
      ),
    );
  }
}
