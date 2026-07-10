import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

/// One row from GET /spending/recent. Amounts are stored in cents.
class TransactionDto {
  final String merchant;
  final String category;
  final int amountCents;
  final DateTime transactionDate;

  const TransactionDto({
    required this.merchant,
    required this.category,
    required this.amountCents,
    required this.transactionDate,
  });

  factory TransactionDto.fromJson(Map<String, dynamic> json) {
    return TransactionDto(
      merchant: (json['merchant'] as String?) ?? 'Transaction',
      category: (json['category'] as String?) ?? 'Other',
      amountCents: (json['amount'] as num?)?.toInt() ?? 0,
      transactionDate:
          DateTime.tryParse(json['transactionDate'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// Aggregates from GET /spending/summary.
class SpendingSummaryDto {
  final int spentTodayCents;
  final int spentMonthCents;
  final List<(String category, int cents)> byCategory;

  const SpendingSummaryDto({
    required this.spentTodayCents,
    required this.spentMonthCents,
    required this.byCategory,
  });

  factory SpendingSummaryDto.fromJson(Map<String, dynamic> json) {
    return SpendingSummaryDto(
      spentTodayCents: (json['spentTodayCents'] as num?)?.toInt() ?? 0,
      spentMonthCents: (json['spentMonthCents'] as num?)?.toInt() ?? 0,
      byCategory: [
        for (final entry in (json['byCategory'] as List<dynamic>? ?? []))
          (
            (entry['category'] as String?) ?? 'Other',
            (entry['cents'] as num?)?.toInt() ?? 0,
          ),
      ],
    );
  }
}

class SpendingRepository {
  final Dio _dio;
  SpendingRepository(this._dio);

  Future<List<TransactionDto>> fetchRecentSpending() async {
    // Local-first: the sync backend is optional, fall back when offline.
    try {
      final response = await _dio.get('/spending/recent');
      return [
        for (final item in response.data as List<dynamic>)
          TransactionDto.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException {
      return const [];
    }
  }

  /// Null means the backend is unreachable — callers show placeholders.
  Future<SpendingSummaryDto?> fetchSummary() async {
    try {
      final response = await _dio.get('/spending/summary');
      return SpendingSummaryDto.fromJson(response.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  /// Returns false when the backend rejected the write or is offline.
  Future<bool> addTransaction({
    required int amountCents,
    required String category,
    required String merchant,
  }) async {
    try {
      await _dio.post('/spending', data: {
        'amount': amountCents,
        'category': category,
        'merchant': merchant,
      });
      return true;
    } on DioException {
      return false;
    }
  }
}

final spendingRepositoryProvider = Provider<SpendingRepository>((ref) {
  return SpendingRepository(ref.watch(dioProvider));
});

final recentSpendingProvider = FutureProvider<List<TransactionDto>>((ref) {
  return ref.watch(spendingRepositoryProvider).fetchRecentSpending();
});

final spendingSummaryProvider = FutureProvider<SpendingSummaryDto?>((ref) {
  return ref.watch(spendingRepositoryProvider).fetchSummary();
});
