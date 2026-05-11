import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'app_card.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trailing;
  final IconData? icon;
  final bool emphasized;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.icon,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = emphasized ? t.bg : t.ink;
    final muted = emphasized ? t.bg.withValues(alpha: 0.7) : t.inkMuted;
    return AppCard(
      color: emphasized ? t.ink : t.surface,
      stroked: !emphasized,
      padding: const EdgeInsets.all(Sp.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: IconSize.s, color: muted),
                const SizedBox(width: Sp.xs),
              ],
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.m),
          Text(
            value,
            style: AppText.display.copyWith(color: fg, fontSize: 32),
          ),
          if (trailing != null) ...[
            const SizedBox(height: Sp.xs),
            Text(
              trailing!,
              style: AppText.label.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}
