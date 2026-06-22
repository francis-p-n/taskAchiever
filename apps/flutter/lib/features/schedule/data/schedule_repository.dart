import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_achiever/core/network/api_client.dart';

class ScheduleRepository {
  final Dio _dio;
  ScheduleRepository(this._dio);

  Future<List<dynamic>> fetchTodaySchedule() async {
    final response = await _dio.get('/schedule/today');
    return response.data as List<dynamic>;
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(dioProvider));
});

final todayScheduleProvider = FutureProvider<List<dynamic>>((ref) {
  return ref.watch(scheduleRepositoryProvider).fetchTodaySchedule();
});
