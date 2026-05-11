import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';

class StreakPill extends StatelessWidget {
  final int days;
  final String? label;
  final bool emphasized;
  const StreakPill({
    super.key,
    required this.days,
    this.label,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bg = emphasized ? t.accent : t.surfaceAlt;
    final fg = emphasized ? t.accentInk : t.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.m, vertical: Sp.s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(R.s),
        border: emphasized ? null : Border.all(color: t.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.flame, size: IconSize.s, color: fg),
          const SizedBox(width: Sp.s),
          Text(
            '$days',
            style: AppText.mono.copyWith(color: fg, fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 2),
          Text(
            label ?? (days == 1 ? 'day' : 'days'),
            style: AppText.label.copyWith(color: fg.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}
