import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Decide which 15-min quarter the user means when they tap "Log this 15
/// min" (or "Log this 30 min" / "Log this hour" depending on block size).
///
/// The rule (per spec):
/// * if we are 5+ minutes into the current quarter, log the current quarter
///   (the user is mid-block).
/// * if we are in the first 5 minutes of a new quarter, ask the user whether
///   they meant the just-finished previous quarter or the in-progress current
///   one.
class SmartQuarterPicker {
  final DateTime Function() now;

  /// 15 / 30 / 60. Storage stays at 15-min granularity; the picker snaps to
  /// the first 15-min quarter of the current display block. The caller writes
  /// the same utilization to all sub-quarters in that block.
  final int blockSizeMinutes;
  const SmartQuarterPicker({
    DateTime Function()? now,
    this.blockSizeMinutes = 15,
  }) : now = now ?? DateTime.now;

  int get _stride => blockSizeMinutes == 60
      ? 4
      : (blockSizeMinutes == 30 ? 2 : 1);

  Future<int?> pick(BuildContext context) async {
    final t = now();
    final stride = _stride;
    final currentQ = t.hour * 4 + (t.minute ~/ 15);
    final blockFirstQ = currentQ - (currentQ % stride);
    final minutesIntoBlock = (currentQ - blockFirstQ) * 15 + (t.minute % 15);
    if (minutesIntoBlock >= 5 || blockFirstQ == 0) return blockFirstQ;
    return await _askPreviousOrCurrent(context, blockFirstQ);
  }

  Future<int?> _askPreviousOrCurrent(BuildContext context, int currentBlockFirstQ) {
    final prev = currentBlockFirstQ - _stride;
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surface,
      builder: (ctx) => _ChoiceSheet(
        prev: prev,
        current: currentBlockFirstQ,
        blockSizeMinutes: blockSizeMinutes,
      ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  final int prev;
  final int current;
  final int blockSizeMinutes;
  const _ChoiceSheet({
    required this.prev,
    required this.current,
    required this.blockSizeMinutes,
  });

  String _label(int firstQ) {
    final startMin = firstQ * 15;
    final endMin = startMin + blockSizeMinutes;
    final sh = startMin ~/ 60;
    final sm = startMin % 60;
    final eh = endMin ~/ 60;
    final em = endMin % 60;
    String fmt(int h, int m) =>
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return '${fmt(sh, sm)}–${fmt(eh, em)}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, Sp.m, Sp.md, Sp.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.divider,
                  borderRadius: BorderRadius.circular(R.pill),
                ),
              ),
            ),
            const SizedBox(height: Sp.md),
            Text('Which block?', style: AppText.headline.copyWith(color: t.ink)),
            const SizedBox(height: Sp.xs),
            Text(
              'A new $blockSizeMinutes minute block just started. Tell me which one you mean.',
              style: AppText.body.copyWith(color: t.inkMuted),
            ),
            const SizedBox(height: Sp.md),
            if (prev >= 0)
              _Choice(
                label: 'The block that just ended',
                subtitle: _label(prev),
                hint: 'Log the past block, fully complete',
                onTap: () => Navigator.of(context).pop(prev),
              ),
            if (prev >= 0) const SizedBox(height: Sp.s),
            _Choice(
              label: 'The block in progress',
              subtitle: _label(current),
              hint: 'Log the current block early',
              onTap: () => Navigator.of(context).pop(current),
            ),
            const SizedBox(height: Sp.s),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final String subtitle;
  final String hint;
  final VoidCallback onTap;
  const _Choice({
    required this.label,
    required this.subtitle,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.s),
      child: Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(R.s),
          border: Border.all(color: t.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(label, style: AppText.bodyStrong.copyWith(color: t.ink))),
                Text(subtitle, style: AppText.mono.copyWith(color: t.ink, fontSize: 14)),
              ],
            ),
            const SizedBox(height: Sp.xs),
            Text(hint, style: AppText.label.copyWith(color: t.inkMuted)),
          ],
        ),
      ),
    );
  }
}
