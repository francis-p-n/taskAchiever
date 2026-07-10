import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

/// One schedule entry for today, parsed defensively from the backend.
class ScheduleEventDto {
  final String title;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isGoogleEvent;

  const ScheduleEventDto({
    required this.title,
    required this.startTime,
    this.endTime,
    this.isGoogleEvent = false,
  });

  /// Returns null when the row has no parseable start time.
  static ScheduleEventDto? tryParse(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['startTime']?.toString() ?? '');
    if (start == null) return null;
    return ScheduleEventDto(
      title: json['title']?.toString() ?? 'Event',
      startTime: start,
      endTime: DateTime.tryParse(json['endTime']?.toString() ?? ''),
      isGoogleEvent: json['isGoogleEvent'] == true,
    );
  }
}

class ScheduleRepository {
  final Dio _dio;
  ScheduleRepository(this._dio);

  Future<List<ScheduleEventDto>> fetchTodaySchedule() async {
    // Local-first: the sync backend is optional, fall back when offline.
    try {
      final response = await _dio.get('/schedule/today');
      final data = response.data;
      if (data is! List) return const [];
      final events = data
          .whereType<Map<String, dynamic>>()
          .map(ScheduleEventDto.tryParse)
          .whereType<ScheduleEventDto>()
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return events;
    } on DioException {
      return const [];
    }
  }

  /// Creates an event for today. Returns false when the backend is offline.
  Future<bool> createEvent({
    required String title,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      await _dio.post('/schedule', data: {
        'title': title,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      });
      return true;
    } on DioException {
      return false;
    }
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(ref.watch(dioProvider));
});

final todayScheduleProvider = FutureProvider<List<ScheduleEventDto>>((ref) {
  return ref.watch(scheduleRepositoryProvider).fetchTodaySchedule();
});
