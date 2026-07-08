import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/theme.dart';
import 'package:life_achiever/features/food/data/food_repository.dart';
import 'package:life_achiever/shared/widgets/block_bar.dart';
import 'package:life_achiever/shared/widgets/metric_callout.dart';
import 'package:life_achiever/shared/widgets/notion_card.dart';

const _macros = <(String, String, int, int, Color, Color)>[
  ('🥩', 'Protein', 96, 120, NotionColors.blue, NotionColors.blueBg),
  ('🍞', 'Carbs', 110, 220, NotionColors.orange, NotionColors.orangeBg),
  ('🥑', 'Fats', 42, 70, NotionColors.yellow, NotionColors.yellowBg),
];

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final foodData = ref.watch(todayFoodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🍜  Nutrition')),
      body: foodData.when(
        data: (logs) => _buildContent(context, logs),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> logs) {
    return PageBody(
      children: [
        const MetricRow(
          children: [
            MetricCallout(
              emoji: '🔥',
              label: 'Calories',
              value: '1,850 / 2,200',
              color: NotionColors.green,
              bgColor: NotionColors.greenBg,
              progress: 1850 / 2200,
            ),
            MetricCallout(
              emoji: '💧',
              label: 'Water',
              value: '5 / 8 cups',
              color: NotionColors.blue,
              bgColor: NotionColors.blueBg,
              progress: 5 / 8,
            ),
            MetricCallout(
              emoji: '🍽️',
              label: 'Meals Logged',
              value: '2',
              color: NotionColors.purple,
              bgColor: NotionColors.purpleBg,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(emoji: '📐', title: 'Daily Macros'),
        NotionCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              for (final (emoji, label, current, target, color, bg)
                  in _macros)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 64,
                        child: Text(label,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Expanded(
                        child: BlockBar(
                          value: ((current / target) * 10).round().clamp(0, 10),
                          max: 10,
                          color: color,
                          showLabel: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      NotionTag(
                        text: '$current / ${target}g',
                        color: color,
                        bgColor: bg,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        NotionSectionTitle(
          emoji: '🍱',
          title: 'Meals Today',
          trailing: TextButton.icon(
            onPressed: () {},
            style: TextButton.styleFrom(
                foregroundColor: NotionColors.textMuted),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Log meal', style: TextStyle(fontSize: 12)),
          ),
        ),
        NotionCard(
          padding: EdgeInsets.zero,
          child: logs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No meals logged today — log one to earn VIT.',
                      style: TextStyle(
                          fontSize: 12, color: NotionColors.textFaint),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < logs.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            const Text('🍽️',
                                style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                (logs[i]['mealType'] ?? 'Meal') as String,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            NotionTag(
                              text: '${logs[i]['calories'] ?? 0} kcal',
                              color: NotionColors.green,
                              bgColor: NotionColors.greenBg,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
