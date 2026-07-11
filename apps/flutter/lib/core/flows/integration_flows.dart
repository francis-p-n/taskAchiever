import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/data/integrations_repository.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';
import 'package:life_os/features/spending/data/spending_repository.dart';
import 'package:life_os/shared/widgets/connect_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// Opens the browser for Strava OAuth; the backend callback completes the
/// connection, so the user comes back and hits Sync (or waits for the cycle).
Future<void> connectStravaFlow(BuildContext context, WidgetRef ref) async {
  final url =
      await ref.read(integrationsRepositoryProvider).fetchStravaAuthUrl();
  if (!context.mounted) return;
  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Strava unavailable — backend offline or '
          'STRAVA_CLIENT_ID / STRAVA_CLIENT_SECRET not set.'),
    ));
    return;
  }
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    content: Text('Authorize in the browser, then come back and Sync.'),
  ));
}

/// Google Wallet has no read API: expenses arrive as a Takeout / bank CSV
/// picked from disk. Rows dedupe server-side, so re-imports are harmless.
Future<void> importWalletCsvFlow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
    dialogTitle: 'Import Google Wallet / bank CSV',
  );
  final path = picked?.files.single.path;
  if (path == null) return;

  messenger.showSnackBar(
    const SnackBar(content: Text('Importing transactions…')),
  );
  final csv = await File(path).readAsString();
  final result = await ref.read(spendingRepositoryProvider).importCsv(csv);

  ref.invalidate(recentSpendingProvider);
  ref.invalidate(spendingSummaryProvider);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(result == null
        ? 'Import failed — check the file has date and amount columns.'
        : 'Imported ${result.imported} transactions'
            '${result.skipped > 0 ? ', ${result.skipped} already known' : ''}'
            '${result.failed > 0 ? ', ${result.failed} unreadable rows' : ''}.'),
  ));
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
