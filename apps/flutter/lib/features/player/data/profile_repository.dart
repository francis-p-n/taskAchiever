import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

/// Server copy of the player profile blob, for cross-device sync.
class RemoteProfile {
  final Map<String, dynamic>? profile;
  final DateTime? updatedAt;

  const RemoteProfile({this.profile, this.updatedAt});
}

/// Syncs the client player profile (name/class/energies/daily counters)
/// through the backend. The server arbitrates last-write-wins; a rejected
/// push returns the winning copy so the device can adopt it.
class ProfileRepository {
  final Dio _dio;
  ProfileRepository(this._dio);

  Future<RemoteProfile?> fetch() async {
    try {
      final res = await _dio.get('/player/profile');
      final data = res.data as Map<String, dynamic>;
      return RemoteProfile(
        profile: (data['profile'] as Map?)?.cast<String, dynamic>(),
        updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? ''),
      );
    } on DioException {
      return null;
    }
  }

  /// Pushes the local profile. Returns the winning remote copy when the
  /// server had something newer, null on success or offline.
  Future<RemoteProfile?> push(String profileJson, DateTime updatedAt) async {
    try {
      final res = await _dio.put('/player/profile', data: {
        'profile': jsonDecode(profileJson),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      });
      final data = res.data as Map<String, dynamic>;
      if (data['accepted'] == true) return null;
      return RemoteProfile(
        profile: (data['profile'] as Map?)?.cast<String, dynamic>(),
        updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? ''),
      );
    } on DioException {
      return null; // offline — local stays authoritative until reconnect
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});
