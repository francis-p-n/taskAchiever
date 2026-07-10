import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';
import 'package:life_os/features/player/application/player_notifier.dart';

class UserStatsDto {
  final int experiencePoints;
  final int totalCompleted;
  final int currentStreak;
  final int longestStreak;
  final int streakFreezes;
  final bool streakAtRisk; // true = nothing completed yet today

  UserStatsDto({
    required this.experiencePoints,
    required this.totalCompleted,
    required this.currentStreak,
    required this.longestStreak,
    required this.streakFreezes,
    this.streakAtRisk = false,
  });

  factory UserStatsDto.fromJson(Map<String, dynamic> json) => UserStatsDto(
        experiencePoints: (json['experiencePoints'] as num?)?.toInt() ?? 0,
        totalCompleted: (json['totalCompleted'] as num?)?.toInt() ?? 0,
        currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
        longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
        streakFreezes: (json['streakFreezes'] as num?)?.toInt() ?? 0,
        streakAtRisk: json['streakAtRisk'] == true,
      );
}

class StatsRepository {
  final Dio _dio;
  StatsRepository(this._dio);

  /// Lifetime gamification stats from the backend, or null when offline.
  Future<UserStatsDto?> fetchStats() async {
    try {
      final response = await _dio.get('/stats');
      final data = response.data;
      if (data is! Map<String, dynamic> || data.isEmpty) return null;
      return UserStatsDto.fromJson(data);
    } on DioException {
      return null;
    }
  }
}

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository(ref.watch(dioProvider));
});

/// Lifetime stats (streaks included) for the dashboard; null when offline.
final userStatsProvider = FutureProvider<UserStatsDto?>((ref) {
  return ref.watch(statsRepositoryProvider).fetchStats();
});

/// Fetches server stats at startup and makes the backend's lifetime XP the
/// source of truth for the player's level/progress. No-op when offline.
final playerHydrationProvider = FutureProvider<void>((ref) async {
  final stats = await ref.watch(statsRepositoryProvider).fetchStats();
  if (stats != null) {
    await ref
        .read(playerProvider.notifier)
        .hydrateFromServerXp(stats.experiencePoints);
  }
});
