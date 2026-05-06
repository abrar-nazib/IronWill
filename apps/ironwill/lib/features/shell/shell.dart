import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/tokens.dart';
import '../../theme/typography.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;
  const AppShell({super.key, required this.child, required this.state});

  static const _destinations = [
    _Dest(label: 'Today', icon: LucideIcons.sunrise, route: '/today'),
    _Dest(label: 'Time', icon: LucideIcons.layoutGrid, route: '/time'),
    _Dest(label: 'Habits', icon: LucideIcons.checkCheck, route: '/habits'),
    _Dest(label: 'Stats', icon: LucideIcons.chartLine, route: '/stats'),
  ];

  int get _index {
    final loc = state.matchedLocation;
    final i = _destinations.indexWhere((d) => loc.startsWith(d.route));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final activeIndex = _index;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (activeIndex == 0) {
          SystemNavigator.pop();
        } else {
          context.go(_destinations[0].route);
        }
      },
      child: Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(top: false, child: child),
        bottomNavigationBar: _IronNavBar(
          destinations: _destinations,
          activeIndex: activeIndex,
          onTap: (i) => context.go(_destinations[i].route),
          tokens: t,
        ),
      ),
    );
  }
}

class _IronNavBar extends StatelessWidget {
  final List<_Dest> destinations;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final AppTokens tokens;

  const _IronNavBar({
    required this.destinations,
    required this.activeIndex,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: tokens.divider)),
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _NavItem(
                      dest: destinations[i],
                      active: i == activeIndex,
                      onTap: () => onTap(i),
                      tokens: tokens,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _Dest dest;
  final bool active;
  final VoidCallback onTap;
  final AppTokens tokens;

  const _NavItem({
    required this.dest,
    required this.active,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? tokens.accent : tokens.inkMuted;
    return Semantics(
      selected: active,
      button: true,
      label: dest.label,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 2,
                color: active ? tokens.accent : Colors.transparent,
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(dest.icon, size: IconSize.l, color: color),
                  const SizedBox(height: Sp.xs),
                  Text(
                    dest.label,
                    style: AppText.nav.copyWith(
                      color: color,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dest {
  final String label;
  final IconData icon;
  final String route;
  const _Dest({required this.label, required this.icon, required this.route});
}
