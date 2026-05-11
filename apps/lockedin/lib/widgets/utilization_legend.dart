import 'package:flutter/material.dart';

import '../models/utilization.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

class UtilizationLegend extends StatelessWidget {
  final List<Utilization> entries;
  const UtilizationLegend({
    super.key,
    this.entries = const [
      Utilization.notFocus,
      Utilization.wasted,
      Utilization.low,
      Utilization.mid,
      Utilization.good,
      Utilization.full,
    ],
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: Sp.s,
      runSpacing: Sp.s,
      children: [
        for (final u in entries)
          Semantics(
            label: '${u.label}, ${u.percent ?? 'reserved'}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: u.color(t),
                    borderRadius: BorderRadius.circular(R.xs),
                  ),
                ),
                const SizedBox(width: Sp.xs),
                Text(
                  u.percent != null ? '${u.percent}%' : u.label,
                  style: AppText.label.copyWith(color: t.inkMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
