import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/router.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/neu.dart';

class _Tab {
  const _Tab(this.icon, this.label, this.route);
  final IconData icon;
  final String label;
  final String route;
}

const _tabs = [
  _Tab(Symbols.home_rounded, 'Home', Routes.home),
  _Tab(Symbols.assignment_rounded, 'Today', Routes.today),
  _Tab(Symbols.groups_rounded, 'Group', Routes.group),
  _Tab(Symbols.chat_bubble_rounded, 'Chat', Routes.chat),
  _Tab(Symbols.person_rounded, 'Profile', Routes.profile),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  int _indexFor(String location) {
    final i = _tabs.indexWhere((t) => location.startsWith(t.route));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If the session goes signedOut (e.g. 401 interceptor), redirect to welcome.
    ref.listen<SessionState>(sessionProvider, (_, s) {
      if (s.status == AuthStatus.signedOut) {
        context.go(Routes.welcome);
      }
    });

    final location = GoRouterState.of(context).uri.path;
    final current = _indexFor(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: Neu.card(radius: Neu.rPill, depth: 0.6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < _tabs.length; i++)
              _NavItem(
                tab: _tabs[i],
                selected: i == current,
                onTap: () => context.go(_tabs[i].route),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.onTap});
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.coral : Colors.transparent,
          borderRadius: BorderRadius.circular(Neu.rPill),
          boxShadow: selected ? Neu.small() : null,
        ),
        child: Row(
          children: [
            Icon(tab.icon,
                size: 24,
                fill: selected ? 1 : 0,
                color: selected ? Colors.white : AppColors.inkSoft),
            if (selected) ...[
              const SizedBox(width: 8),
              Text(tab.label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }
}
