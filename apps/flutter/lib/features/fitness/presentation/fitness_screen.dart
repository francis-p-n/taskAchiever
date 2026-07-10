import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/fitness/data/fitness_repository.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

class FitnessScreen extends ConsumerWidget {
  const FitnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitnessData = ref.watch(dailyFitnessProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Training')),
      body: fitnessData.when(
        data: (data) => _buildContent(context, ref, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            _buildContent(context, ref, const DailyFitnessDto()),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    DailyFitnessDto data,
  ) {
    return PageBody(
      children: [
        MetricRow(
          children: [
            MetricCallout(
              icon: Icons.directions_run_outlined,
              label: 'Steps',
              value: '${data.steps}',
              color: NotionColors.green,
              bgColor: NotionColors.greenBg,
              progress: (data.steps / 10000).clamp(0.0, 1.0),
            ),
            MetricCallout(
              icon: Icons.local_fire_department_outlined,
              label: 'Calories Burned',
              value: '${data.caloriesBurned} kcal',
              color: NotionColors.orange,
              bgColor: NotionColors.orangeBg,
            ),
            MetricCallout(
              icon: Icons.favorite_outline,
              label: 'Heart Rate',
              value: data.hasHeartRate
                  ? '${data.heartRateMin}-${data.heartRateMax} bpm'
                  : '—',
              color: NotionColors.red,
              bgColor: NotionColors.redBg,
            ),
          ],
        ),
        const SizedBox(height: 20),
        NotionSectionTitle(
          icon: Icons.monitor_heart_outlined,
          title: 'Heart Rate (Today)',
          trailing: data.hasHeartRate
              ? const NotionTag(
                  text: "today's range",
                  color: NotionColors.red,
                  bgColor: NotionColors.redBg,
                )
              : const NotionTag(
                  text: 'sample data',
                  color: NotionColors.textMuted,
                  bgColor: NotionColors.surfaceHover,
                ),
        ),
        NotionCard(
          padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
          child: SizedBox(
            height: 220,
            child: LineChart(_heartChartData(data)),
          ),
        ),
        const SizedBox(height: 20),
        NotionSectionTitle(
          icon: Icons.fitness_center_outlined,
          title: 'Activity Log',
          trailing: TextButton.icon(
            onPressed: () => _openLogSheet(context, ref),
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Log', style: TextStyle(fontSize: 12)),
          ),
        ),
        if (data.isEmpty)
          const NotionCard(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'No workouts logged today — train to earn STR.',
                style:
                    TextStyle(fontSize: 12, color: NotionColors.textFaint),
              ),
            ),
          )
        else
          NotionCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bolt_outlined,
                    size: 15, color: NotionColors.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: NotionColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activitySummary(data),
                        style: const TextStyle(
                          fontSize: 12,
                          color: NotionColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _activitySummary(DailyFitnessDto data) {
    var summary = '${data.steps} steps · ${data.caloriesBurned} kcal burned';
    if (data.hasHeartRate) {
      summary += ' · ${data.heartRateMin}-${data.heartRateMax} bpm';
    }
    return summary;
  }

  LineChartData _heartChartData(DailyFitnessDto data) {
    final live = data.hasHeartRate;

    List<FlSpot> spots;
    double? minY;
    double? maxY;
    if (live) {
      // A simple smooth curve spanning today's recorded min-max range.
      final low = data.heartRateMin!.toDouble();
      final high = data.heartRateMax!.toDouble();
      final mid = (low + high) / 2;
      spots = [
        FlSpot(0, low),
        FlSpot(1.5, mid),
        FlSpot(3, high),
        FlSpot(4.5, mid),
        FlSpot(6, low),
      ];
      minY = low - 10;
      maxY = high + 10;
    } else {
      spots = const [
        FlSpot(0, 60),
        FlSpot(1, 65),
        FlSpot(2, 70),
        FlSpot(3, 110),
        FlSpot(4, 120),
        FlSpot(5, 80),
        FlSpot(6, 65),
      ];
    }

    // Placeholder data is dimmed to make clear it isn't a live reading.
    final lineColor =
        live ? NotionColors.red : NotionColors.red.withValues(alpha: 0.35);

    return LineChartData(
      minY: minY,
      maxY: maxY,
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
          sideTitles: SideTitles(showTitles: true, reservedSize: 32),
        ),
        rightTitles: AxisTitles(),
        topTitles: AxisTitles(),
        bottomTitles: AxisTitles(),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: lineColor,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: NotionColors.red.withValues(alpha: live ? 0.08 : 0.04),
          ),
        ),
      ],
    );
  }

  Future<void> _openLogSheet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_LogActivityInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NotionColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        side: BorderSide(color: NotionColors.border),
      ),
      builder: (_) => const _LogActivitySheet(),
    );
    if (result == null || !context.mounted) return;

    final ok = await ref.read(fitnessRepositoryProvider).logActivity(
          steps: result.steps,
          caloriesBurned: result.caloriesBurned,
          heartRateMin: result.heartRateMin,
          heartRateMax: result.heartRateMax,
        );
    if (!context.mounted) return;
    if (ok) ref.invalidate(dailyFitnessProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Activity logged.'
              : 'Backend unreachable — activity not saved.',
        ),
      ),
    );
  }
}

class _LogActivityInput {
  final int? steps;
  final int? caloriesBurned;
  final int? heartRateMin;
  final int? heartRateMax;

  const _LogActivityInput({
    this.steps,
    this.caloriesBurned,
    this.heartRateMin,
    this.heartRateMax,
  });
}

class _LogActivitySheet extends StatefulWidget {
  const _LogActivitySheet();

  @override
  State<_LogActivitySheet> createState() => _LogActivitySheetState();
}

class _LogActivitySheetState extends State<_LogActivitySheet> {
  final _steps = TextEditingController();
  final _calories = TextEditingController();
  final _hrMin = TextEditingController();
  final _hrMax = TextEditingController();

  bool get _hasAnyValue =>
      _parse(_steps) != null ||
      _parse(_calories) != null ||
      _parse(_hrMin) != null ||
      _parse(_hrMax) != null;

  int? _parse(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  @override
  void initState() {
    super.initState();
    for (final c in [_steps, _calories, _hrMin, _hrMax]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _steps.dispose();
    _calories.dispose();
    _hrMin.dispose();
    _hrMax.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _LogActivityInput(
        steps: _parse(_steps),
        caloriesBurned: _parse(_calories),
        heartRateMin: _parse(_hrMin),
        heartRateMax: _parse(_hrMax),
      ),
    );
  }

  Widget _field(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
            color: NotionColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 13,
            color: NotionColors.textPrimary,
          ),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.fitness_center_outlined,
                      size: 15, color: NotionColors.textMuted),
                  SizedBox(width: 8),
                  Text(
                    'Log activity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: NotionColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'All fields optional — fill in at least one.',
                style:
                    TextStyle(fontSize: 11, color: NotionColors.textFaint),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _field('Steps', 'e.g. 8000', _steps)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                        'Calories burned', 'e.g. 350', _calories),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field('Heart rate min', 'bpm', _hrMin),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field('Heart rate max', 'bpm', _hrMax),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel',
                        style: TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _hasAnyValue ? _submit : null,
                    child: const Text('Log activity',
                        style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
