import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:life_achiever/core/network/api_client.dart';
import 'package:life_achiever/core/sync_engine.dart';

// Provides the global Isar instance. Will be overridden in main.dart once initialized.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden');
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final dio = ref.watch(dioProvider);
  return SyncEngine(dio);
});
