import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/data/integrations_repository.dart';
import 'package:life_os/core/flows/integration_flows.dart';
import 'package:life_os/core/network/api_client.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/fitness/data/health_sync.dart';
import 'package:life_os/features/player/application/player_notifier.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';
import 'package:life_os/features/settings/presentation/edit_player_dialog.dart';
import 'package:life_os/shared/widgets/connect_dialog.dart';
import 'package:life_os/shared/widgets/integration_card.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
              icon: Icons.dns_outlined, title: 'Server'),
          _UtilityIntegrationRow(
            icon: Icons.cloud_outlined,
            name: 'Backend',
            description: ref.watch(backendUrlProvider) +
                '\nOn a phone, point this at your PC '
                    '(http://<pc-ip>:3000/api) or a hosted backend — the '
                    'same account syncs across every device.',
            actionLabel: 'Change',
            onAction: () async {
              final url = await showConnectDialog(
                context,
                title: 'Backend URL',
                fieldLabel: 'http(s)://host:port/api',
                helpText: 'Where the lifeOS backend lives. Desktop default '
                    'is http://127.0.0.1:3000/api. From a phone, use your '
                    "PC's LAN IP or a hosted URL.",
              );
              if (url == null || url.trim().isEmpty || !context.mounted) {
                return;
              }
              final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
              await ref.read(backendUrlProvider.notifier).set(trimmed);
              ref.invalidate(integrationsStatusProvider);
              ref.invalidate(remoteQuestsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Backend set to $trimmed')),
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _UtilityIntegrationRow(
            icon: Icons.key_outlined,
            name: 'Access code',
            description:
                'Required by hosted backends (AUTH_ACCESS_CODE) so only you '
                'can sign in. Leave unset for a local backend.',
            actionLabel: 'Set',
            onAction: () async {
              final code = await showConnectDialog(
                context,
                title: 'Access code',
                fieldLabel: 'Access code',
                obscure: true,
                helpText: 'The AUTH_ACCESS_CODE value configured on your '
                    'deployed backend.',
              );
              if (code == null || !context.mounted) return;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(accessCodePrefsKey, code.trim());
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Access code saved.')),
                );
              }
            },
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
          const SizedBox(height: 12),
          IntegrationCard(
            icon: Icons.directions_run_outlined,
            name: 'Strava',
            description:
                'Pull in workouts automatically. Overlapping activities from '
                'other sources are deduped — Strava wins.',
            connected: status?.strava.connected ?? false,
            lastSyncAt: status?.strava.lastSyncAt,
            onConnect: () => connectStravaFlow(context, ref),
            onSync: () async {
              final result = await repo.syncStrava();
              if (context.mounted) _showResult(context, ref, result);
            },
            onDisconnect: () async {
              final result = await repo.disconnectStrava();
              if (context.mounted) _showResult(context, ref, result);
            },
          ),
          const SizedBox(height: 12),
          _UtilityIntegrationRow(
            icon: Icons.monitor_heart_outlined,
            name: 'Health Connect',
            description:
                'Steps, heart rate and workouts from your watch, via the '
                'Android Health Connect app.',
            actionLabel: 'Sync now',
            onAction: () async {
              final message =
                  await ref.read(healthSyncProvider).syncToday();
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(message)));
              }
            },
          ),
          const SizedBox(height: 12),
          _UtilityIntegrationRow(
            icon: Icons.account_balance_wallet_outlined,
            name: 'Google Wallet / bank CSV',
            description:
                'Import expenses from a Google Takeout (Google Pay) export '
                'or any bank statement CSV. Safe to re-import.',
            actionLabel: 'Import CSV',
            onAction: () => importWalletCsvFlow(context, ref),
          ),
          const SizedBox(height: 12),
          _UtilityIntegrationRow(
            icon: Icons.auto_awesome_outlined,
            name: 'Claude AI',
            description: (status?.aiConfigured ?? false)
                ? 'Powering meal photo analysis, quest steps, difficulty '
                    'ratings and side-quest ideas.'
                : 'Set ANTHROPIC_API_KEY on the backend to enable meal '
                    'photos, quest steps, difficulty and suggestions.',
            statusTag: (status?.aiConfigured ?? false) ? 'Active' : 'Off',
            statusOk: status?.aiConfigured ?? false,
          ),
        ],
      ),
    );
  }
}

/// Compact hub row for integrations that don't follow the connect/disconnect
/// pattern (device sync, file import, server-side config).
class _UtilityIntegrationRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? statusTag;
  final bool statusOk;

  const _UtilityIntegrationRow({
    required this.icon,
    required this.name,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.statusTag,
    this.statusOk = false,
  });

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: NotionColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    if (statusTag != null) ...[
                      const SizedBox(width: 8),
                      NotionTag(
                        text: statusTag!,
                        color: statusOk
                            ? NotionColors.green
                            : NotionColors.textFaint,
                        bgColor: statusOk
                            ? NotionColors.greenBg
                            : NotionColors.surfaceHover,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: NotionColors.textMuted)),
              ],
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 28,
              child: OutlinedButton(
                onPressed: onAction,
                child:
                    Text(actionLabel!, style: const TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
