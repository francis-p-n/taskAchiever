import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/network/api_client.dart';

class SpendingRepository {
  final Dio _dio;
  SpendingRepository(this._dio);

  Future<List<dynamic>> fetchRecentSpending() async {
    final response = await _dio.get('/spending/recent');
    return response.data as List<dynamic>;
  }
}

final spendingRepositoryProvider = Provider<SpendingRepository>((ref) {
  return SpendingRepository(ref.watch(dioProvider));
});

final recentSpendingProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(spendingRepositoryProvider).fetchRecentSpending();
});
