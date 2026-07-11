import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/application/player_notifier.dart';

/// Barely-there color atmosphere behind every screen: a green breath at the
/// top-left and a purple one at the bottom-right, ~4% alpha. It reads as
/// depth, not decoration — the flat charcoal stays in charge.
class _Atmosphere extends StatelessWidget {
  final Widget child;

  const _Atmosphere({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.9, -1.1),
                  radius: 1.3,
                  colors: [
                    NotionColors.green.withValues(alpha: 0.045),
                    Colors.transparent,
                  ],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.1, 1.2),
                    radius: 1.2,
                    colors: [
                      NotionColors.purple.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class MainLayout extends ConsumerWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine layout based on screen width
    final isDesktop = MediaQuery.of(context).size.width > 800;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: NotionColors.background,
        body: Row(
          children: [
            _buildSidebar(context, ref),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: _Atmosphere(child: child)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: NotionColors.background,
      body: _Atmosphere(child: child),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    return NavigationRail(
      selectedIndex: _calculateSelectedIndex(context),
      onDestinationSelected: (int index) => _onItemTapped(index, context),
      labelType: NavigationRailLabelType.all,
      backgroundColor: NotionColors.surface,
      indicatorColor: NotionColors.surfaceHover,
      selectedIconTheme:
          const IconThemeData(color: NotionColors.textPrimary, size: 20),
      selectedLabelTextStyle: const TextStyle(
        color: NotionColors.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedIconTheme:
          const IconThemeData(color: NotionColors.textFaint, size: 20),
      unselectedLabelTextStyle:
          const TextStyle(color: NotionColors.textFaint, fontSize: 12),
      leading: Padding(
        padding: const EdgeInsets.only(bottom: 20.0, top: 16.0),
        child: Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: NotionColors.surfaceHover,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: NotionColors.border),
              ),
              child: const Center(
                child: Icon(
                  Icons.grid_view_rounded,
                  size: 15,
                  color: NotionColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: NotionColors.redBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'LV ${player.level}',
                style: NotionType.mono(
                  size: 11,
                  weight: FontWeight.w700,
                  color: NotionColors.red,
                ),
              ),
            ),
          ],
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.fitness_center_outlined),
          selectedIcon: Icon(Icons.fitness_center),
          label: Text('Fitness'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.restaurant_menu_outlined),
          selectedIcon: Icon(Icons.restaurant_menu),
          label: Text('Food'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: Text('Spending'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: Text('Schedule'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.list_alt_outlined),
          selectedIcon: Icon(Icons.list_alt),
          label: Text('Quests'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.monitor_heart_outlined),
          selectedIcon: Icon(Icons.monitor_heart),
          label: Text('Status'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _calculateSelectedIndex(context),
      onTap: (int index) => _onItemTapped(index, context),
      type: BottomNavigationBarType.fixed, // Needed for >3 items
      backgroundColor: NotionColors.surface,
      selectedItemColor: NotionColors.textPrimary,
      unselectedItemColor: NotionColors.textFaint,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.fitness_center_outlined),
          activeIcon: Icon(Icons.fitness_center),
          label: 'Fit',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_menu_outlined),
          activeIcon: Icon(Icons.restaurant_menu),
          label: 'Food',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          activeIcon: Icon(Icons.account_balance_wallet),
          label: 'Cash',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month_outlined),
          activeIcon: Icon(Icons.calendar_month),
          label: 'Plan',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.list_alt_outlined),
          activeIcon: Icon(Icons.list_alt),
          label: 'Quests',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.monitor_heart_outlined),
          activeIcon: Icon(Icons.monitor_heart),
          label: 'Status',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Config',
        ),
      ],
    );
  }

  static int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/fitness')) return 1;
    if (location.startsWith('/food')) return 2;
    if (location.startsWith('/spending')) return 3;
    if (location.startsWith('/schedule')) return 4;
    if (location.startsWith('/quests')) return 5;
    if (location.startsWith('/status')) return 6;
    if (location.startsWith('/settings')) return 7;
    return 0; // Default to Home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/fitness');
        break;
      case 2:
        context.go('/food');
        break;
      case 3:
        context.go('/spending');
        break;
      case 4:
        context.go('/schedule');
        break;
      case 5:
        context.go('/quests');
        break;
      case 6:
        context.go('/status');
        break;
      case 7:
        context.go('/settings');
        break;
    }
  }
}
