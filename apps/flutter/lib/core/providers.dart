import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:life_os/core/network/api_client.dart';
import 'package:life_os/core/offline_queue.dart';
import 'package:life_os/core/sync_engine.dart';
import 'package:life_os/features/quests/data/quests_repository.dart';

// Provides the global Isar instance. Will be overridden in main.dart once initialized.
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider must be overridden');
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(ref.watch(dioProvider), ref.watch(offlineQueueProvider));
});

/// App-lifetime offline sync loop: flush the queued mutations once at
/// startup, then again every time connectivity comes back. A successful
/// flush refetches quests so the server's conflict resolution lands in the
/// UI.
final offlineSyncProvider = Provider<void>((ref) {
  final engine = ref.watch(syncEngineProvider);

  Future<void> flushAndRefresh() async {
    if (await engine.flushQueue()) {
      ref.invalidate(remoteQuestsProvider);
    }
  }

  unawaited(flushAndRefresh());
  final subscription = engine.watchConnectivity(() => unawaited(flushAndRefresh()));
  ref.onDispose(subscription.cancel);
});
