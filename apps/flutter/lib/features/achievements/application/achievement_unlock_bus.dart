import 'package:flutter/foundation.dart';
import 'package:life_os/features/achievements/domain/achievement.dart';

/// Fan-in point for "newlyUnlocked" achievements returned by any write
/// endpoint (quest complete, fitness/food/spending logs). Repositories push
/// here directly — no need to thread Riverpod's ref through every notifier
/// just to raise a toast. MainLayout listens and drains the queue.
class AchievementUnlockBus {
  AchievementUnlockBus._();

  static final ValueNotifier<List<Achievement>> unlocks = ValueNotifier([]);

  static void publish(Object? rawNewlyUnlocked) {
    if (rawNewlyUnlocked is! List || rawNewlyUnlocked.isEmpty) return;
    final achievements = [
      for (final item in rawNewlyUnlocked)
        if (item is Map<String, dynamic>) Achievement.fromJson(item),
    ];
    if (achievements.isEmpty) return;
    unlocks.value = [...unlocks.value, ...achievements];
  }

  /// Pops the queue after the listener has shown them.
  static void drain(int count) {
    if (count >= unlocks.value.length) {
      unlocks.value = [];
    } else {
      unlocks.value = unlocks.value.sublist(count);
    }
  }
}
