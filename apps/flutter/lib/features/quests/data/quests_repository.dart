import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';
import 'package:life_os/features/player/domain/player.dart';

class QuestDto {
  final String id;
  final String title;
  final String? category;
  final int difficulty;
  final DateTime? dueDate;
  final DateTime? completedAt;

  QuestDto({
    required this.id,
    required this.title,
    this.category,
    required this.difficulty,
    this.dueDate,
    this.completedAt,
  });

  factory QuestDto.fromJson(Map<String, dynamic> json) => QuestDto(
        id: json['id'] as String,
        title: json['title'] as String,
        category: json['category'] as String?,
        difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
        dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
        completedAt:
            json['completedAt'] != null ? DateTime.tryParse(json['completedAt'] as String) : null,
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
  }) async {
    try {
      final response = await _dio.post('/quests', data: {
        'title': title,
        'description': description,
        'category': category,
        'difficulty': difficulty,
        'dueDate': dueDate?.toIso8601String(),
      });
      return QuestDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  /// Marks a quest complete on the server (awards XP/streak in user_stats).
  Future<bool> completeQuest(String id, {int fulfillment = 3}) async {
    try {
      await _dio.post('/quests/$id/complete', data: {'fulfillment': fulfillment});
      return true;
    } on DioException {
      return false;
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
}

final questsRepositoryProvider = Provider<QuestsRepository>((ref) {
  return QuestsRepository(ref.watch(dioProvider));
});

/// Server quest list; null when the backend is unreachable.
final remoteQuestsProvider = FutureProvider<List<QuestDto>?>((ref) {
  return ref.watch(questsRepositoryProvider).fetchQuests();
});
