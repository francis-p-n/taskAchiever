import 'package:flutter/material.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';

class FoodScreen extends StatelessWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition & Food')),
      body: SingleChildScrollView(
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
            const ListTile(
              leading: Icon(Icons.breakfast_dining),
              title: Text('Breakfast'),
              subtitle: Text('Oatmeal & Eggs (450 kcal)'),
            ),
            const ListTile(
              leading: Icon(Icons.lunch_dining),
              title: Text('Lunch'),
              subtitle: Text('Chicken Salad (600 kcal)'),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
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
