import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/router.dart';
import 'package:life_achiever/core/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Isar initialization will go here later
  runApp(const ProviderScope(child: TaskAchieverApp()));
}

class TaskAchieverApp extends StatelessWidget {
  const TaskAchieverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TaskAchiever',
      theme: buildGameTheme(),
      routerConfig: goRouter,
    );
  }
}
