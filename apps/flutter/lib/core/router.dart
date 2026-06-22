import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_achiever/features/dashboard/presentation/dashboard_screen.dart';
import 'package:life_achiever/features/dashboard/presentation/main_layout.dart';
import 'package:life_achiever/features/quests/presentation/quests_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MainLayout(child: child);
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/quests',
          builder: (context, state) => const QuestsScreen(),
        ),
      ],
    ),
  ],
);
