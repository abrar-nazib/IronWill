import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool stroked;
  final double? radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.stroked = true,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = radius ?? R.s;
    final inner = Padding(
      padding: padding ?? const EdgeInsets.all(Sp.md),
      child: child,
    );
    final box = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? t.surface,
        borderRadius: BorderRadius.circular(r),
        border: stroked ? Border.all(color: t.divider) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(onTap: onTap, child: inner),
              )
            : inner,
      ),
    );
    return box;
  }
}

/// Tracked uppercase section header. Use sparingly; one per section block.
class SectionHeader extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionHeader(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.s),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.inkMuted),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
