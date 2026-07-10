import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

/// One meal log entry from GET /food/today, parsed defensively so a
/// missing or oddly-typed field never crashes the screen.
class FoodLogDto {
  final String mealType;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;

  const FoodLogDto({
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  factory FoodLogDto.fromJson(Map<String, dynamic> json) {
    return FoodLogDto(
      mealType: json['mealType']?.toString() ?? 'Meal',
      calories: _asInt(json['calories']),
      protein: _asInt(json['protein']),
      carbs: _asInt(json['carbs']),
      fats: _asInt(json['fats']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class FoodRepository {
  final Dio _dio;
  FoodRepository(this._dio);

  Future<List<FoodLogDto>> fetchTodayFood() async {
    // Local-first: the sync backend is optional, fall back when offline.
    try {
      final response = await _dio.get('/food/today');
      final data = response.data;
      if (data is! List) return const [];
      return [
        for (final item in data)
          if (item is Map<String, dynamic>) FoodLogDto.fromJson(item),
      ];
    } on DioException {
      return const [];
    }
  }

  /// POST /food. Returns false instead of throwing when the backend is down.
  Future<bool> logMeal({
    required String mealType,
    required int calories,
    int? protein,
    int? carbs,
    int? fats,
  }) async {
    try {
      await _dio.post('/food', data: {
        'mealType': mealType,
        'calories': calories,
        if (protein != null) 'protein': protein,
        if (carbs != null) 'carbs': carbs,
        if (fats != null) 'fats': fats,
      });
      return true;
    } on DioException {
      return false;
    }
  }
}

final foodRepositoryProvider = Provider<FoodRepository>((ref) {
  return FoodRepository(ref.watch(dioProvider));
});

final todayFoodProvider = FutureProvider<List<FoodLogDto>>((ref) {
  return ref.watch(foodRepositoryProvider).fetchTodayFood();
});
