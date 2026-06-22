import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/providers.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync Quests',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data...')),
              );
              
              final syncEngine = ref.read(syncEngineProvider);
              await syncEngine.pullUpdates();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync complete!')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 3, // Mock data for now
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.check_circle_outline, color: Colors.green),
              title: Text('Sample Quest ${index + 1}'),
              subtitle: const Text('Complete this task to earn XP.'),
              trailing: const Text('+10 XP', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
          );
        },
      ),
    );
  }
}
