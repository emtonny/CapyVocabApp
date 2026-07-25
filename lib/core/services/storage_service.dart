import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service quản lý lưu trữ hình ảnh trên Supabase Storage (Bucket photo_notes)
class StorageService {
  final SupabaseClient _supabaseClient;
  static const String _bucketName = 'photo_notes';
  static const String _photoNotesTable = 'photo_notes';

  StorageService({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  /// Tải ảnh AI Vision scan lên Supabase Storage bucket và nhận URL public
  Future<String> uploadPhotoNoteImage({
    required File imageFile,
    required String userId,
  }) async {
    try {
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_note.jpg';

      await _supabaseClient.storage.from(_bucketName).upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      final String publicUrl =
          _supabaseClient.storage.from(_bucketName).getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading photo note image to Supabase Storage: $e');
      rethrow;
    }
  }

  /// Tạo bản ghi Ghi chú ảnh mới trong bảng photo_notes
  Future<Map<String, dynamic>> savePhotoNoteRecord({
    required String userId,
    required String imageUrl,
    required String noteTitle,
    String templateId = 'standard',
  }) async {
    final response = await _supabaseClient
        .from(_photoNotesTable)
        .insert({
          'user_id': userId,
          'image_path': imageUrl,
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
    final response = await _supabaseClient
        .from(_photoNotesTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }
}
