import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/network/api_client.dart';

class FitnessRepository {
  final Dio _dio;
  FitnessRepository(this._dio);

  Future<Map<String, dynamic>> fetchDailyFitness() async {
    // Local-first: the sync backend is optional, fall back when offline.
    try {
      final response = await _dio.get('/fitness/daily');
      return response.data as Map<String, dynamic>;
    } on DioException {
      return const {'steps': 0, 'caloriesBurned': 0};
    }
  }
}

final fitnessRepositoryProvider = Provider<FitnessRepository>((ref) {
  return FitnessRepository(ref.watch(dioProvider));
});

final dailyFitnessProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(fitnessRepositoryProvider).fetchDailyFitness();
});
