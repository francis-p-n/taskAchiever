import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/network/api_client.dart';

class ContactDto {
  final int id;
  final String name;
  final String relationshipType;
  final DateTime? lastContactedAt;
  final int engagementScore;
  final bool atRisk;

  const ContactDto({
    required this.id,
    required this.name,
    required this.relationshipType,
    required this.lastContactedAt,
    required this.engagementScore,
    required this.atRisk,
  });

  factory ContactDto.fromJson(Map<String, dynamic> json) {
    return ContactDto(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'Contact',
      relationshipType: (json['relationshipType'] as String?) ?? 'friend',
      lastContactedAt:
          DateTime.tryParse(json['lastContactedAt'] as String? ?? ''),
      engagementScore: (json['engagementScore'] as num?)?.toInt() ?? 0,
      atRisk: (json['atRisk'] as bool?) ?? false,
    );
  }
}

class RelationshipsRepository {
  final Dio _dio;
  RelationshipsRepository(this._dio);

  Future<List<ContactDto>> fetchContacts() async {
    try {
      final response = await _dio.get('/contacts');
      return [
        for (final item in response.data as List<dynamic>)
          ContactDto.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException {
      return const [];
    }
  }

  Future<bool> addContact({
    required String name,
    required String relationshipType,
  }) async {
    try {
      await _dio.post('/contacts', data: {
        'name': name,
        'relationshipType': relationshipType,
      });
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> logInteraction({
    required int contactId,
    required String interactionType,
    String? notes,
  }) async {
    try {
      await _dio.post('/contacts/$contactId/interactions', data: {
        'interactionType': interactionType,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      });
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> deleteContact(int id) async {
    try {
      await _dio.delete('/contacts/$id');
      return true;
    } on DioException {
      return false;
    }
  }
}

final relationshipsRepositoryProvider =
    Provider<RelationshipsRepository>((ref) {
  return RelationshipsRepository(ref.watch(dioProvider));
});

final contactsProvider = FutureProvider<List<ContactDto>>((ref) {
  return ref.watch(relationshipsRepositoryProvider).fetchContacts();
});
