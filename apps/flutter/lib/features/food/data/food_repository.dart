import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/network/api_client.dart';

class FoodRepository {
  final Dio _dio;
  FoodRepository(this._dio);

  Future<List<dynamic>> fetchTodayFood() async {
    // Local-first: the sync backend is optional, fall back when offline.
    try {
      final response = await _dio.get('/food/today');
      return response.data as List<dynamic>;
    } on DioException {
      return const [];
    }
  }
}

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(dioProvider));
});

final todayFoodProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(foodRepositoryProvider).fetchTodayFood();
});
