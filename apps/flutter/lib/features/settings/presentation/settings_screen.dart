import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/data/integrations_repository.dart';
import 'package:life_os/core/flows/integration_flows.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/application/player_notifier.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';
import 'package:life_os/features/settings/presentation/edit_player_dialog.dart';
import 'package:life_os/shared/widgets/integration_card.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showResult(
      BuildContext context, WidgetRef ref, IntegrationResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    ref.invalidate(integrationsStatusProvider);
    ref.invalidate(remoteQuestsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final status = ref.watch(integrationsStatusProvider).valueOrNull;
    final repo = ref.read(integrationsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          const NotionSectionTitle(
              icon: Icons.badge_outlined, title: 'Player'),
          NotionCard(
            padding: const EdgeInsets.all(16),
            child: Row(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(player.name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                        '${player.job} · Age ${player.age} · Level ${player.level}',
                        style: const TextStyle(
                            fontSize: 12, color: NotionColors.textMuted),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => const EditPlayerDialog(),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NotionColors.textPrimary,
                      side: const BorderSide(color: NotionColors.border),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit Player ID',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const NotionSectionTitle(
              icon: Icons.link_outlined, title: 'Integrations'),
          IntegrationCard(
            icon: Icons.check_circle_outline,
            name: 'Todoist',
            description:
                'Import your Todoist tasks as side quests and close them '
                'there when you complete them here.',
            connected: status?.todoist.connected ?? false,
            lastSyncAt: status?.todoist.lastSyncAt,
            onConnect: () => connectTodoistFlow(context, ref),
            onSync: () async {
              final result = await repo.syncTodoist();
              if (context.mounted) _showResult(context, ref, result);
            },
            onDisconnect: () async {
              final result = await repo.disconnectTodoist();
              if (context.mounted) _showResult(context, ref, result);
            },
          ),
          const SizedBox(height: 12),
          IntegrationCard(
            icon: Icons.event_outlined,
            name: 'Google Calendar',
            description:
                'Sync your calendar so scheduled blocks show up in Schedule '
                'and the dashboard.',
            connected: status?.calendar.connected ?? false,
            lastSyncAt: status?.calendar.lastSyncAt,
            onConnect: () => connectCalendarFlow(context, ref),
            onSync: () async {
              final result = await repo.syncCalendar();
              if (context.mounted) _showResult(context, ref, result);
            },
            onDisconnect: () async {
              final result = await repo.disconnectCalendar();
              if (context.mounted) _showResult(context, ref, result);
            },
          ),
        ],
      ),
    );
  }
}
