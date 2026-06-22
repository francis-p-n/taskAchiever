import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';
import 'package:life_achiever/features/fitness/data/fitness_repository.dart';

class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitnessData = ref.watch(dailyFitnessProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Fitness & Health')),
      body: fitnessData.when(
        data: (data) => _buildContent(context, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> data) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Heart Rate (Today)'),
          SizedBox(
            height: 250,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
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
                    color: Colors.redAccent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.redAccent.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const SectionHeader(title: 'Activity Summary'),
          Text('Steps: ${data['steps'] ?? 0}'),
          Text('Calories Burned: ${data['caloriesBurned'] ?? 0}'),
        ],
      ),
    );
  }
}
