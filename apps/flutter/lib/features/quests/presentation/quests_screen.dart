import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/providers.dart';
import 'package:life_achiever/core/theme.dart';
import 'package:life_achiever/features/player/application/player_notifier.dart';
import 'package:life_achiever/features/player/domain/player.dart';
import 'package:life_achiever/shared/widgets/integration_card.dart';
import 'package:life_achiever/shared/widgets/notion_card.dart';

class _QuestEntry {
  final String title;
  final String time;
  final Area area;
  final int xp;
  bool completed = false;

  _QuestEntry({
    required this.title,
    required this.time,
    required this.area,
    required this.xp,
  });
}

// Mock daily quests until the Isar-backed quest list is wired in.
final _questsProvider = StateProvider<List<_QuestEntry>>((ref) => [
      _QuestEntry(
          title: 'Ginger Tea', time: '7:00 AM', area: Area.care, xp: 5),
      _QuestEntry(
          title: 'Morning Workout',
          time: '8:00 AM',
          area: Area.physical,
          xp: 10),
      _QuestEntry(
          title: 'Play Rafayel Sea God Myth',
          time: '7:30 PM',
          area: Area.psyche,
          xp: 5),
      _QuestEntry(
          title: 'Read ORV', time: '9:00 PM', area: Area.intel, xp: 10),
      _QuestEntry(
          title: 'Practice Session',
          time: '5:00 PM',
          area: Area.intel,
          xp: 15),
      _QuestEntry(
          title: 'Evening Meditation',
          time: '10:00 PM',
          area: Area.spiritual,
          xp: 5),
    ]);

final _tabProvider = StateProvider<int>((ref) => 0);

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  static const _tabs = ['Today', 'Available Tasks', 'Completed'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(_questsProvider);
    final tab = ref.watch(_tabProvider);

    final visible = switch (tab) {
      2 => quests.where((q) => q.completed).toList(),
      _ => quests.where((q) => !q.completed).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚔️  Quests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, size: 18),
            tooltip: 'Sync Quests',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data...')),
              );

              final ok =
                  await ref.read(syncEngineProvider).pullUpdates();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Sync complete!'
                        : 'Backend offline — using local data'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () =>
                          ref.read(_tabProvider.notifier).state = i,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: tab == i
                              ? NotionColors.surfaceHover
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: tab == i
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: tab == i
                                ? NotionColors.textPrimary
                                : NotionColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text('Nothing here yet',
                      style: TextStyle(
                          color: NotionColors.textFaint, fontSize: 13)),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio:
                      MediaQuery.of(context).size.width > 600 ? 1.7 : 2.2,
                ),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final quest = visible[index];
                  return _QuestCard(
                    quest: quest,
                    onComplete: () => _completeQuest(context, ref, quest),
                  );
                },
              ),
            const SizedBox(height: 24),
            const NotionSectionTitle(emoji: '🧩', title: 'Side Quests'),
            const IntegrationCard(
              emoji: '✅',
              name: 'Todoist',
              description:
                  'Pull your Todoist tasks in as side quests — complete them to earn bonus XP.',
              preview: [
                IntegrationPreviewRow(
                  leading: 'Today',
                  title: 'Reply to landlord email',
                  trailingText: '+5 XP',
                  trailingColor: NotionColors.green,
                  trailingBg: NotionColors.greenBg,
                ),
                IntegrationPreviewRow(
                  leading: 'Today',
                  title: 'Buy groceries',
                  trailingText: '+5 XP',
                  trailingColor: NotionColors.green,
                  trailingBg: NotionColors.greenBg,
                ),
                IntegrationPreviewRow(
                  leading: 'Tomorrow',
                  title: 'Renew gym membership',
                  trailingText: '+10 XP',
                  trailingColor: NotionColors.green,
                  trailingBg: NotionColors.greenBg,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _completeQuest(
      BuildContext context, WidgetRef ref, _QuestEntry quest) {
    if (quest.completed) return;

    quest.completed = true;
    ref.read(_questsProvider.notifier).state =
        List.of(ref.read(_questsProvider));

    final result =
        ref.read(playerProvider.notifier).gainXp(quest.xp, area: quest.area);

    if (result.leveledUp) {
      showDialog(
        context: context,
        builder: (_) => _LevelUpDialog(newLevel: result.newLevel),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${quest.title} complete  +${result.xpGained} XP  •  ${quest.area.label}'),
        ),
      );
    }
  }
}

class _QuestCard extends StatelessWidget {
  final _QuestEntry quest;
  final VoidCallback onComplete;

  const _QuestCard({required this.quest, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return NotionCard(
      color: quest.completed
          ? NotionColors.surface
          : NotionColors.purpleBg.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quest.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration:
                      quest.completed ? TextDecoration.lineThrough : null,
                  color: quest.completed
                      ? NotionColors.textFaint
                      : NotionColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                quest.time,
                style: const TextStyle(
                    fontSize: 11, color: NotionColors.textMuted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  NotionTag(
                    text: quest.area.label,
                    color: NotionColors.purple,
                    bgColor: NotionColors.purpleBg,
                  ),
                  const SizedBox(width: 6),
                  NotionTag(
                    text: '+${quest.xp} XP',
                    color: NotionColors.green,
                    bgColor: NotionColors.greenBg,
                  ),
                ],
              ),
            ],
          ),
          if (!quest.completed)
            SizedBox(
              height: 26,
              child: OutlinedButton(
                onPressed: onComplete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: NotionColors.textMuted,
                  side: const BorderSide(color: NotionColors.border),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('Complete', style: TextStyle(fontSize: 11)),
              ),
            )
          else
            const Text('✓ Done',
                style:
                    TextStyle(fontSize: 11, color: NotionColors.green)),
        ],
      ),
    );
  }
}

class _LevelUpDialog extends StatelessWidget {
  final int newLevel;

  const _LevelUpDialog({required this.newLevel});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NotionColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: NotionColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'Level Up!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'You reached Level $newLevel',
              style: const TextStyle(
                  fontSize: 13, color: NotionColors.textMuted),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: NotionColors.textPrimary,
                side: const BorderSide(color: NotionColors.border),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Continue', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
