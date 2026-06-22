import 'package:flutter/material.dart';
import 'package:life_achiever/shared/widgets/section_header.dart';
import 'package:life_achiever/shared/widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Responsive grid crossAxisCount
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    if (screenWidth > 1200) crossAxisCount = 4;
    else if (screenWidth > 800) crossAxisCount = 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'Overview'),
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.5,
              children: const [
                StatCard(
                  title: 'Daily Steps',
                  value: '8,432',
                  icon: Icons.directions_walk,
                  color: Colors.greenAccent,
                ),
                StatCard(
                  title: 'Calories',
                  value: '1,850 kcal',
                  icon: Icons.local_fire_department,
                  color: Colors.orangeAccent,
                ),
                StatCard(
                  title: 'Spent Today',
                  value: '\$45.00',
                  icon: Icons.attach_money,
                  color: Colors.blueAccent,
                ),
                StatCard(
                  title: 'Active Quests',
                  value: '3',
                  icon: Icons.flag,
                  color: Colors.purpleAccent,
                ),
              ],
            ),
            const SizedBox(height: 32),
            const SectionHeader(title: 'Upcoming Schedule'),
            // Placeholder for schedule list
            Card(
              child: ListTile(
                leading: const Icon(Icons.event, color: Colors.blue),
                title: const Text('Team Meeting'),
                subtitle: const Text('10:00 AM - 11:30 AM'),
                trailing: const Text('In 45 mins', style: TextStyle(color: Colors.grey)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
