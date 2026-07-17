import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/achievements/data/achievements_repository.dart';
import 'package:life_os/features/achievements/domain/achievement.dart';
import 'package:life_os/shared/widgets/metric_callout.dart';
import 'package:life_os/shared/widgets/notion_card.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_outlined, size: 18),
            onPressed: () => ref.invalidate(achievementsProvider),
          ),
        ],
      ),
      body: achievements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const _Unavailable(),
        data: (list) {
          if (list == null) return const _Unavailable();
          final unlockedCount = list.where((a) => a.unlocked).length;
          return PageBody(
            children: [
              MetricCallout(
                icon: Icons.emoji_events_outlined,
                label: 'Unlocked',
                value: '$unlockedCount / ${list.length}',
                color: NotionColors.yellow,
                bgColor: NotionColors.yellowBg,
                progress: list.isEmpty ? 0 : unlockedCount / list.length,
              ),
              const SizedBox(height: 16),
              for (final category in AchievementCategory.values)
                _CategorySection(
                  category: category,
                  achievements:
                      list.where((a) => a.category == category).toList(),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Achievements need a connection to the sync backend.',
        style: TextStyle(color: NotionColors.textMuted),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final AchievementCategory category;
  final List<Achievement> achievements;

  const _CategorySection({required this.category, required this.achievements});

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NotionSectionTitle(
            icon: Icons.folder_outlined,
            title: category.label,
          ),
          for (final achievement in achievements) ...[
            _AchievementTile(achievement: achievement),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;

  const _AchievementTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final locked = !achievement.unlocked;
    return Opacity(
      opacity: locked ? 0.5 : 1,
      child: NotionCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: locked ? NotionColors.surfaceHover : NotionColors.yellowBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: locked ? NotionColors.border : NotionColors.yellow,
                  width: 0.5,
                ),
              ),
              child: Icon(
                locked ? Icons.lock_outline : achievement.iconData,
                size: 18,
                color: locked ? NotionColors.textFaint : NotionColors.yellow,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.title,
                    style: NotionType.display(size: 14, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    achievement.description,
                    style: NotionType.mono(size: 11, color: NotionColors.textMuted),
                  ),
                ],
              ),
            ),
            if (achievement.unlocked && achievement.unlockedAt != null)
              Text(
                '${achievement.unlockedAt!.toLocal()}'.split(' ').first,
                style: NotionType.mono(size: 10, color: NotionColors.textFaint),
              ),
          ],
        ),
      ),
    );
  }
}
