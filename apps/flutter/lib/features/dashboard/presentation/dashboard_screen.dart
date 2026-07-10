import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/application/player_notifier.dart';
import 'package:life_os/features/player/domain/player.dart';
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
          onPressed: () =>
              ref.read(playerProvider.notifier).resetEnergies(),
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
        NotionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Opacity(
                opacity: 0.55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    IntegrationPreviewRow(
                      leading: '10:00 AM',
                      title: 'Team Meeting',
                    ),
                    IntegrationPreviewRow(
                      leading: '6:30 PM',
                      title: 'Gym — Push Day',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => context.go('/schedule'),
                child: const Text(
                  'via Google Calendar — connect in Schedule →',
                  style: TextStyle(
                    fontSize: 11,
                    color: NotionColors.textFaint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
            icon: Icons.battery_charging_full_outlined, title: 'Energy Menu'),
        const _EnergyMenu(),
        const SizedBox(height: 16),
        const NotionSectionTitle(
            icon: Icons.trending_up_outlined, title: 'Monthly Performance'),
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

/// Compact quest cards mirroring the "Watch Anime / Practice Session" row.
class _TodaysQuests extends ConsumerWidget {
  static const _quests = [
    ('Watch Anime', Area.psyche, 5),
    ('Practice Session', Area.intel, 10),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final (title, area, xp) in _quests) ...[
          Expanded(
            child: NotionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  NotionTag(
                    text: '+$xp XP',
                    color: NotionColors.green,
                    bgColor: NotionColors.greenBg,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 28,
                    child: OutlinedButton(
                      onPressed: () {
                        ref
                            .read(playerProvider.notifier)
                            .gainXp(xp, area: area);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$title complete  +$xp XP')),
                        );
                      },
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
          const SizedBox(width: 12),
        ],
        const Expanded(
          child: NotionCard(
            child: SizedBox(
              height: 88,
              child: Center(
                child: Text('+ New page',
                    style: TextStyle(
                        fontSize: 12, color: NotionColors.textFaint)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The pill-button board: actions that spend or restore energies, grouped
/// into one labeled column per energy like the template.
class _EnergyMenu extends ConsumerWidget {
  const _EnergyMenu();

  static const _actions = <Energy, List<(IconData, String, int)>>{
    Energy.hp: [
      (Icons.ramen_dining_outlined, 'Food +1', 1),
      (Icons.bed_outlined, 'Nap +2', 2),
      (Icons.nightlight_outlined, 'Sleep +4', 4),
      (Icons.pool_outlined, 'Swim +3', 3),
    ],
    Energy.mood: [
      (Icons.mic_none_outlined, 'Sing +1', 1),
      (Icons.group_outlined, 'Friends +2', 2),
      (Icons.movie_outlined, 'Watch Edits +1', 1),
      (Icons.directions_walk_outlined, 'Walk +1', 1),
    ],
    Energy.focus: [
      (Icons.coffee_outlined, 'Break +1', 1),
      (Icons.menu_book_outlined, 'Study -2', -2),
      (Icons.smartphone_outlined, 'Doomscroll -1', -1),
    ],
    Energy.motivation: [
      (Icons.spa_outlined, 'Affirmation +1', 1),
      (Icons.school_outlined, 'Mentors +1', 1),
      (Icons.smartphone_outlined, 'Doomscroll -1', -1),
    ],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotionCard(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final entry in _actions.entries)
            SizedBox(
              width: 168,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(entry.key.icon, size: 13, color: entry.key.color),
                      const SizedBox(width: 6),
                      Text(
                        entry.key.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: entry.key.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final (icon, label, delta) in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(4),
                        onTap: () {
                          ref
                              .read(playerProvider.notifier)
                              .adjustEnergy(entry.key, delta);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '${entry.key.label} ${delta > 0 ? '+' : ''}$delta'),
                              duration: const Duration(milliseconds: 900),
                            ),
                          );
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 13,
                              color: delta >= 0
                                  ? entry.key.color
                                  : NotionColors.red,
                            ),
                            const SizedBox(width: 6),
                            NotionTag(
                              text: label,
                              color: delta >= 0
                                  ? entry.key.color
                                  : NotionColors.red,
                              bgColor: delta >= 0
                                  ? entry.key.bgColor
                                  : NotionColors.redBg,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PerformanceChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const spots = [
      FlSpot(0, 1),
      FlSpot(1, 3),
      FlSpot(2, 2),
      FlSpot(3, 6),
      FlSpot(4, 2),
      FlSpot(5, 4),
      FlSpot(6, 1),
      FlSpot(7, 5),
      FlSpot(8, 3),
      FlSpot(9, 7),
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

class _RightColumn extends StatelessWidget {
  final Player player;

  const _RightColumn({required this.player});

  @override
  Widget build(BuildContext context) {
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
                  Text(
                    player.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
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
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: NotionColors.textPrimary,
                    side: const BorderSide(color: NotionColors.border),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 14),
                  label: const Text('Log Status',
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
            icon: Icons.repeat_rounded, title: 'Habit Streaks'),
        NotionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _habitRow('Morning Gym', 'Streak 4', NotionColors.green,
                  NotionColors.greenBg),
              const Divider(height: 1),
              _habitRow('Morning Meditation', 'Streak 7', NotionColors.purple,
                  NotionColors.purpleBg),
            ],
          ),
        ),
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

  static Widget _habitRow(
      String name, String streak, Color color, Color bg) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontSize: 12)),
          NotionTag(text: streak, color: color, bgColor: bg),
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
