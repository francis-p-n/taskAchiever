import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/theme.dart';
import 'package:life_achiever/features/schedule/data/schedule_repository.dart';
import 'package:life_achiever/shared/widgets/integration_card.dart';
import 'package:life_achiever/shared/widgets/notion_card.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleData = ref.watch(todayScheduleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('🗓️  Schedule')),
      body: scheduleData.when(
        data: (events) => _buildContent(context, events),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> events) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const NotionSectionTitle(emoji: '📅', title: 'Today'),
          NotionCard(
            child: events.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'No events scheduled for today.',
                      style: TextStyle(
                          fontSize: 12, color: NotionColors.textMuted),
                    ),
                  )
                : Column(
                    children: [
                      for (final event in events)
                        _TimelineItem(
                          time: event['startTime'] ?? 'Unknown',
                          title: event['title'] ?? 'Event',
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 24),
          const NotionSectionTitle(emoji: '🔗', title: 'Integrations'),
          const IntegrationCard(
            emoji: '📆',
            name: 'Google Calendar',
            description:
                'Sync your calendar so scheduled blocks show up as timed quests.',
            preview: [
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
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String time;
  final String title;

  const _TimelineItem({required this.time, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              time,
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
            child: Text(title, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
