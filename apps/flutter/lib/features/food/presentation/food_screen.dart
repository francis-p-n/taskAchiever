import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';
import 'package:life_achiever/features/food/data/food_repository.dart';

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodData = ref.watch(todayFoodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition & Food')),
      body: foodData.when(
        data: (logs) => _buildContent(context, logs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> logs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Daily Macros'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildMacroIndicator('Protein', 0.8, Colors.blue),
              _buildMacroIndicator('Carbs', 0.5, Colors.orange),
              _buildMacroIndicator('Fats', 0.6, Colors.yellow),
            ],
          ),
          const SizedBox(height: 32),
          const SectionHeader(title: 'Meals Today'),
          if (logs.isEmpty)
            const Text('No meals logged today.')
          else
            ...logs.map((log) => ListTile(
                  leading: const Icon(Icons.restaurant),
                  title: Text(log['mealType'] ?? 'Meal'),
                  subtitle: Text('${log['calories'] ?? 0} kcal'),
                )),
        ],
      ),
    );
  }

  Widget _buildMacroIndicator(String label, double progress, Color color) {
    return Column(
      children: [
        CircularProgressIndicator(
          value: progress,
          color: color,
          backgroundColor: color.withOpacity(0.2),
          strokeWidth: 8,
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
