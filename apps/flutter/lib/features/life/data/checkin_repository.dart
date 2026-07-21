import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

class CheckinDto {
  final DateTime date;
  final int? morningMood;
  final int? morningEnergy;
  final int? morningStress;
  final int? sleepMinutes;
  final int? eveningMood;
  final int? eveningEnergy;
  final int? eveningStress;

  const CheckinDto({
    required this.date,
    this.morningMood,
    this.morningEnergy,
    this.morningStress,
    this.sleepMinutes,
    this.eveningMood,
    this.eveningEnergy,
    this.eveningStress,
  });

  factory CheckinDto.fromJson(Map<String, dynamic> json) {
    int? n(String key) => (json[key] as num?)?.toInt();
    return CheckinDto(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      morningMood: n('morningMood'),
      morningEnergy: n('morningEnergy'),
      morningStress: n('morningStress'),
      sleepMinutes: n('sleepMinutes'),
      eveningMood: n('eveningMood'),
      eveningEnergy: n('eveningEnergy'),
      eveningStress: n('eveningStress'),
    );
  }
}

class CheckinHistoryDto {
  final List<CheckinDto> checkins;
  final double? moodAvg;
  final double? energyAvg;
  final int? sleepMinutesAvg;

  const CheckinHistoryDto({
    required this.checkins,
    this.moodAvg,
    this.energyAvg,
    this.sleepMinutesAvg,
  });

  factory CheckinHistoryDto.fromJson(Map<String, dynamic> json) {
    final averages = (json['averages'] as Map<String, dynamic>?) ?? const {};
    return CheckinHistoryDto(
      checkins: [
        for (final item in (json['checkins'] as List<dynamic>? ?? []))
          CheckinDto.fromJson(item as Map<String, dynamic>),
      ],
      moodAvg: (averages['mood'] as num?)?.toDouble(),
      energyAvg: (averages['energy'] as num?)?.toDouble(),
      sleepMinutesAvg: (averages['sleepMinutes'] as num?)?.toInt(),
    );
  }
}

class CheckinRepository {
  final Dio _dio;
  CheckinRepository(this._dio);

  /// Null means the backend is unreachable.
  Future<CheckinHistoryDto?> fetchRecent({int days = 14}) async {
    try {
      final response =
          await _dio.get('/checkins/recent', queryParameters: {'days': days});
      return CheckinHistoryDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  /// Sends only the provided half (morning or evening) for today.
  Future<bool> submit({
    int? morningMood,
    int? morningEnergy,
    int? morningStress,
    int? sleepMinutes,
    int? eveningMood,
    int? eveningEnergy,
    int? eveningStress,
  }) async {
    try {
      final now = DateTime.now();
      final day = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await _dio.post('/checkins', data: {
        'date': day,
        'morningMood': ?morningMood,
        'morningEnergy': ?morningEnergy,
        'morningStress': ?morningStress,
        'sleepMinutes': ?sleepMinutes,
        'eveningMood': ?eveningMood,
        'eveningEnergy': ?eveningEnergy,
        'eveningStress': ?eveningStress,
      });
      return true;
    } on DioException {
      return false;
    }
  }
}

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  return CheckinRepository(ref.watch(dioProvider));
});

final checkinHistoryProvider = FutureProvider<CheckinHistoryDto?>((ref) {
  return ref.watch(checkinRepositoryProvider).fetchRecent();
});
