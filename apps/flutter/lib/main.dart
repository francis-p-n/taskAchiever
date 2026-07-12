import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:life_os/core/providers.dart';
import 'package:life_os/core/router.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/food/presentation/food_screen.dart';
import 'package:life_os/features/player/data/stats_repository.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';
import 'package:life_os/features/spending/presentation/add_expense_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LifeOSApp()));
}

class LifeOSApp extends ConsumerStatefulWidget {
  const LifeOSApp({super.key});

  @override
  ConsumerState<LifeOSApp> createState() => _LifeOSAppState();
}

class _LifeOSAppState extends ConsumerState<LifeOSApp> {
  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    // Home-screen widget deep links (Android): a cold start delivers the
    // launch URI, a warm app gets it on the click stream.
    if (Platform.isAndroid) {
      HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetUri);
      _widgetClicks = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    }
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    super.dispose();
  }

  Future<void> _handleWidgetUri(Uri? uri) async {
    if (uri == null) return;
    // Let the first frame land so the navigator context exists on cold start.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final context = goRouter.routerDelegate.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    switch (uri.host) {
      case 'add-expense':
        goRouter.go('/spending');
        await showAddExpenseSheet(context, ref);
      case 'add-meal':
        goRouter.go('/food');
        await openLogMealSheet(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kick off the backend fetches at startup: quest data so the Quests tab
    // is warm, and lifetime stats so the player's level reflects the DB.
    ref.watch(remoteQuestsProvider);
    ref.watch(playerHydrationProvider);
    // Offline sync loop: replay queued mutations at startup and on reconnect.
    ref.watch(offlineSyncProvider);

    return MaterialApp.router(
      title: 'lifeOS',
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      routerConfig: goRouter,
    );
  }
}
