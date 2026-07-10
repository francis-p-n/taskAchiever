import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

/// One week of aggregates from GET /api/summary/weekly | /trends.
class WeeklySummaryDto {
  final DateTime weekStart;
  final int questsCompleted;
  final int xpEarned;
  final int activeDays;
  final int workouts;
  final int caloriesBurned;
  final int avgDailySteps;
  final int avgDailyCalories;
  final int spendingCents;

  WeeklySummaryDto({
    required this.weekStart,
    required this.questsCompleted,
    required this.xpEarned,
    required this.activeDays,
    required this.workouts,
    required this.caloriesBurned,
    required this.avgDailySteps,
    required this.avgDailyCalories,
    required this.spendingCents,
  });

  factory WeeklySummaryDto.fromJson(Map<String, dynamic> json) {
    final quests = (json['quests'] as Map?)?.cast<String, dynamic>() ?? const {};
    final fitness = (json['fitness'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nutrition = (json['nutrition'] as Map?)?.cast<String, dynamic>() ?? const {};
    final spending = (json['spending'] as Map?)?.cast<String, dynamic>() ?? const {};
    int asInt(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;

    return WeeklySummaryDto(
      weekStart: DateTime.tryParse(json['weekStart'] as String? ?? '') ?? DateTime.now(),
      questsCompleted: asInt(quests, 'completed'),
      xpEarned: asInt(quests, 'xpEarned'),
      activeDays: asInt(quests, 'activeDays'),
      workouts: asInt(fitness, 'workouts'),
      caloriesBurned: asInt(fitness, 'caloriesBurned'),
      avgDailySteps: asInt(fitness, 'avgDailySteps'),
      avgDailyCalories: asInt(nutrition, 'avgDailyCalories'),
      spendingCents: asInt(spending, 'totalCents'),
    );
  }
}

class SummaryRepository {
  final Dio _dio;
  SummaryRepository(this._dio);

  /// This week's aggregates, or null when offline.
  Future<WeeklySummaryDto?> fetchWeekly() async {
    try {
      final response = await _dio.get('/summary/weekly');
      return WeeklySummaryDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  /// Per-week series (oldest first) for trend charts, or null when offline.
  Future<List<WeeklySummaryDto>?> fetchTrends({int weeks = 8}) async {
    try {
      final response = await _dio.get(
        '/summary/trends',
        queryParameters: {'weeks': weeks},
        // Uncached trends compute several weeks server-side.
        options: Options(receiveTimeout: const Duration(seconds: 15)),
      );
      return [
        for (final week in (response.data['weeks'] as List))
          WeeklySummaryDto.fromJson(week as Map<String, dynamic>),
      ];
    } on DioException {
      return null;
    }
  }
}

final summaryRepositoryProvider = Provider<SummaryRepository>((ref) {
  return SummaryRepository(ref.watch(dioProvider));
});

final weeklySummaryProvider = FutureProvider<WeeklySummaryDto?>((ref) {
  return ref.watch(summaryRepositoryProvider).fetchWeekly();
});

final trendsProvider = FutureProvider<List<WeeklySummaryDto>?>((ref) {
  return ref.watch(summaryRepositoryProvider).fetchTrends();
});
