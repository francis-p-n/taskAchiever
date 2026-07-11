import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/data/integrations_repository.dart';
import 'package:life_os/core/network/api_client.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/application/player_notifier.dart';
import 'package:life_os/features/player/data/stats_repository.dart';
import 'package:life_os/features/player/domain/player.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

/// True when the sync backend answers its health check.
final backendHealthProvider = FutureProvider<bool>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get(
          '/health',
          options: Options(headers: {'skip-auth': 'true'}),
        );
    return res.statusCode == 200;
  } on DioException {
    return false;
  }
});

/// Lifetime server stats (null when the backend is offline).
final serverStatsProvider = FutureProvider<UserStatsDto?>((ref) {
  return ref.watch(statsRepositoryProvider).fetchStats();
});

class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final online = ref.watch(backendHealthProvider).valueOrNull;
    final stats = ref.watch(serverStatsProvider).valueOrNull;
    final integrations = ref.watch(integrationsStatusProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_outlined, size: 18),
            onPressed: () {
              ref.invalidate(backendHealthProvider);
              ref.invalidate(serverStatsProvider);
              ref.invalidate(integrationsStatusProvider);
            },
          ),
        ],
      ),
      body: PageBody(
        children: [
          MetricRow(
            children: [
              MetricCallout(
                icon: online == true
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined,
                label: 'Sync Backend',
                value: switch (online) {
                  true => 'Online',
                  false => 'Offline',
                  null => 'Checking…',
                },
                color: online == true ? NotionColors.green : NotionColors.red,
                bgColor:
                    online == true ? NotionColors.greenBg : NotionColors.redBg,
              ),
              MetricCallout(
                icon: Icons.local_fire_department_outlined,
                label: 'Current Streak',
                value: stats == null ? '—' : '${stats.currentStreak} days',
                color: NotionColors.orange,
                bgColor: NotionColors.orangeBg,
              ),
              MetricCallout(
                icon: Icons.check_circle_outline,
                label: 'Quests Completed',
                value: stats == null ? '—' : '${stats.totalCompleted}',
                color: NotionColors.purple,
                bgColor: NotionColors.purpleBg,
              ),
            ],
          ),
          const SizedBox(height: 20),
          const NotionSectionTitle(
              icon: Icons.person_outline, title: 'Character'),
          NotionCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row('Name', player.name),
                _row('Class', player.playerClass.label),
                _row('Level', '${player.level}'),
                _row('XP (this level)', '${player.xp} / ${player.xpToNext}'),
                _row('Total XP (local)', '${player.totalXp}'),
                if (stats != null) ...[
                  _row('Total XP (server)', '${stats.experiencePoints}'),
                  _row('Longest streak', '${stats.longestStreak} days'),
                  _row('Streak freezes', '${stats.streakFreezes}'),
                ],
                _row('XP today', '${player.xpToday}'),
                _row('Tasks today', '${player.tasksToday}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const NotionSectionTitle(
              icon: Icons.link_outlined, title: 'Integrations'),
          NotionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _integrationRow(
                  'Todoist',
                  connected: integrations?.todoist.connected ?? false,
                  lastSyncAt: integrations?.todoist.lastSyncAt,
                ),
                const Divider(height: 1),
                _integrationRow(
                  'Google Calendar',
                  connected: integrations?.calendar.connected ?? false,
                  lastSyncAt: integrations?.calendar.lastSyncAt,
                ),
                const Divider(height: 1),
                _integrationRow(
                  'Strava',
                  connected: integrations?.strava.connected ?? false,
                  lastSyncAt: integrations?.strava.lastSyncAt,
                  note: integrations?.stravaConfigured == false
                      ? 'server not configured'
                      : null,
                ),
                const Divider(height: 1),
                _integrationRow(
                  'Plaid (bank)',
                  connected: integrations?.plaid.connected ?? false,
                  lastSyncAt: integrations?.plaid.lastSyncAt,
                  note: integrations?.plaidConfigured == false
                      ? 'server not configured'
                      : null,
                ),
                const Divider(height: 1),
                _integrationRow(
                  'AI (Claude)',
                  connected: integrations?.aiConfigured ?? false,
                  connectedLabel: 'Configured',
                  disconnectedLabel: 'Not configured',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime? t) {
    if (t == null) return '';
    final delta = DateTime.now().difference(t.toLocal());
    if (delta.inMinutes < 1) return 'synced just now';
    if (delta.inHours < 1) return 'synced ${delta.inMinutes}m ago';
    if (delta.inDays < 1) return 'synced ${delta.inHours}h ago';
    return 'synced ${delta.inDays}d ago';
  }

  static Widget _row(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
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

  static Widget _integrationRow(
    String name, {
    required bool connected,
    DateTime? lastSyncAt,
    String? note,
    String connectedLabel = 'Connected',
    String disconnectedLabel = 'Not connected',
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
          if (connected && lastSyncAt != null) ...[
            Text(_ago(lastSyncAt),
                style: const TextStyle(
                    fontSize: 11, color: NotionColors.textFaint)),
            const SizedBox(width: 8),
          ],
          if (note != null) ...[
            Text(note,
                style: const TextStyle(
                    fontSize: 11, color: NotionColors.textFaint)),
            const SizedBox(width: 8),
          ],
          NotionTag(
            text: connected ? connectedLabel : disconnectedLabel,
            color: connected ? NotionColors.green : NotionColors.textMuted,
            bgColor:
                connected ? NotionColors.greenBg : NotionColors.surfaceHover,
          ),
        ],
      ),
    );
  }
}
