import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:life_achiever/features/dashboard/presentation/dashboard_screen.dart';
import 'package:life_achiever/features/dashboard/presentation/main_layout.dart';
import 'package:life_achiever/features/quests/presentation/quests_screen.dart';
import 'package:life_achiever/features/fitness/presentation/fitness_screen.dart';
import 'package:life_achiever/features/food/presentation/food_screen.dart';
import 'package:life_achiever/features/spending/presentation/spending_screen.dart';
import 'package:life_achiever/features/schedule/presentation/schedule_screen.dart';

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
          path: '/fitness',
          builder: (context, state) => const FitnessScreen(),
        ),
        GoRoute(
          path: '/food',
          builder: (context, state) => const FoodScreen(),
        ),
        GoRoute(
          path: '/spending',
          builder: (context, state) => const SpendingScreen(),
        ),
        GoRoute(
          path: '/schedule',
          builder: (context, state) => const ScheduleScreen(),
        ),
        GoRoute(
          path: '/quests',
          builder: (context, state) => const QuestsScreen(),
        ),
      ],
    ),
  ],
);
