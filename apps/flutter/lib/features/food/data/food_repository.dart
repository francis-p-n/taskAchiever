import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/network/api_client.dart';

class FoodRepository {
  final Dio _dio;
  FoodRepository(this._dio);

  Future<List<dynamic>> fetchTodayFood() async {
    final response = await _dio.get('/food/today');
    return response.data as List<dynamic>;
  }
}

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(dioProvider));
});

final todayFoodProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(foodRepositoryProvider).fetchTodayFood();
});
