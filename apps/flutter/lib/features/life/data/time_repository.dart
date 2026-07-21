import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

/// One logged block of time from GET /time/recent.
class TimeEntryDto {
  final String category;
  final DateTime startTime;
  final int durationMinutes;
  final String? notes;
  final int? roiScore;

  const TimeEntryDto({
    required this.category,
    required this.startTime,
    required this.durationMinutes,
    this.notes,
    this.roiScore,
  });

  factory TimeEntryDto.fromJson(Map<String, dynamic> json) {
    return TimeEntryDto(
      category: (json['category'] as String?) ?? 'rest',
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ??
          DateTime.now(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
      roiScore: (json['roiScore'] as num?)?.toInt(),
    );
  }
}

/// Per-category aggregate from GET /time/summary.
class TimeCategorySummary {
  final String category;
  final int minutes;
  final int entries;
  final int avgRoi;

  const TimeCategorySummary({
    required this.category,
    required this.minutes,
    required this.entries,
    required this.avgRoi,
  });

  factory TimeCategorySummary.fromJson(Map<String, dynamic> json) {
    return TimeCategorySummary(
      category: (json['category'] as String?) ?? 'rest',
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      entries: (json['entries'] as num?)?.toInt() ?? 0,
      avgRoi: (json['avgRoi'] as num?)?.toInt() ?? 0,
    );
  }
}

class TimeSummaryDto {
  final int rangeDays;
  final int totalMinutes;
  final List<TimeCategorySummary> byCategory;
  final List<TimeCategorySummary> roiRanking;

  const TimeSummaryDto({
    required this.rangeDays,
    required this.totalMinutes,
    required this.byCategory,
    required this.roiRanking,
  });

  factory TimeSummaryDto.fromJson(Map<String, dynamic> json) {
    List<TimeCategorySummary> parse(String key) => [
          for (final item in (json[key] as List<dynamic>? ?? []))
            TimeCategorySummary.fromJson(item as Map<String, dynamic>),
        ];
    return TimeSummaryDto(
      rangeDays: (json['rangeDays'] as num?)?.toInt() ?? 7,
      totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
      byCategory: parse('byCategory'),
      roiRanking: parse('roiRanking'),
    );
  }
}

class TimeRepository {
  final Dio _dio;
  TimeRepository(this._dio);

  Future<List<TimeEntryDto>> fetchRecent() async {
    try {
      final response = await _dio.get('/time/recent');
      return [
        for (final item in response.data as List<dynamic>)
          TimeEntryDto.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException {
      return const [];
    }
  }

  /// Null means the backend is unreachable — callers show placeholders.
  Future<TimeSummaryDto?> fetchSummary({String range = '7d'}) async {
    try {
      final response =
          await _dio.get('/time/summary', queryParameters: {'range': range});
      return TimeSummaryDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  /// Returns false when the backend rejected the write or is offline.
  Future<bool> logEntry({
    required String category,
    required int durationMinutes,
    String? notes,
    int? moodBefore,
    int? moodAfter,
    int? energyBefore,
    int? energyAfter,
  }) async {
    try {
      await _dio.post('/time', data: {
        'category': category,
        'durationMinutes': durationMinutes,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'moodBefore': ?moodBefore,
        'moodAfter': ?moodAfter,
        'energyBefore': ?energyBefore,
        'energyAfter': ?energyAfter,
      });
      return true;
    } on DioException {
      return false;
    }
  }
}

final timeRepositoryProvider = Provider<TimeRepository>((ref) {
  return TimeRepository(ref.watch(dioProvider));
});

final recentTimeEntriesProvider = FutureProvider<List<TimeEntryDto>>((ref) {
  return ref.watch(timeRepositoryProvider).fetchRecent();
});

final timeSummaryProvider = FutureProvider<TimeSummaryDto?>((ref) {
  return ref.watch(timeRepositoryProvider).fetchSummary();
});
