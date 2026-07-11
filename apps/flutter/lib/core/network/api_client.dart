import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _devEmail = 'mugicianx@gmail.com';
const _tokenPrefsKey = 'api_auth_token';
const _urlPrefsKey = 'backend_url';

/// Matches the backend's AUTH_ACCESS_CODE on hosted deployments (Settings →
/// Server). Local dev backends don't set one, so this stays empty there.
const accessCodePrefsKey = 'auth_access_code';

/// Compile-time default, overridable per install from Settings → Server.
/// On the desktop the backend runs locally; a phone points this at the PC's
/// LAN address (http://192.168.x.x:3000/api) or a hosted deployment.
const _defaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000/api',
);

/// The backend base URL. Changing it (Settings → Server) rebuilds the Dio
/// client and, through it, every repository in the app.
class BackendUrlNotifier extends StateNotifier<String> {
  BackendUrlNotifier() : super(_defaultBaseUrl) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_urlPrefsKey);
    if (saved != null && saved.isNotEmpty && mounted) state = saved;
  }

  Future<void> set(String url) async {
    state = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlPrefsKey, url);
  }
}

final backendUrlProvider =
    StateNotifierProvider<BackendUrlNotifier, String>((ref) {
  return BackendUrlNotifier();
});

/// Attaches a JWT to every request, obtaining one from the backend's dev
/// login endpoint on first use (single-user desktop app — no login UI).
/// On a 401 (expired token) it re-authenticates once and retries.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._dio);

  final Dio _dio;
  String? _token;
  Future<String?>? _loginInFlight;

  Future<String?> _getToken({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      if (_token != null) return _token;
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenPrefsKey);
      if (_token != null) return _token;
    }

    // Deduplicate concurrent logins from parallel requests.
    _loginInFlight ??= _login();
    try {
      return await _loginInFlight;
    } finally {
      _loginInFlight = null;
    }
  }

  Future<String?> _login() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessCode = prefs.getString(accessCodePrefsKey);
      final response = await _dio.post(
        '/auth/dev',
        data: {
          'email': _devEmail,
          if (accessCode != null && accessCode.isNotEmpty)
            'accessCode': accessCode,
        },
        options: Options(headers: {'skip-auth': 'true'}),
      );
      final token = response.data['token'] as String?;
      if (token != null) {
        _token = token;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenPrefsKey, token);
      }
      return token;
    } on DioException {
      return null; // Backend unreachable — app is local-first, callers cope.
    }
  }

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.headers.remove('skip-auth') != null) {
      return handler.next(options);
    }
    final token = await _getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    // Token expired or invalidated: re-login once and retry the request.
    if (err.response?.statusCode == 401 &&
        err.requestOptions.headers['retried-auth'] != 'true') {
      final token = await _getToken(forceRefresh: true);
      if (token != null) {
        final options = err.requestOptions
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['retried-auth'] = 'true';
        try {
          final response = await _dio.fetch(options);
          return handler.resolve(response);
        } on DioException catch (retryErr) {
          return handler.next(retryErr);
        }
      }
    }
    handler.next(err);
  }
}

/// Single Dio instance for the sync backend (Fastify → Neon Postgres). The
/// app is local-first: callers must tolerate this host being unreachable.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ref.watch(backendUrlProvider),
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );
  dio.interceptors.add(_AuthInterceptor(dio));
  return dio;
});
