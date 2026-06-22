import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';
import 'package:life_achiever/features/schedule/data/schedule_repository.dart';

class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleData = ref.watch(todayScheduleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: scheduleData.when(
        data: (events) => _buildContent(context, events),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<dynamic> events) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Today'),
          if (events.isEmpty)
            const Text('No events scheduled for today.')
          else
            ...events.map((event) => _buildTimelineItem(
                  event['startTime'] ?? 'Unknown',
                  event['title'] ?? 'Event',
                  Colors.blue,
                )),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.calendar_month),
              label: const Text('Connect Google Calendar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String time, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              time,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Container(
            width: 4,
            height: 40,
            color: color,
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
