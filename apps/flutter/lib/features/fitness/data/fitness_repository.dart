import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/network/api_client.dart';

class FitnessRepository {
  final Dio _dio;
  FitnessRepository(this._dio);

  Future<Map<String, dynamic>> fetchDailyFitness() async {
    final response = await _dio.get('/fitness/daily');
    return response.data as Map<String, dynamic>;
  }
}

final fitnessRepositoryProvider = Provider<FitnessRepository>((ref) {
  return FitnessRepository(ref.watch(dioProvider));
});

final dailyFitnessProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(fitnessRepositoryProvider).fetchDailyFitness();
});
