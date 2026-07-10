import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

/// Connect/sync calls run a full server-side sync inline, so they get a
/// longer deadline than the default 3s data reads.
final _longCall = Options(
  receiveTimeout: const Duration(seconds: 45),
  sendTimeout: const Duration(seconds: 15),
);

class IntegrationInfo {
  final bool connected;
  final DateTime? lastSyncAt;

  const IntegrationInfo({required this.connected, this.lastSyncAt});

  static IntegrationInfo fromJson(Map<String, dynamic>? json) => IntegrationInfo(
        connected: json?['connected'] == true,
        lastSyncAt: json?['lastSyncAt'] != null
            ? DateTime.tryParse(json!['lastSyncAt'] as String)
            : null,
      );
}

class IntegrationsStatus {
  final IntegrationInfo todoist;
  final IntegrationInfo calendar;
  final IntegrationInfo plaid;
  final bool plaidConfigured;
  final bool aiConfigured;

  const IntegrationsStatus({
    required this.todoist,
    required this.calendar,
    required this.plaid,
    required this.plaidConfigured,
    required this.aiConfigured,
  });
}

/// Result of a connect/sync/disconnect action, with a user-displayable message.
class IntegrationResult {
  final bool ok;
  final String message;

  const IntegrationResult(this.ok, this.message);
}

class IntegrationsRepository {
  final Dio _dio;
  IntegrationsRepository(this._dio);

  Future<IntegrationsStatus?> fetchStatus() async {
    try {
      final res = await _dio.get('/integrations');
      final data = res.data as Map<String, dynamic>;
      return IntegrationsStatus(
        todoist: IntegrationInfo.fromJson(data['todoist'] as Map<String, dynamic>?),
        calendar: IntegrationInfo.fromJson(data['calendar'] as Map<String, dynamic>?),
        plaid: IntegrationInfo.fromJson(data['plaid'] as Map<String, dynamic>?),
        plaidConfigured: (data['plaid'] as Map<String, dynamic>?)?['configured'] == true,
        aiConfigured: (data['ai'] as Map<String, dynamic>?)?['configured'] == true,
      );
    } on DioException {
      return null; // backend offline — callers show the disconnected state
    }
  }

  Future<IntegrationResult> connectTodoist(String apiKey,
          {String? projectName}) =>
      _action(() => _dio.post('/integrations/todoist',
          data: {
            'apiKey': apiKey,
            if (projectName != null) 'projectName': projectName,
          },
          options: _longCall));

  Future<IntegrationResult> syncTodoist() =>
      _action(() => _dio.post('/integrations/todoist/sync', options: _longCall));

  Future<IntegrationResult> disconnectTodoist() =>
      _action(() => _dio.delete('/integrations/todoist'));

  Future<IntegrationResult> connectCalendar(String icalUrl) =>
      _action(() => _dio.post('/integrations/calendar',
          data: {'icalUrl': icalUrl}, options: _longCall));

  Future<IntegrationResult> syncCalendar() =>
      _action(() => _dio.post('/integrations/calendar/sync', options: _longCall));

  Future<IntegrationResult> disconnectCalendar() =>
      _action(() => _dio.delete('/integrations/calendar'));

  Future<IntegrationResult> _action(Future<Response> Function() call) async {
    try {
      final res = await call();
      final data = res.data;
      final sync = data is Map<String, dynamic>
          ? (data['sync'] as Map<String, dynamic>? ?? data)
          : const <String, dynamic>{};
      final imported = sync['imported'] ?? sync['added'];
      final detail = imported != null ? ' — $imported items synced' : '';
      return IntegrationResult(true, 'Done$detail');
    } on DioException catch (e) {
      final body = e.response?.data;
      final message = body is Map<String, dynamic>
          ? (body['error'] ?? body['reason'] ?? 'Request failed').toString()
          : 'Backend offline — try again later';
      return IntegrationResult(false, message);
    }
  }
}

final integrationsRepositoryProvider = Provider<IntegrationsRepository>((ref) {
  return IntegrationsRepository(ref.watch(dioProvider));
});

/// Refreshable status of every external integration. Invalidate after any
/// connect/disconnect/sync action.
final integrationsStatusProvider = FutureProvider<IntegrationsStatus?>((ref) {
  return ref.watch(integrationsRepositoryProvider).fetchStatus();
});
