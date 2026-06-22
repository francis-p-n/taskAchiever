import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';

class SpendingScreen extends StatelessWidget {
  const SpendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance & Spending')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Monthly Spending Breakdown'),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(value: 40, color: Colors.blue, title: 'Food'),
                    PieChartSectionData(value: 30, color: Colors.red, title: 'Rent'),
                    PieChartSectionData(value: 15, color: Colors.green, title: 'Transport'),
                    PieChartSectionData(value: 15, color: Colors.orange, title: 'Other'),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Recent Transactions'),
            const ListTile(
              leading: Icon(Icons.shopping_cart, color: Colors.blue),
              title: Text('Groceries'),
              trailing: Text('-\$45.00', style: TextStyle(color: Colors.redAccent)),
            ),
            const ListTile(
              leading: Icon(Icons.directions_car, color: Colors.green),
              title: Text('Uber Ride'),
              trailing: Text('-\$15.50', style: TextStyle(color: Colors.redAccent)),
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
}
