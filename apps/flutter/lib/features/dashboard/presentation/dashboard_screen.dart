import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/dashboard/data/summary_repository.dart';
import 'package:life_os/features/player/application/player_notifier.dart';
import 'package:life_os/features/player/data/stats_repository.dart';
import 'package:life_os/features/player/domain/player.dart';
import 'package:life_os/features/quests/application/quest_actions.dart';
import 'package:life_os/features/quests/application/quests_notifier.dart';
import 'package:life_os/features/schedule/data/schedule_repository.dart';
import 'package:life_os/features/settings/presentation/edit_player_dialog.dart';
import 'package:life_os/shared/widgets/block_bar.dart';
import 'package:life_os/shared/widgets/integration_card.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

/// Daily XP goal shown on the gold Daily Target card.
const _dailyTargetXp = 50;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EnergyRow(player: player),
            const SizedBox(height: 16),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 260, child: _LeftColumn(player: player)),
                  const SizedBox(width: 16),
                  Expanded(child: _CenterColumn(player: player)),
                  const SizedBox(width: 16),
                  SizedBox(width: 300, child: _RightColumn(player: player)),
                ],
              )
            else ...[
              _LeftColumn(player: player),
              const SizedBox(height: 16),
              _CenterColumn(player: player),
              const SizedBox(height: 16),
              _RightColumn(player: player),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top row: the four energy callouts
// ---------------------------------------------------------------------------

class _EnergyRow extends ConsumerWidget {
  final Player player;

  const _EnergyRow({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.of(context).size.width > 700;

    final cards = Energy.values.map((e) {
      return NotionCard(
        color: e.bgColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(e.icon, size: 14, color: e.color),
                const SizedBox(width: 6),
                Text(
                  e.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: e.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BlockBar(value: player.energyOf(e), max: maxEnergy, color: e.color),
            const SizedBox(height: 6),
            Text(
              e.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: NotionColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }).toList();

    if (isWide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          cards[i],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Left column: level, character portrait, today's report
// ---------------------------------------------------------------------------

class _LeftColumn extends ConsumerWidget {
  final Player player;

  const _LeftColumn({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NotionCard(
          color: NotionColors.redBg,
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department_outlined,
                size: 14,
                color: NotionColors.red,
              ),
              const SizedBox(width: 8),
              Text(
                'LEVEL ${player.level}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: NotionColors.red,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                player.job,
                style: const TextStyle(
                  fontSize: 12,
                  color: NotionColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const NotionSectionTitle(
            icon: Icons.battery_5_bar_outlined, title: 'Daily Energy'),
        for (final e in Energy.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NotionCard(
              color: e.bgColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(e.icon, size: 13, color: e.color),
                      const SizedBox(width: 6),
                      Text(
                        e.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: e.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  BlockBar(
                    value: player.energyOf(e),
                    max: maxEnergy,
                    color: e.color,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        const NotionSectionTitle(
            icon: Icons.calendar_today_outlined, title: "Today's Report"),
        NotionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _weekdayName(DateTime.now().weekday),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Progress ',
                    style: TextStyle(
                        fontSize: 12, color: NotionColors.textMuted),
                  ),
                  Expanded(
                    child: BlockBar(
                      value: player.tasksToday.clamp(0, 10),
                      max: 10,
                      color: NotionColors.green,
                      showLabel: false,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "You've Gained ${player.xpToday} XPs Today",
                style: const TextStyle(
                    fontSize: 12, color: NotionColors.textPrimary),
              ),
              Text(
                "You've Completed ${player.tasksToday} Tasks Today",
                style: const TextStyle(
                    fontSize: 12, color: NotionColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'You got this!',
                style: TextStyle(fontSize: 12, color: NotionColors.yellow),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () {
            ref.read(playerProvider.notifier).resetEnergies();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('All energy bars refilled.'),
                duration: Duration(milliseconds: 1200),
              ),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: NotionColors.textMuted,
            alignment: Alignment.centerLeft,
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reset All Energy',
              style: TextStyle(fontSize: 13)),
        ),
        const SizedBox(height: 8),
        const NotionSectionTitle(icon: Icons.event_outlined, title: 'Up Next'),
        const _UpNext(),
      ],
    );
  }
}

/// Real upcoming events from the schedule (synced Google Calendar events and
/// manual entries). Falls back to a connect hint when there's nothing today.
class _UpNext extends ConsumerWidget {
  const _UpNext();

  static String _formatTime(DateTime t) {
    final local = t.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(todayScheduleProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final upcoming = events
        .where((e) => (e.endTime ?? e.startTime).isAfter(now))
        .take(4)
        .toList();

    return NotionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Nothing else scheduled today.',
                style:
                    TextStyle(fontSize: 12, color: NotionColors.textMuted),
              ),
            )
          else
            for (final event in upcoming)
              IntegrationPreviewRow(
                leading: _formatTime(event.startTime),
                title: event.title,
                trailingText: event.isGoogleEvent ? 'Cal' : null,
                trailingColor: NotionColors.blue,
                trailingBg: NotionColors.blueBg,
              ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => context.go('/schedule'),
            child: const Text(
              'Open Schedule →',
              style: TextStyle(
                fontSize: 11,
                color: NotionColors.textFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Center column: radar chart, today's quests, energy menu, performance
// ---------------------------------------------------------------------------

class _CenterColumn extends ConsumerWidget {
  final Player player;

  const _CenterColumn({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NotionCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'Radar Chart of Your Growth Areas',
                style:
                    TextStyle(fontSize: 11, color: NotionColors.textFaint),
              ),
              const SizedBox(height: 8),
              SizedBox(height: 280, child: _AreaRadarChart(player: player)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NotionSectionTitle(
          icon: Icons.checklist_rounded,
          title: "Today's Quests",
          trailing: TextButton(
            onPressed: () => context.go('/quests'),
            child: const Text('View all',
                style:
                    TextStyle(fontSize: 12, color: NotionColors.textMuted)),
          ),
        ),
        // Plan / Today / Done tab strip, as on the template's quest board.
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              for (final (label, active) in const [
                ('Plan', false),
                ('Today', true),
                ('Done', false),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => context.go('/quests'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: active
                            ? NotionColors.surfaceHover
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w400,
                          color: active
                              ? NotionColors.textPrimary
                              : NotionColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _TodaysQuests(),
        const SizedBox(height: 16),
        const NotionSectionTitle(
            icon: Icons.trending_up_outlined, title: 'Weekly XP Trend'),
        NotionCard(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
          child: SizedBox(height: 180, child: _PerformanceChart()),
        ),
      ],
    );
  }
}

class _AreaRadarChart extends StatelessWidget {
  final Player player;

  const _AreaRadarChart({required this.player});

  @override
  Widget build(BuildContext context) {
    // fl_chart scales the radar to the min/max entry, which turns small
    // differences into spikes. Pin the scale with invisible datasets so the
    // pentagon stays full like the template's.
    final maxValue = [
      for (final area in Area.values) player.areaOf(area)
    ].reduce((a, b) => a > b ? a : b);
    final cap = (maxValue * 1.15).ceilToDouble();

    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        radarBackgroundColor: Colors.transparent,
        borderData: FlBorderData(show: false),
        radarBorderData:
            const BorderSide(color: NotionColors.border, width: 1),
        gridBorderData:
            const BorderSide(color: NotionColors.border, width: 1),
        tickBorderData:
            const BorderSide(color: Colors.transparent, width: 0),
        tickCount: 4,
        ticksTextStyle:
            const TextStyle(color: Colors.transparent, fontSize: 8),
        titleTextStyle: const TextStyle(
          color: NotionColors.textMuted,
          fontSize: 12,
        ),
        getTitle: (index, angle) =>
            RadarChartTitle(text: Area.values[index].label),
        dataSets: [
          RadarDataSet(
            fillColor: NotionColors.green.withValues(alpha: 0.25),
            borderColor: NotionColors.green,
            borderWidth: 2,
            entryRadius: 2.5,
            dataEntries: [
              for (final area in Area.values)
                RadarEntry(value: player.areaOf(area).toDouble()),
            ],
          ),
          // Invisible datasets pinning the scale to [0, cap].
          RadarDataSet(
            fillColor: Colors.transparent,
            borderColor: Colors.transparent,
            borderWidth: 0,
            entryRadius: 0,
            dataEntries: [
              for (final _ in Area.values) const RadarEntry(value: 0),
            ],
          ),
          RadarDataSet(
            fillColor: Colors.transparent,
            borderColor: Colors.transparent,
            borderWidth: 0,
            entryRadius: 0,
            dataEntries: [
              for (final _ in Area.values) RadarEntry(value: cap),
            ],
          ),
        ],
      ),
    );
  }
}

/// The first few open quests for today, driven by the same provider as the
/// Quests screen so completing one here removes it everywhere.
class _TodaysQuests extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref
        .watch(questsProvider)
        .where((q) => !q.completed)
        .take(3)
        .toList();

    if (open.isEmpty) {
      return const NotionCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text('All quests done for today 🎉',
                style:
                    TextStyle(fontSize: 12, color: NotionColors.textFaint)),
          ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < open.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: NotionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(open[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  NotionTag(
                    text: '+${open[i].xp} XP',
                    color: NotionColors.green,
                    bgColor: NotionColors.greenBg,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 28,
                    child: OutlinedButton(
                      onPressed: () => completeQuest(context, ref, open[i]),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: NotionColors.textMuted,
                        side: const BorderSide(color: NotionColors.border),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: const Text('Complete',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Real XP-per-week line from /api/summary/trends. Offline (or empty
/// history) falls back to a flat zero line rather than fake numbers.
class _PerformanceChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = ref.watch(trendsProvider).valueOrNull;
    final spots = (weeks == null || weeks.isEmpty)
        ? [for (var i = 0; i < 8; i++) FlSpot(i.toDouble(), 0)]
        : [
            for (var i = 0; i < weeks.length; i++)
              FlSpot(i.toDouble(), weeks[i].xpEarned.toDouble()),
          ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: NotionColors.border, strokeWidth: 0.5),
        ),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 24),
          ),
          rightTitles: AxisTitles(),
          topTitles: AxisTitles(),
          bottomTitles: AxisTitles(),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: NotionColors.green,
            barWidth: 1.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) =>
                  FlDotCirclePainter(
                radius: 2.5,
                color: NotionColors.green,
                strokeColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right column: Player ID card, daily target, habit streaks, task logs
// ---------------------------------------------------------------------------

class _RightColumn extends ConsumerWidget {
  final Player player;

  const _RightColumn({required this.player});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NotionSectionTitle(icon: Icons.badge_outlined, title: 'Player ID'),
        NotionCard(
          color: NotionColors.greenBg.withValues(alpha: 0.4),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: NotionColors.surfaceHover,
                    child: Text(
                      player.name.isEmpty ? '?' : player.name[0],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: NotionColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      player.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Update Player ID',
                    iconSize: 15,
                    color: NotionColors.textMuted,
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const EditPlayerDialog(),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _kv('Update Status', ''),
              _kv('Age', '${player.age}'),
              _kv('Job', player.job),
              _kv('Level', '${player.level}'),
              const SizedBox(height: 8),
              Text(
                'Current ${player.xp} XP',
                style: const TextStyle(
                    fontSize: 12, color: NotionColors.orange),
              ),
              const SizedBox(height: 4),
              BlockBar(
                value: ((player.xp / player.xpToNext) * 10).round(),
                max: 10,
                color: NotionColors.orange,
                showLabel: false,
              ),
              const Divider(height: 24),
              for (final area in Area.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(area.label,
                          style: const TextStyle(
                              fontSize: 12,
                              color: NotionColors.textMuted)),
                      Text(
                        '${player.areaOf(area)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _areaColor(area),
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              _kv('Total', '${player.totalXp} XP'),
              const SizedBox(height: 12),
              SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/status'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NotionColors.textPrimary,
                    side: const BorderSide(color: NotionColors.border),
                  ),
                  icon: const Icon(Icons.monitor_heart_outlined, size: 14),
                  label: const Text('View Status',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NotionCard(
          color: NotionColors.yellowBg,
          child: Column(
            children: [
              const Icon(
                Icons.auto_awesome_outlined,
                size: 17,
                color: NotionColors.yellow,
              ),
              const SizedBox(height: 4),
              Text(
                '${player.xpToday} / $_dailyTargetXp',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: NotionColors.yellow,
                ),
              ),
              const Text(
                'Daily Target (XP)',
                style:
                    TextStyle(fontSize: 11, color: NotionColors.textMuted),
              ),
              const SizedBox(height: 8),
              BlockBar(
                value: ((player.xpToday / _dailyTargetXp) * 10)
                    .round()
                    .clamp(0, 10),
                max: 10,
                color: NotionColors.yellow,
                showLabel: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const NotionSectionTitle(
            icon: Icons.calendar_view_week_outlined, title: 'This Week'),
        const _WeeklySummaryCard(),
        const SizedBox(height: 16),
        const NotionSectionTitle(
            icon: Icons.local_fire_department_outlined, title: 'Streak'),
        const _StreakCard(),
        const SizedBox(height: 16),
        const NotionSectionTitle(icon: Icons.notes_outlined, title: 'Task Logs'),
        NotionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _logRow('Morning Gym', '+Strength', NotionColors.green,
                  NotionColors.greenBg),
              const Divider(height: 1),
              _logRow('Morning Meditation', '+Psyche', NotionColors.purple,
                  NotionColors.purpleBg),
              const Divider(height: 1),
              _logRow('Deep Work', '+Intel', NotionColors.blue,
                  NotionColors.blueBg),
            ],
          ),
        ),
      ],
    );
  }

  static Color _areaColor(Area area) {
    switch (area) {
      case Area.physical:
        return NotionColors.green;
      case Area.intel:
        return NotionColors.blue;
      case Area.psyche:
        return NotionColors.purple;
      case Area.spiritual:
        return NotionColors.yellow;
      case Area.care:
        return NotionColors.pink;
    }
  }

  static Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: const TextStyle(
                  fontSize: 12, color: NotionColors.textMuted)),
          Text(v,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  static Widget _logRow(String name, String tag, Color color, Color bg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 12)),
          NotionTag(text: tag, color: color, bgColor: bg),
        ],
      ),
    );
  }
}

/// Goal progress at a glance: quests, XP, activity and spend for the running
/// week, with an active-days bar (7/7 = perfect week). Data from
/// /api/summary/weekly; hidden numbers degrade to zero when offline.
class _WeeklySummaryCard extends ConsumerWidget {
  const _WeeklySummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(weeklySummaryProvider).valueOrNull;

    if (summary == null) {
      return const NotionCard(
        child: Text(
          'Weekly summary unavailable offline.',
          style: TextStyle(fontSize: 12, color: NotionColors.textFaint),
        ),
      );
    }

    Widget row(IconData icon, String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Icon(icon, size: 13, color: NotionColors.textMuted),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: NotionColors.textMuted)),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return NotionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(Icons.checklist_rounded, 'Quests done',
              '${summary.questsCompleted}'),
          row(Icons.auto_awesome_outlined, 'XP earned', '${summary.xpEarned}'),
          row(Icons.fitness_center_outlined, 'Workouts',
              '${summary.workouts}'),
          if (summary.avgDailySteps > 0)
            row(Icons.directions_walk_outlined, 'Steps / day',
                '${summary.avgDailySteps}'),
          if (summary.avgDailyCalories > 0)
            row(Icons.restaurant_outlined, 'Kcal / day',
                '${summary.avgDailyCalories}'),
          if (summary.spendingCents > 0)
            row(Icons.payments_outlined, 'Spent',
                '\$${(summary.spendingCents / 100).toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Active days ',
                  style: TextStyle(
                      fontSize: 11, color: NotionColors.textMuted)),
              Expanded(
                child: BlockBar(
                  value: summary.activeDays.clamp(0, 7),
                  max: 7,
                  color: NotionColors.green,
                  showLabel: false,
                ),
              ),
              Text(' ${summary.activeDays}/7',
                  style: const TextStyle(
                      fontSize: 11, color: NotionColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Real quest streak from user_stats, with an "at risk" warning until
/// something is completed today.
class _StreakCard extends ConsumerWidget {
  const _StreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(userStatsProvider).valueOrNull;

    if (stats == null) {
      return const NotionCard(
        child: Text(
          'Streak unavailable offline.',
          style: TextStyle(fontSize: 12, color: NotionColors.textFaint),
        ),
      );
    }

    final atRisk = stats.streakAtRisk && stats.currentStreak > 0;
    return NotionCard(
      color: atRisk ? NotionColors.redBg : null,
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department,
            size: 22,
            color: atRisk ? NotionColors.red : NotionColors.orange,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stats.currentStreak} day${stats.currentStreak == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                'Longest ${stats.longestStreak}'
                '${stats.streakFreezes > 0 ? '  •  ${stats.streakFreezes} freeze${stats.streakFreezes == 1 ? '' : 's'}' : ''}',
                style: const TextStyle(
                    fontSize: 11, color: NotionColors.textMuted),
              ),
            ],
          ),
          const Spacer(),
          if (atRisk)
            const NotionTag(
              text: 'At risk',
              color: NotionColors.red,
              bgColor: NotionColors.redBg,
            ),
        ],
      ),
    );
  }
}

String _weekdayName(int weekday) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[weekday - 1];
}
