import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/router.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/data/stats_repository.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Isar initialization will go here later
  runApp(const ProviderScope(child: LifeOSApp()));
}

class LifeOSApp extends ConsumerWidget {
  const LifeOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kick off the backend fetches at startup: quest data so the Quests tab
    // is warm, and lifetime stats so the player's level reflects the DB.
    ref.watch(remoteQuestsProvider);
    ref.watch(playerHydrationProvider);

    return MaterialApp.router(
      title: 'lifeOS',
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      routerConfig: goRouter,
    );
  }
}
