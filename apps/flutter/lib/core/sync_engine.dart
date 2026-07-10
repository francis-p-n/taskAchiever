import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import 'package:life_os/core/offline_queue.dart';

/// Drains the offline mutation queue to the backend and reports whether
/// anything was applied, so callers know to refetch server state.
///
/// Conflict resolution is server-side last-write-wins: each op carries the
/// client timestamp (`at`), the server compares it with the row's updatedAt
/// and answers 'applied', 'conflict' (server row included) or 'missing'.
/// In every case the queue entry is consumed — the refetch that follows a
/// flush replaces local state with the server's resolution.
class SyncEngine {
  SyncEngine(this._dio, this._queue);

  final Dio _dio;
  final OfflineQueue _queue;
  bool _flushing = false;

  /// Pushes queued offline ops. Returns true when ops were flushed and the
  /// caller should refresh quest data. Leaves the queue intact when the
  /// backend is still unreachable.
  Future<bool> flushQueue() async {
    if (_flushing) return false;
    _flushing = true;
    try {
      final ops = await _queue.load();
      if (ops.isEmpty) return false;

      final response = await _dio.post('/sync/push', data: {
        'operations': [for (final op in ops) op.toJson()],
      });

      if (response.statusCode == 200) {
        await _queue.clear();
        final results = (response.data['results'] as List?) ?? const [];
        final conflicts =
            results.where((r) => r is Map && r['status'] == 'conflict').length;
        developer.log(
          'Flushed ${ops.length} offline ops ($conflicts conflicts, server won)',
          name: 'SyncEngine',
        );
        return true;
      }
      return false;
    } on DioException catch (e) {
      // 409 = another sync in flight; anything else = still offline. Either
      // way the queue survives for the next attempt.
      developer.log('Flush deferred: ${e.message}', name: 'SyncEngine');
      return false;
    } finally {
      _flushing = false;
    }
  }

  /// Fires [onReconnect] whenever connectivity returns, so the app can flush
  /// the queue and refetch without polling.
  StreamSubscription<List<ConnectivityResult>> watchConnectivity(
      void Function() onReconnect) {
    return Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) onReconnect();
    });
  }
}
