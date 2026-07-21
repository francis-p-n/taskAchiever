import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';
import 'package:life_os/features/achievements/application/achievement_unlock_bus.dart';
import 'package:life_os/features/player/domain/player.dart';

class QuestDto {
  final String id;
  final String title;
  final String? category;
  final int difficulty;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? recurrence; // null | 'daily' | 'weekly'
  final List<String> steps; // actionable breakdown (AI-generated for imports)

  QuestDto({
    required this.id,
    required this.title,
    this.category,
    required this.difficulty,
    this.dueDate,
    this.completedAt,
    this.recurrence,
    this.steps = const [],
  });

  factory QuestDto.fromJson(Map<String, dynamic> json) => QuestDto(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String?,
        difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
        dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
        completedAt:
            json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
        recurrence: json['recurrence'] as String?,
        steps: [
          if (json['steps'] is List)
            for (final step in json['steps'] as List)
              if (step is Map<String, dynamic> && step['text'] != null)
                step['text'].toString(),
        ],
      );

  int get xp => difficulty * 10;

  Area get area => switch (category?.toLowerCase()) {
        'physical' || 'fitness' => Area.physical,
        'psyche' => Area.psyche,
        'spiritual' => Area.spiritual,
        'care' || 'test' => Area.care,
        _ => Area.intel,
      };
}

class QuestsRepository {
  final Dio _dio;
  QuestsRepository(this._dio);

  /// Returns the user's quests from the backend, or null when offline
  /// (local-first: callers fall back to local data).
  Future<List<QuestDto>?> fetchQuests() async {
    try {
      final response = await _dio.get('/quests');
      return (response.data as List)
          .map((q) => QuestDto.fromJson(q as Map<String, dynamic>))
          .toList();
    } on DioException {
      return null;
    }
  }

  Future<QuestDto?> createQuest({
    required String title,
    String? description,
    String? category,
    int difficulty = 1,
    DateTime? dueDate,
    String? recurrence,
  }) async {
    try {
      final response = await _dio.post('/quests', data: {
        'title': title,
        'description': description,
        'category': category,
        'difficulty': difficulty,
        'dueDate': dueDate?.toIso8601String(),
        'recurrence': ?recurrence,
      });
      return QuestDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  /// Marks a quest complete on the server (awards XP/streak in user_stats).
  Future<bool> completeQuest(String id, {int fulfillment = 3}) async {
    try {
      final response = await _dio.post('/quests/$id/complete', data: {'fulfillment': fulfillment});
      final data = response.data;
      if (data is Map<String, dynamic>) {
        AchievementUnlockBus.publish(data['newlyUnlocked']);
      }
      return true;
    } on DioException {
      return false;
    }
  }

  /// Attaches opt-in tracking tags to an already-completed quest. Returns
  /// the server's bonus XP, or null when offline / rejected (already tagged).
  Future<int?> tagQuest(
    String id, {
    int? durationMinutes,
    String? timeCategory,
    int? moodAfter,
    int? energyAfter,
    int? spendingCents,
    String? spendingCategory,
    int? contactId,
    String? interactionType,
  }) async {
    try {
      final response = await _dio.post('/quests/$id/tracking', data: {
        'durationMinutes': ?durationMinutes,
        'timeCategory': ?timeCategory,
        'moodAfter': ?moodAfter,
        'energyAfter': ?energyAfter,
        'spendingCents': ?spendingCents,
        'spendingCategory': ?spendingCategory,
        'contactId': ?contactId,
        'interactionType': ?interactionType,
      });
      return (response.data['bonusXp'] as num?)?.toInt();
    } on DioException {
      return null;
    }
  }

  /// Reverts a completion on the server (takes back the XP it awarded).
  Future<bool> uncompleteQuest(String id) async {
    try {
      await _dio.post('/quests/$id/uncomplete');
      return true;
    } on DioException {
      return false;
    }
  }

  /// Hides a quest from the active list, keeping it for history.
  Future<bool> archiveQuest(String id) async {
    try {
      await _dio.post('/quests/$id/archive');
      return true;
    } on DioException {
      return false;
    }
  }

  /// Permanently removes a quest and its steps.
  Future<bool> deleteQuest(String id) async {
    try {
      await _dio.delete('/quests/$id');
      return true;
    } on DioException {
      return false;
    }
  }

  /// Asks the AI to break the quest into actionable steps. Returns the
  /// refreshed quest, or null when offline / not found.
  Future<QuestDto?> generateSteps(String id) async {
    try {
      final response = await _dio.post(
        '/quests/$id/generate-steps',
        options: Options(
          // One Claude round-trip — the default 3s receive timeout is too slim.
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final quest = response.data['quest'];
      return quest is Map<String, dynamic> ? QuestDto.fromJson(quest) : null;
    } on DioException {
      return null;
    }
  }

  /// AI side-quest ideas; [focus] names the life area to lean toward.
  /// Null when the backend is unreachable (the server itself falls back to
  /// canned ideas when the AI is unconfigured, so null really means offline).
  Future<List<({String title, int difficulty})>?> suggestQuests(
      {String? focus}) async {
    try {
      final response = await _dio.post(
        '/ai/suggest-quests',
        data: {'focus': ?focus},
        options: Options(receiveTimeout: const Duration(seconds: 30)),
      );
      return [
        for (final item in (response.data['suggestions'] as List))
          (
            title: item['title'].toString(),
            difficulty: (item['difficulty'] as num?)?.toInt() ?? 1,
          ),
      ];
    } on DioException {
      return null;
    }
  }

  /// Amends the (auto-generated) difficulty.
  Future<bool> setDifficulty(String id, int difficulty) async {
    try {
      await _dio.patch('/quests/$id', data: {'difficulty': difficulty});
      return true;
    } on DioException {
      return false;
    }
  }
}

final questsRepositoryProvider = Provider<QuestsRepository>((ref) {
  return QuestsRepository(ref.watch(dioProvider));
});

/// Server quest list; null when the backend is unreachable.
final remoteQuestsProvider = FutureProvider<List<QuestDto>?>((ref) {
  return ref.watch(questsRepositoryProvider).fetchQuests();
});
