import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/theme.dart';
import 'package:life_achiever/features/fitness/data/fitness_repository.dart';
import 'package:life_achiever/shared/widgets/metric_callout.dart';
import 'package:life_achiever/shared/widgets/notion_card.dart';

class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitnessData = ref.watch(dailyFitnessProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('💪  Training')),
      body: fitnessData.when(
        data: (data) => _buildContent(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    final steps = (data['steps'] ?? 0) as num;
    final calories = (data['caloriesBurned'] ?? 0) as num;

    return PageBody(
      children: [
        MetricRow(
          children: [
            MetricCallout(
              emoji: '👟',
              label: 'Steps',
              value: '$steps',
              color: NotionColors.green,
              bgColor: NotionColors.greenBg,
              progress: (steps / 10000).clamp(0.0, 1.0).toDouble(),
            ),
            MetricCallout(
              emoji: '🔥',
              label: 'Calories Burned',
              value: '$calories kcal',
              color: NotionColors.orange,
              bgColor: NotionColors.orangeBg,
            ),
            const MetricCallout(
              emoji: '⏱️',
              label: 'Active Time',
              value: '0 min',
              color: NotionColors.blue,
              bgColor: NotionColors.blueBg,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(emoji: '❤️', title: 'Heart Rate (Today)'),
        NotionCard(
          padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
          child: SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: NotionColors.border,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles:
                        SideTitles(showTitles: true, reservedSize: 32),
                  ),
                  rightTitles: AxisTitles(),
                  topTitles: AxisTitles(),
                  bottomTitles: AxisTitles(),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 60),
                      FlSpot(1, 65),
                      FlSpot(2, 70),
                      FlSpot(3, 110),
                      FlSpot(4, 120),
                      FlSpot(5, 80),
                      FlSpot(6, 65),
                    ],
                    isCurved: true,
                    color: NotionColors.red,
                    barWidth: 2,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: NotionColors.red.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(emoji: '🏋️', title: 'Activity Log'),
        const NotionCard(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No workouts logged today — train to earn STR.',
              style:
                  TextStyle(fontSize: 12, color: NotionColors.textFaint),
            ),
          ),
        ),
      ],
    );
  }
}
