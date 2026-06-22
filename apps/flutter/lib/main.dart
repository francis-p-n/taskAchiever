import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/router.dart';

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
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      routerConfig: goRouter,
    );
  }
}
