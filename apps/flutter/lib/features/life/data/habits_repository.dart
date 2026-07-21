import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

class HabitDto {
  final int id;
  final String name;
  final String category;
  final int difficulty;
  final String targetFrequency;
  final int currentStreakDays;
  final int longestStreakDays;
  final int freezesRemaining;
  final bool completedToday;

  const HabitDto({
    required this.id,
    required this.name,
    required this.category,
    required this.difficulty,
    required this.targetFrequency,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.freezesRemaining,
    required this.completedToday,
  });

  factory HabitDto.fromJson(Map<String, dynamic> json) {
    return HabitDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'Habit',
      category: (json['category'] as String?) ?? 'fitness',
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 3,
      targetFrequency: (json['targetFrequency'] as String?) ?? 'daily',
      currentStreakDays: (json['currentStreakDays'] as num?)?.toInt() ?? 0,
      longestStreakDays: (json['longestStreakDays'] as num?)?.toInt() ?? 0,
      freezesRemaining: (json['freezesRemaining'] as num?)?.toInt() ?? 0,
      completedToday: (json['completedToday'] as bool?) ?? false,
    );
  }
}

class HabitsRepository {
  final Dio _dio;
  HabitsRepository(this._dio);

  Future<List<HabitDto>> fetchHabits() async {
    try {
      final response = await _dio.get('/habits');
      return [
        for (final item in response.data as List<dynamic>)
          HabitDto.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException {
      return const [];
    }
  }

  Future<bool> createHabit({
    required String name,
    required String category,
    required int difficulty,
    required String targetFrequency,
  }) async {
    try {
      await _dio.post('/habits', data: {
        'name': name,
        'category': category,
        'difficulty': difficulty,
        'targetFrequency': targetFrequency,
      });
      return true;
    } on DioException {
      return false;
    }
  }

  /// Result of a completion tap. `alreadyDone` distinguishes the 409 from
  /// an offline failure so the UI can word the message honestly.
  Future<({bool ok, bool alreadyDone, int streak, int xp})> completeHabit(
      int id) async {
    try {
      final response = await _dio.post('/habits/$id/complete');
      final data = response.data as Map<String, dynamic>;
      return (
        ok: true,
        alreadyDone: false,
        streak: (data['currentStreakDays'] as num?)?.toInt() ?? 0,
        xp: (data['xpAwarded'] as num?)?.toInt() ?? 0,
      );
    } on DioException catch (e) {
      return (
        ok: false,
        alreadyDone: e.response?.statusCode == 409,
        streak: 0,
        xp: 0,
      );
    }
  }

  Future<bool> archiveHabit(int id) async {
    try {
      await _dio.delete('/habits/$id');
      return true;
    } on DioException {
      return false;
    }
  }
}

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository(ref.watch(dioProvider));
});

final habitsProvider = FutureProvider<List<HabitDto>>((ref) {
  return ref.watch(habitsRepositoryProvider).fetchHabits();
});
