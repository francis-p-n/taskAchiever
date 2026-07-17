import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/data/integrations_repository.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/schedule/data/schedule_repository.dart';
import 'package:life_os/shared/widgets/connect_dialog.dart';
import 'package:life_os/shared/widgets/integration_card.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

/// Result of the add-event dialog.
typedef _NewEvent = ({String title, TimeOfDay start, int durationMinutes});

String _formatTime(DateTime t) {
  final local = t.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(todayScheduleProvider);
    ref.invalidate(integrationsStatusProvider);
  }

  void _showResult(BuildContext context, WidgetRef ref, IntegrationResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.message)),
    );
    _refreshAll(ref);
  }

  Future<void> _connectCalendar(BuildContext context, WidgetRef ref) async {
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

  Future<void> _syncCalendar(BuildContext context, WidgetRef ref) async {
    final result =
        await ref.read(integrationsRepositoryProvider).syncCalendar();
    if (!context.mounted) return;
    _showResult(context, ref, result);
  }

  Future<void> _disconnectCalendar(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: NotionColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: NotionColors.border),
        ),
        title: const Text('Disconnect calendar?', style: TextStyle(fontSize: 16)),
        content: const Text(
          'Synced calendar events will be removed from your schedule.',
          style: TextStyle(fontSize: 12, color: NotionColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: NotionColors.textMuted, fontSize: 13),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NotionColors.redBg,
              foregroundColor: NotionColors.red,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Disconnect', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result =
        await ref.read(integrationsRepositoryProvider).disconnectCalendar();
    if (!context.mounted) return;
    _showResult(context, ref, result);
  }

  Future<void> _addEvent(BuildContext context, WidgetRef ref) async {
    final input = await showDialog<_NewEvent>(
      context: context,
      builder: (context) => const _AddEventDialog(),
    );
    if (input == null || !context.mounted) return;
    final now = DateTime.now();
    final start = DateTime(
        now.year, now.month, now.day, input.start.hour, input.start.minute);
    final end = start.add(Duration(minutes: input.durationMinutes));
    final ok = await ref.read(scheduleRepositoryProvider).createEvent(
          title: input.title,
          startTime: start,
          endTime: end,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Added "${input.title}" at ${_formatTime(start)}'
            : 'Could not add event — backend offline'),
      ),
    );
    if (ok) ref.invalidate(todayScheduleProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(todayScheduleProvider);
    final statusAsync = ref.watch(integrationsStatusProvider);
    final calendar = statusAsync.valueOrNull?.calendar;
    final connected = calendar?.connected ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_outlined, size: 18),
            onPressed: () => _refreshAll(ref),
          ),
        ],
      ),
      body: PageBody(
        children: [
          NotionSectionTitle(
            icon: Icons.calendar_today_outlined,
            title: 'Today',
            trailing: TextButton.icon(
              onPressed: () => _addEvent(context, ref),
              style: TextButton.styleFrom(
                foregroundColor: NotionColors.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add', style: TextStyle(fontSize: 12)),
            ),
          ),
          NotionCard(
            child: scheduleAsync.when(
              data: (events) => events.isEmpty
                  ? const _EmptySchedule()
                  : Column(
                      children: [
                        for (final event in events) _TimelineItem(event: event),
                      ],
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              // Repository already swallows network errors; never crash here.
              error: (_, _) => const _EmptySchedule(),
            ),
          ),
          const SizedBox(height: 24),
          const NotionSectionTitle(
              icon: Icons.link_outlined, title: 'Integrations'),
          IntegrationCard(
            icon: Icons.event_outlined,
            name: 'Google Calendar',
            description:
                'Sync your calendar so scheduled blocks show up as timed quests.',
            connected: connected,
            lastSyncAt: calendar?.lastSyncAt,
            preview: connected
                ? const []
                : const [
                    IntegrationPreviewRow(
                      leading: '10:00 AM',
                      title: 'Team Meeting',
                      trailingText: 'Work',
                      trailingColor: NotionColors.blue,
                      trailingBg: NotionColors.blueBg,
                    ),
                    IntegrationPreviewRow(
                      leading: '1:00 PM',
                      title: 'Lunch with Sam',
                      trailingText: 'Personal',
                      trailingColor: NotionColors.purple,
                      trailingBg: NotionColors.purpleBg,
                    ),
                    IntegrationPreviewRow(
                      leading: '6:30 PM',
                      title: 'Gym — Push Day',
                      trailingText: 'Fitness',
                      trailingColor: NotionColors.green,
                      trailingBg: NotionColors.greenBg,
                    ),
                  ],
            onConnect: () => _connectCalendar(context, ref),
            onSync: () => _syncCalendar(context, ref),
            onDisconnect: () => _disconnectCalendar(context, ref),
          ),
        ],
      ),
    );
  }
}

class _EmptySchedule extends StatelessWidget {
  const _EmptySchedule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        'No events scheduled for today.',
        style: TextStyle(fontSize: 12, color: NotionColors.textMuted),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final ScheduleEventDto event;

  const _TimelineItem({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              _formatTime(event.startTime),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: NotionColors.textMuted,
              ),
            ),
          ),
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: NotionColors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
            margin: const EdgeInsets.only(right: 12),
          ),
          Expanded(
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          if (event.isGoogleEvent)
            const NotionTag(
              text: 'Cal',
              color: NotionColors.blue,
              bgColor: NotionColors.blueBg,
            ),
        ],
      ),
    );
  }
}

/// Notion-styled dialog: title + start time (today) + duration.
class _AddEventDialog extends StatefulWidget {
  const _AddEventDialog();

  @override
  State<_AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<_AddEventDialog> {
  final _titleController = TextEditingController();
  TimeOfDay _start = TimeOfDay.now();
  int _durationMinutes = 60;

  static const _durations = <int, String>{
    30: '30 minutes',
    60: '1 hour',
    120: '2 hours',
  };

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _start);
    if (picked != null) setState(() => _start = picked);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop<_NewEvent>(
      (title: title, start: _start, durationMinutes: _durationMinutes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startLabel = _formatTime(
        DateTime(now.year, now.month, now.day, _start.hour, _start.minute));

    return AlertDialog(
      backgroundColor: NotionColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: NotionColors.border),
      ),
      title: const Text('Add event', style: TextStyle(fontSize: 16)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle:
                    TextStyle(fontSize: 12, color: NotionColors.textMuted),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: NotionColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: NotionColors.textMuted),
                ),
                isDense: true,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: NotionColors.textPrimary,
                      side: const BorderSide(color: NotionColors.border),
                    ),
                    icon: const Icon(Icons.schedule_outlined, size: 14),
                    label: Text(startLabel,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _durationMinutes,
                    style: const TextStyle(
                        fontSize: 12, color: NotionColors.textPrimary),
                    dropdownColor: NotionColors.surfaceHover,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      labelStyle: TextStyle(
                          fontSize: 12, color: NotionColors.textMuted),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: NotionColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: NotionColors.textMuted),
                      ),
                      isDense: true,
                    ),
                    items: [
                      for (final entry in _durations.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _durationMinutes = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: NotionColors.textMuted, fontSize: 13),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: NotionColors.surfaceHover,
            foregroundColor: NotionColors.textPrimary,
          ),
          onPressed: _submit,
          child: const Text('Add', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
