import 'package:flutter/material.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/life/presentation/checkin_tab.dart';
import 'package:life_os/features/life/presentation/habits_tab.dart';
import 'package:life_os/features/life/presentation/people_tab.dart';
import 'package:life_os/features/life/presentation/time_tab.dart';

/// The lifeOS v2 tracking hub: one screen hosting the granular life-tracking
/// domains (time, habits, people, wellness check-ins) as tabs so the main
/// navigation stays uncluttered.
class LifeScreen extends StatelessWidget {
  const LifeScreen({super.key});

  static const _tabs = <(String, IconData, Widget)>[
    ('Time', Icons.timer_outlined, TimeTab()),
    ('Habits', Icons.repeat, HabitsTab()),
    ('People', Icons.people_outline, PeopleTab()),
    ('Check-in', Icons.self_improvement, CheckinTab()),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Life'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: NotionColors.textPrimary,
            unselectedLabelColor: NotionColors.textFaint,
            indicatorColor: NotionColors.textPrimary,
            labelStyle:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: [
              for (final (label, icon, _) in _tabs)
                Tab(icon: Icon(icon, size: 16), text: label, height: 52),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final (_, _, tab) in _tabs) tab],
        ),
      ),
    );
  }
}
