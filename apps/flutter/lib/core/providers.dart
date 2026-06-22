import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:life_achiever/core/sync_engine.dart';

// Provides the global Isar instance. Will be overridden in main.dart once initialized.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden');
});

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:3000', // Update with actual backend URL
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));
  return dio;
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final dio = ref.watch(dioProvider);
  return SyncEngine(dio);
});
