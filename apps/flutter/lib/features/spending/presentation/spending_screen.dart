import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';
import 'package:life_achiever/features/spending/data/spending_repository.dart';

class SpendingScreen extends ConsumerWidget {
  const SpendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingData = ref.watch(recentSpendingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Finance & Spending')),
      body: spendingData.when(
        data: (transactions) => _buildContent(context, transactions),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> transactions) {
    return SingleChildScrollView(
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
          if (transactions.isEmpty)
            const Text('No recent transactions.')
          else
            ...transactions.map((tx) => ListTile(
                  leading: const Icon(Icons.payment, color: Colors.blue),
                  title: Text(tx['merchant'] ?? tx['category'] ?? 'Transaction'),
                  trailing: Text('-\$${((tx['amount'] ?? 0) / 100).toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.redAccent)),
                )),
        ],
      ),
    );
  }
}
