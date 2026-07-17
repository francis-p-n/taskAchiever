import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';
import 'package:life_os/features/achievements/domain/achievement.dart';

class AchievementsRepository {
  final Dio _dio;
  AchievementsRepository(this._dio);

  /// Full catalog with this user's unlock state; null when offline.
  Future<List<Achievement>?> fetchAchievements() async {
    try {
      final response = await _dio.get('/achievements');
      final data = response.data;
      if (data is! List) return null;
      return [
        for (final item in data)
          if (item is Map<String, dynamic>) Achievement.fromJson(item),
      ];
    } on DioException {
      return null;
    }
  }
}

final achievementsRepositoryProvider = Provider<AchievementsRepository>((ref) {
  return AchievementsRepository(ref.watch(dioProvider));
});

final achievementsProvider = FutureProvider<List<Achievement>?>((ref) {
  return ref.watch(achievementsRepositoryProvider).fetchAchievements();
});
