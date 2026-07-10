import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/data/integrations_repository.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';
import 'package:life_os/shared/widgets/connect_dialog.dart';

/// Shared connect/sync flows so Settings, Quests and Schedule all drive the
/// same integrations without duplicating the dialogs.

void _showResult(BuildContext context, WidgetRef ref, IntegrationResult result) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(result.message)),
  );
  ref.invalidate(integrationsStatusProvider);
  ref.invalidate(remoteQuestsProvider);
}

Future<void> connectTodoistFlow(BuildContext context, WidgetRef ref) async {
  final apiKey = await showConnectDialog(
    context,
    title: 'Connect Todoist',
    fieldLabel: 'API token',
    obscure: true,
    helpText: 'Todoist → Settings → Integrations → Developer → copy your '
        'API token. Tasks in your "Sidequest" project become side quests '
        'automatically; leave the project blank to import everything.',
  );
  if (apiKey == null || !context.mounted) return;

  final project = await showConnectDialog(
    context,
    title: 'Which project?',
    fieldLabel: 'Project name (optional — Cancel for all)',
    helpText: 'Type the name of the Todoist project to import from, e.g. '
        '"Sidequest". Cancel to import from every project.',
  );
  if (!context.mounted) return;

  final result = await ref
      .read(integrationsRepositoryProvider)
      .connectTodoist(apiKey, projectName: project);
  if (!context.mounted) return;
  _showResult(context, ref, result);
}

Future<void> syncTodoistFlow(BuildContext context, WidgetRef ref) async {
  final result = await ref.read(integrationsRepositoryProvider).syncTodoist();
  if (!context.mounted) return;
  _showResult(context, ref, result);
}

Future<void> disconnectTodoistFlow(BuildContext context, WidgetRef ref) async {
  final result =
      await ref.read(integrationsRepositoryProvider).disconnectTodoist();
  if (!context.mounted) return;
  _showResult(context, ref, result);
}

Future<void> connectCalendarFlow(BuildContext context, WidgetRef ref) async {
  final url = await showConnectDialog(
    context,
    title: 'Connect your calendar',
    fieldLabel: 'Secret iCal URL',
    helpText:
        'Google Calendar → Settings → your calendar → Integrate calendar → '
        'copy the "Secret address in iCal format" URL. Works with any iCal '
        'feed (Outlook, Apple).',
  );
  if (url == null || !context.mounted) return;
  final result =
      await ref.read(integrationsRepositoryProvider).connectCalendar(url);
  if (!context.mounted) return;
  _showResult(context, ref, result);
}
