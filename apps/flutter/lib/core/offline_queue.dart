import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _queuePrefsKey = 'offline_ops_v1';

/// One quest mutation performed while the backend was unreachable.
class PendingOp {
  final String action; // 'complete' | 'uncomplete' | 'upsert'
  final Map<String, dynamic> data; // includes id + at (client timestamp)

  const PendingOp(this.action, this.data);

  Map<String, dynamic> toJson() => {
        'collection': 'quests',
        'action': action,
        'data': data,
      };

  factory PendingOp.fromJson(Map<String, dynamic> json) => PendingOp(
        json['action'] as String,
        (json['data'] as Map).cast<String, dynamic>(),
      );
}

/// Durable queue of quest mutations made offline, persisted across restarts.
/// The sync engine drains it through POST /api/sync/push, where the server
/// resolves conflicts (last-write-wins on the row's updatedAt); whatever the
/// server decides is picked up by the follow-up quest refetch.
class OfflineQueue {
  Future<List<PendingOp>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queuePrefsKey);
    if (raw == null) return const [];
    return [
      for (final item in jsonDecode(raw) as List)
        PendingOp.fromJson((item as Map).cast<String, dynamic>()),
    ];
  }

  Future<void> enqueue(PendingOp op) async {
    final ops = List<PendingOp>.from(await load())..add(op);
    await _store(ops);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queuePrefsKey);
  }

  Future<void> _store(List<PendingOp> ops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queuePrefsKey,
      jsonEncode([for (final op in ops) op.toJson()]),
    );
  }
}

final offlineQueueProvider = Provider<OfflineQueue>((ref) => OfflineQueue());
