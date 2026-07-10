import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/features/player/domain/player.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _completionsPrefsKey = 'quest_completions_v1';

class QuestEntry {
  final String title;
  final String time;
  final Area area;
  final int xp;
  final String? remoteId; // set when the quest lives in the backend DB
  final bool isSideQuest;
  final bool completed;

  const QuestEntry({
    required this.title,
    required this.time,
    required this.area,
    required this.xp,
    this.remoteId,
    this.isSideQuest = false,
    this.completed = false,
  });

  /// Stable key for persisting local completion state across restarts.
  String get key => remoteId ?? 'local:$title';

  QuestEntry copyWith({bool? completed}) => QuestEntry(
        title: title,
        time: time,
        area: area,
        xp: xp,
        remoteId: remoteId,
        isSideQuest: isSideQuest,
        completed: completed ?? this.completed,
      );

  static String formatTime(DateTime? dt) {
    if (dt == null) return 'Anytime';
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  factory QuestEntry.fromDto(QuestDto dto) => QuestEntry(
        title: dto.title,
        time: formatTime(dto.dueDate),
        area: dto.area,
        xp: dto.xp,
        remoteId: dto.id,
        isSideQuest: dto.category == 'side',
        completed: dto.completedAt != null,
      );
}

List<QuestEntry> _fallbackQuests() => const [
      QuestEntry(title: 'Ginger Tea', time: '7:00 AM', area: Area.care, xp: 5),
      QuestEntry(
          title: 'Morning Workout',
          time: '8:00 AM',
          area: Area.physical,
          xp: 10),
      QuestEntry(
          title: 'Play Rafayel Sea God Myth',
          time: '7:30 PM',
          area: Area.psyche,
          xp: 5),
      QuestEntry(title: 'Read ORV', time: '9:00 PM', area: Area.intel, xp: 10),
      QuestEntry(
          title: 'Practice Session',
          time: '5:00 PM',
          area: Area.intel,
          xp: 15),
      QuestEntry(
          title: 'Evening Meditation',
          time: '10:00 PM',
          area: Area.spiritual,
          xp: 5),
    ];

/// Owns the quest list shown on the Quests screen and dashboard.
/// Completions are persisted per-day locally (for the offline fallback
/// quests) and to the backend when the quest has a remote id.
class QuestsNotifier extends StateNotifier<List<QuestEntry>> {
  QuestsNotifier(this._repository, List<QuestEntry> seed) : super(seed) {
    _applyStoredCompletions();
  }

  final QuestsRepository _repository;

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _applyStoredCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_completionsPrefsKey);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (map['date'] != _today()) return; // stale — completions reset daily
    final keys = (map['keys'] as List).cast<String>().toSet();
    if (!mounted || keys.isEmpty) return;
    state = [
      for (final q in state)
        keys.contains(q.key) ? q.copyWith(completed: true) : q,
    ];
  }

  Future<void> _storeCompletions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _completionsPrefsKey,
      jsonEncode({
        'date': _today(),
        'keys': [for (final q in state.where((q) => q.completed)) q.key],
      }),
    );
  }

  /// Marks [quest] complete locally and on the backend. Returns false if it
  /// was already completed.
  bool complete(QuestEntry quest) {
    final index = state.indexWhere((q) => q.key == quest.key);
    if (index == -1 || state[index].completed) return false;

    state = [
      for (final q in state)
        q.key == quest.key ? q.copyWith(completed: true) : q,
    ];
    _storeCompletions();

    // Persist completion to the backend (awards XP/streak in user_stats).
    if (quest.remoteId != null) {
      _repository.completeQuest(quest.remoteId!);
    }
    return true;
  }

  /// Reverts a completion (the Undo button). Returns false if it wasn't
  /// completed.
  bool uncomplete(QuestEntry quest) {
    final index = state.indexWhere((q) => q.key == quest.key);
    if (index == -1 || !state[index].completed) return false;

    state = [
      for (final q in state)
        q.key == quest.key ? q.copyWith(completed: false) : q,
    ];
    _storeCompletions();

    if (quest.remoteId != null) {
      _repository.uncompleteQuest(quest.remoteId!);
    }
    return true;
  }
}

/// Seeded from the backend quest list; falls back to the offline mock
/// entries until (or unless) the fetch resolves. Watching the remote
/// provider here means the seed is correct regardless of whether the
/// fetch settles before or after the first screen build.
final questsProvider =
    StateNotifierProvider<QuestsNotifier, List<QuestEntry>>((ref) {
  final remote = ref.watch(remoteQuestsProvider).valueOrNull;
  final seed = (remote != null && remote.isNotEmpty)
      ? remote.map(QuestEntry.fromDto).toList()
      : _fallbackQuests();
  return QuestsNotifier(ref.watch(questsRepositoryProvider), seed);
});
