import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';

class FitnessScreen extends StatelessWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitness & Health')),
      body: SingleChildScrollView(
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
            // additional content mocked
          ],
        ),
      ),
    );
  }
}
