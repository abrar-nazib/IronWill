import 'package:flutter/material.dart';

import '../../models/utilization.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

String quarterLabel(int q) {
  final h = (q ~/ 4).toString().padLeft(2, '0');
  final m = ((q % 4) * 15).toString().padLeft(2, '0');
  final endH = (((q + 1) ~/ 4) % 24).toString().padLeft(2, '0');
  final endM = (((q + 1) % 4) * 15).toString().padLeft(2, '0');
  return '$h:$m to $endH:$endM';
}

Future<Utilization?> showLogBlockSheet(
  BuildContext context, {
  required Utilization current,
  required int quarterIndex,
}) {
  return showModalBottomSheet<Utilization>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).extension<AppTokens>()!.surface,
    builder: (ctx) => _LogSheet(current: current, quarterIndex: quarterIndex),
  );
}

class _LogSheet extends StatelessWidget {
  final Utilization current;
  final int quarterIndex;
  const _LogSheet({required this.current, required this.quarterIndex});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final options = const [
      Utilization.full,
      Utilization.good,
      Utilization.mid,
      Utilization.low,
      Utilization.wasted,
      Utilization.notFocus,
      Utilization.none,
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.md, Sp.md, Sp.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.divider,
                  borderRadius: BorderRadius.circular(R.pill),
                ),
              ),
            ),
            const SizedBox(height: Sp.md),
            Text('Log this quarter', style: AppText.headline.copyWith(color: t.ink)),
            const SizedBox(height: 2),
            Text(quarterLabel(quarterIndex), style: AppText.label.copyWith(color: t.inkMuted)),
            const SizedBox(height: Sp.md),
            for (final u in options) _Row(
              util: u,
              selected: u == current,
              onTap: () => Navigator.of(context).pop(u),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Utilization util;
  final bool selected;
  final VoidCallback onTap;
  const _Row({required this.util, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final swatchColor = util == Utilization.none ? Colors.transparent : util.color(t);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: Sp.xs),
        padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.m),
        decoration: BoxDecoration(
          color: selected ? t.surfaceAlt : Colors.transparent,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: selected ? t.ink : t.divider, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: swatchColor,
                borderRadius: BorderRadius.circular(R.xs),
                border: util == Utilization.none ? Border.all(color: t.divider) : null,
              ),
            ),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(util.focusLabel, style: AppText.bodyStrong.copyWith(color: t.ink)),
            ),
            if (util.percent != null)
              Text('${util.percent}%', style: AppText.label.copyWith(color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}
