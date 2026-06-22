import 'package:flutter/material.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedule')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Today'),
            _buildTimelineItem('09:00 AM', 'Deep Work Session', Colors.purple),
            _buildTimelineItem('10:30 AM', 'Sync Meeting', Colors.blue),
            _buildTimelineItem('01:00 PM', 'Lunch Break', Colors.orange),
            _buildTimelineItem('03:00 PM', 'Workout', Colors.green),
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
