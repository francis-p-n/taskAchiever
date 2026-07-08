import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single Dio instance for the optional sync backend. The app is
/// local-first: callers must tolerate this host being unreachable.
final dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'http://127.0.0.1:3000/api', // Use 10.0.2.2 for Android emulator if needed later
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );
});
