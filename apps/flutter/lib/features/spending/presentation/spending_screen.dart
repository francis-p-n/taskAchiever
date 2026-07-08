import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/theme.dart';
import 'package:life_achiever/features/spending/data/spending_repository.dart';
import 'package:life_achiever/shared/widgets/metric_callout.dart';
import 'package:life_achiever/shared/widgets/notion_card.dart';

/// Category slices for the monthly breakdown, in Notion's muted palette.
const _categories = <(String, double, Color, Color)>[
  ('Food', 40, NotionColors.blue, NotionColors.blueBg),
  ('Rent', 30, NotionColors.red, NotionColors.redBg),
  ('Transport', 15, NotionColors.green, NotionColors.greenBg),
  ('Other', 15, NotionColors.orange, NotionColors.orangeBg),
];

class SpendingScreen extends ConsumerWidget {
  const SpendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingData = ref.watch(recentSpendingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('💰  Gold')),
      body: spendingData.when(
        data: (transactions) => _buildContent(context, transactions),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> transactions) {
    return PageBody(
      children: [
        const MetricRow(
          children: [
            MetricCallout(
              emoji: '💸',
              label: 'Spent Today',
              value: '\$45.00',
              color: NotionColors.red,
              bgColor: NotionColors.redBg,
            ),
            MetricCallout(
              emoji: '📆',
              label: 'This Month',
              value: '\$1,240',
              color: NotionColors.yellow,
              bgColor: NotionColors.yellowBg,
              progress: 0.62,
            ),
            MetricCallout(
              emoji: '🏦',
              label: 'Budget Left',
              value: '\$760',
              color: NotionColors.green,
              bgColor: NotionColors.greenBg,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const NotionSectionTitle(emoji: '📊', title: 'Monthly Breakdown'),
        NotionCard(
          padding: const EdgeInsets.all(20),
          child: MediaQuery.of(context).size.width > 560
              ? Row(
                  children: [
                    Expanded(child: _buildDonut()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildLegend()),
                  ],
                )
              : Column(
                  children: [
                    _buildDonut(),
                    const SizedBox(height: 20),
                    _buildLegend(),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        NotionSectionTitle(
          emoji: '🧾',
          title: 'Recent Transactions',
          trailing: TextButton.icon(
            onPressed: () {},
            style: TextButton.styleFrom(
                foregroundColor: NotionColors.textMuted),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Add', style: TextStyle(fontSize: 12)),
          ),
        ),
        NotionCard(
          padding: EdgeInsets.zero,
          child: transactions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No transactions yet — add one to start tracking your gold.',
                      style: TextStyle(
                          fontSize: 12, color: NotionColors.textFaint),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < transactions.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _TransactionRow(tx: transactions[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildDonut() {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sections: [
            for (final (_, value, color, _) in _categories)
              PieChartSectionData(
                value: value,
                color: color,
                showTitle: false,
                radius: 28,
              ),
          ],
          sectionsSpace: 3,
          centerSpaceRadius: 52,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    final total = _categories.fold<double>(0, (sum, c) => sum + c.$2);

    return Column(
      children: [
        for (final (label, value, color, bg) in _categories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 13)),
                ),
                NotionTag(
                  text: '${(value / total * 100).round()}%',
                  color: color,
                  bgColor: bg,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final dynamic tx;

  const _TransactionRow({required this.tx});

  @override
  Widget build(BuildContext context) {
    final category = (tx['category'] ?? 'Other') as String;
    final match = _categories.firstWhere(
      (c) => c.$1.toLowerCase() == category.toLowerCase(),
      orElse: () => _categories.last,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          NotionTag(text: category, color: match.$3, bgColor: match.$4),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              (tx['merchant'] ?? 'Transaction') as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '-\$${((tx['amount'] ?? 0) / 100).toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NotionColors.red,
            ),
          ),
        ],
      ),
    );
  }
}
