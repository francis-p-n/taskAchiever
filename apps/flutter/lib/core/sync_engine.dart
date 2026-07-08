// SyncEngine skeleton for Flutter
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';

class SyncEngine {
  final Dio dio;
  
  SyncEngine(this.dio);

  Future<void> pushOfflineOperations() async {
    // 1. Read pending operations from local Isar `PendingOperation` collection
    final operations = []; // e.g. await isar.pendingOperations.where().findAll();
    
    if (operations.isEmpty) return;

    try {
      final response = await dio.post('/api/sync/push', data: {
        'operations': operations.map((o) => jsonDecode(o.payload)).toList(),
      });

      if (response.statusCode == 200) {
        // 2. Clear local operations queue on success
        // await isar.writeTxn(() => isar.pendingOperations.clear());
      }
    } catch (e) {
      developer.log('Sync failed, will retry later: $e', name: 'SyncEngine');
    }
  }

  /// Returns true when the pull succeeded, false when the backend was
  /// unreachable (the app is local-first, so this is a normal condition).
  Future<bool> pullUpdates() async {
    // 1. Fetch last sync timestamp from local storage
    final lastSync = '2026-01-01T00:00:00Z'; // e.g. prefs.getString('lastSync')

    try {
      final response = await dio.get('/sync/pull', queryParameters: {'since': lastSync});

      if (response.statusCode == 200) {
        // 2. Upsert fetched records (quests, stats) from response.data
        //    into the local Isar DB
        // 3. Update last sync timestamp
        // prefs.setString('lastSync', response.data['timestamp']);
        return true;
      }
      return false;
    } catch (e) {
      developer.log('Pull failed: $e', name: 'SyncEngine');
      return false;
    }
  }
}
