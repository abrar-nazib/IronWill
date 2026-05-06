import 'package:flutter/material.dart';

import '../models/utilization.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// 24 hour x 4 quarter day grid. Cells use the utilization data ramp.
class QuarterGrid extends StatelessWidget {
  final List<Utilization> quarters;
  final void Function(int quarterIndex)? onTap;
  final bool compact;

  const QuarterGrid({
    super.key,
    required this.quarters,
    this.onTap,
    this.compact = false,
  })  : assert(quarters.length == 96);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final cellRadius = compact ? 2.0 : R.xs;
    final cellGap = compact ? 2.0 : 3.0;
    final rowGap = compact ? 5.0 : Sp.xs;
    final hourLabelWidth = compact ? 22.0 : 30.0;

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
                    for (int q = 0; q < 4; q++) ...[
                      Expanded(
                        child: _Cell(
                          util: quarters[hour * 4 + q],
                          radius: cellRadius,
                          height: compact ? 8 : 14,
                          onTap: onTap == null ? null : () => onTap!(hour * 4 + q),
                        ),
                      ),
                      if (q < 3) SizedBox(width: cellGap),
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
