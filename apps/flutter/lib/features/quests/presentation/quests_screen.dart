import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:life_os/core/providers.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/player/domain/player.dart';
import 'package:life_os/features/quests/application/quest_actions.dart';
import 'package:life_os/features/quests/application/quests_notifier.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';
import 'package:life_os/shared/widgets/integration_card.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

final _tabProvider = StateProvider<int>((ref) => 0);

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  static const _tabs = ['Today', 'Available Tasks', 'Completed'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questsProvider);
    final tab = ref.watch(_tabProvider);

    final main = quests.where((q) => !q.isSideQuest).toList();
    final side = quests.where((q) => q.isSideQuest).toList();

    final visible = switch (tab) {
      2 => main.where((q) => q.completed).toList(),
      _ => main.where((q) => !q.completed).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, size: 18),
            tooltip: 'Sync Quests',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data...')),
              );

              final ok = await ref.read(syncEngineProvider).pullUpdates();
              ref.invalidate(remoteQuestsProvider);

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
                  return QuestCard(
                    quest: quest,
                    onComplete: () => completeQuest(context, ref, quest),
                    onUndo: () => undoQuest(context, ref, quest),
                  );
                },
              ),
            const SizedBox(height: 24),
            const NotionSectionTitle(
                icon: Icons.extension_outlined, title: 'Side Quests'),
            if (side.isNotEmpty) ...[
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
                itemCount: side.length,
                itemBuilder: (context, index) {
                  final quest = side[index];
                  return QuestCard(
                    quest: quest,
                    onComplete: () => completeQuest(context, ref, quest),
                    onUndo: () => undoQuest(context, ref, quest),
                  );
                },
              ),
              const SizedBox(height: 12),
            ] else
              const IntegrationCard(
                icon: Icons.check_circle_outline,
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
}

class QuestCard extends StatelessWidget {
  final QuestEntry quest;
  final VoidCallback onComplete;
  final VoidCallback onUndo;

  const QuestCard({
    super.key,
    required this.quest,
    required this.onComplete,
    required this.onUndo,
  });

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
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: Lottie.asset(
                    'assets/lottie/success_check.json',
                    repeat: false,
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Done',
                    style:
                        TextStyle(fontSize: 11, color: NotionColors.green)),
                const Spacer(),
                SizedBox(
                  height: 26,
                  child: TextButton.icon(
                    onPressed: onUndo,
                    style: TextButton.styleFrom(
                      foregroundColor: NotionColors.textMuted,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.undo, size: 12),
                    label:
                        const Text('Undo', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
