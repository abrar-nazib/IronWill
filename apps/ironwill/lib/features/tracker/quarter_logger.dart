import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'log_block_sheet.dart';

/// Decide which quarter the user means when they tap "Log this quarter".
///
/// The rule (per spec):
/// * if we are 5+ minutes into the current quarter, log the current quarter
///   (the user is mid-block).
/// * if we are in the first 5 minutes of a new quarter, ask the user whether
///   they meant the just-finished previous quarter or the in-progress current
///   one.
class SmartQuarterPicker {
  final DateTime Function() now;
  const SmartQuarterPicker({DateTime Function()? now}) : now = now ?? DateTime.now;

  Future<int?> pick(BuildContext context) async {
    final t = now();
    final currentQ = t.hour * 4 + (t.minute ~/ 15);
    final minIntoQuarter = t.minute % 15;
    if (minIntoQuarter >= 5 || currentQ == 0) return currentQ;
    return await _askPreviousOrCurrent(context, currentQ);
  }

  Future<int?> _askPreviousOrCurrent(BuildContext context, int currentQ) {
    final prev = currentQ - 1;
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.surface,
      builder: (ctx) => _ChoiceSheet(prev: prev, current: currentQ),
    );
  }
}

class _ChoiceSheet extends StatelessWidget {
  final int prev;
  final int current;
  const _ChoiceSheet({required this.prev, required this.current});

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
              'A new 15 minute block just started. Tell me which one you mean.',
              style: AppText.body.copyWith(color: t.inkMuted),
            ),
            const SizedBox(height: Sp.md),
            _Choice(
              label: 'The block that just ended',
              subtitle: quarterLabel(prev),
              hint: 'Logging the past quarter, fully complete',
              onTap: () => Navigator.of(context).pop(prev),
            ),
            const SizedBox(height: Sp.s),
            _Choice(
              label: 'The block in progress',
              subtitle: quarterLabel(current),
              hint: 'Logging the current quarter early',
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
