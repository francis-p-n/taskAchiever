import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

/// One workout/activity row (Strava import or manual log).
class ActivityDto {
  final String name;
  final String? sportType;
  final String source; // 'strava' | 'manual' | 'health'
  final DateTime startTime;
  final int durationSeconds;
  final int caloriesBurned;
  final int? avgHeartRate;

  const ActivityDto({
    required this.name,
    this.sportType,
    required this.source,
    required this.startTime,
    this.durationSeconds = 0,
    this.caloriesBurned = 0,
    this.avgHeartRate,
  });

  static ActivityDto? tryParse(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startTime']?.toString() ?? '');
    if (start == null) return null;
    return ActivityDto(
      name: json['name']?.toString() ?? 'Activity',
      sportType: json['sportType']?.toString(),
      source: json['source']?.toString() ?? 'manual',
      startTime: start,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toInt() ?? 0,
      avgHeartRate: (json['avgHeartRate'] as num?)?.toInt(),
    );
  }
}

/// Today's fitness snapshot from GET /fitness/daily.
class DailyFitnessDto {
  final int steps;
  final int caloriesBurned;
  final int? heartRateMin;
  final int? heartRateMax;
  final int? sleepScore;
  final List<ActivityDto> activities;

  const DailyFitnessDto({
    this.steps = 0,
    this.caloriesBurned = 0,
    this.heartRateMin,
    this.heartRateMax,
    this.sleepScore,
    this.activities = const [],
  });

  factory DailyFitnessDto.fromJson(Map<String, dynamic> json) {
    return DailyFitnessDto(
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toInt() ?? 0,
      heartRateMin: (json['heartRateMin'] as num?)?.toInt(),
      heartRateMax: (json['heartRateMax'] as num?)?.toInt(),
      sleepScore: (json['sleepScore'] as num?)?.toInt(),
      activities: [
        if (json['activities'] is List)
          for (final item in json['activities'] as List)
            if (item is Map<String, dynamic>)
              if (ActivityDto.tryParse(item) case final ActivityDto activity)
                activity,
      ],
    );
  }

  /// True when a full min/max heart-rate range was recorded today.
  bool get hasHeartRate => heartRateMin != null && heartRateMax != null;

  /// True when nothing has been logged today.
  bool get isEmpty =>
      steps == 0 &&
      caloriesBurned == 0 &&
      heartRateMin == null &&
      heartRateMax == null &&
      activities.isEmpty;
}

class FitnessRepository {
  final Dio _dio;
  FitnessRepository(this._dio);

  Future<DailyFitnessDto> fetchDailyFitness() async {
    // Local-first: the sync backend is optional, fall back when offline.
    try {
      final response = await _dio.get('/fitness/daily');
      return DailyFitnessDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return const DailyFitnessDto();
    }
  }

  /// POST /fitness — logs today's activity. Returns false when offline.
  Future<bool> logActivity({
    int? steps,
    int? caloriesBurned,
    int? heartRateMin,
    int? heartRateMax,
  }) async {
    try {
      await _dio.post('/fitness', data: {
        if (steps != null) 'steps': steps,
        if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
        if (heartRateMin != null) 'heartRateMin': heartRateMin,
        if (heartRateMax != null) 'heartRateMax': heartRateMax,
      });
      return true;
    } on DioException {
      return false;
    }
  }
}

final fitnessRepositoryProvider = Provider<FitnessRepository>((ref) {
  return FitnessRepository(ref.watch(dioProvider));
});

final dailyFitnessProvider = FutureProvider<DailyFitnessDto>((ref) {
  return ref.watch(fitnessRepositoryProvider).fetchDailyFitness();
});
