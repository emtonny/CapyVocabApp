import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

enum PhotoNoteMediaVariant { original, display, modelInput }

/// Service quản lý ảnh Photo Note trong private Supabase Storage.
class StorageService {
  final SupabaseClient _supabaseClient;
  static const String bucketName = 'photo_notes';
  static const String _photoNotesTable = 'photo_notes';
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static final RegExp _extensionPattern = RegExp(
    r'^(jpg|jpeg|png|webp|heic)$',
  );
  static final RegExp _objectNamePattern = RegExp(
    r'^(original|display|model_input)\.(jpg|jpeg|png|webp|heic)$',
  );

  StorageService({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static String photoNoteObjectPath({
    required String userId,
    required String mediaAssetId,
    PhotoNoteMediaVariant variant = PhotoNoteMediaVariant.display,
    String extension = 'jpg',
  }) {
    final owner = _requireUuid(userId, 'userId');
    final media = _requireUuid(mediaAssetId, 'mediaAssetId');
    final normalizedExtension = extension.trim().toLowerCase();
    if (!_extensionPattern.hasMatch(normalizedExtension)) {
      throw ArgumentError.value(
        extension,
        'extension',
        'must contain only letters and digits',
      );
    }
    final variantName = switch (variant) {
      PhotoNoteMediaVariant.original => 'original',
      PhotoNoteMediaVariant.display => 'display',
      PhotoNoteMediaVariant.modelInput => 'model_input',
    };
    return '$owner/$media/$variantName.$normalizedExtension';
  }

  /// Upload idempotent theo owner/media/variant và trả về object path riêng tư.
  Future<String> uploadPhotoNoteImage({
    required File imageFile,
    required String userId,
    required String mediaAssetId,
    PhotoNoteMediaVariant variant = PhotoNoteMediaVariant.display,
    String extension = 'jpg',
  }) async {
    final objectPath = photoNoteObjectPath(
      userId: userId,
      mediaAssetId: mediaAssetId,
      variant: variant,
      extension: extension,
    );
    try {
      await _supabaseClient.storage.from(bucketName).upload(
            objectPath,
            imageFile,
            fileOptions: FileOptions(
              cacheControl: '3600',
              upsert: true,
              contentType: _contentTypeForExtension(extension),
            ),
          );
      return objectPath;
    } catch (e) {
      debugPrint('Error uploading photo note image to Supabase Storage: $e');
      rethrow;
    }
  }

  Future<String> createSignedPhotoNoteUrl({
    required String userId,
    required String mediaAssetId,
    PhotoNoteMediaVariant variant = PhotoNoteMediaVariant.display,
    String extension = 'jpg',
    Duration validFor = const Duration(minutes: 15),
  }) {
    if (validFor.inSeconds <= 0) {
      throw ArgumentError.value(validFor, 'validFor', 'must be positive');
    }
    final objectPath = photoNoteObjectPath(
      userId: userId,
      mediaAssetId: mediaAssetId,
      variant: variant,
      extension: extension,
    );
    return _supabaseClient.storage
        .from(bucketName)
        .createSignedUrl(objectPath, validFor.inSeconds);
  }

  /// Tạo bản ghi Ghi chú ảnh mới trong bảng photo_notes
  Future<Map<String, dynamic>> savePhotoNoteRecord({
    required String userId,
    required String imagePath,
    required String noteTitle,
    String templateId = 'standard',
  }) async {
    final owner = _requireUuid(userId, 'userId');
    _requireOwnedObjectPath(imagePath, owner);
    final response = await _supabaseClient
        .from(_photoNotesTable)
        .insert({
          'user_id': owner,
          'image_path': imagePath,
          'template_id': templateId,
          'note_title': noteTitle,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return response;
  }

  /// Lấy danh sách album photo notes của user
  Future<List<Map<String, dynamic>>> getUserPhotoNotes(String userId) async {
    final owner = _requireUuid(userId, 'userId');
    final response = await _supabaseClient
        .from(_photoNotesTable)
        .select()
        .eq('user_id', owner)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}

String _requireUuid(String value, String fieldName) {
  final normalized = value.trim().toLowerCase();
  if (!StorageService._uuidPattern.hasMatch(normalized)) {
    throw ArgumentError.value(value, fieldName, 'must be a UUID');
  }
  return normalized;
}

void _requireOwnedObjectPath(String value, String owner) {
  final segments = value.split('/');
  if (segments.length != 3 ||
      segments.first != owner ||
      !StorageService._uuidPattern.hasMatch(segments[1]) ||
      !StorageService._objectNamePattern.hasMatch(segments[2])) {
    throw ArgumentError.value(
      value,
      'imagePath',
      'must match {userId}/{mediaAssetId}/{variant}.{extension}',
    );
  }
}

String _contentTypeForExtension(String extension) {
  return switch (extension.trim().toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    _ => throw ArgumentError.value(extension, 'extension', 'is unsupported'),
  };
}
