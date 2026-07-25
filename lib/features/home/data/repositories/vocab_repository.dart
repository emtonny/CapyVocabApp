import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Repository quản lý Bài học (lessons), Từ vựng (vocabularies) & Tiến trình SRS (user_vocab_progress)
class VocabRepository {
  final SupabaseClient _supabaseClient;

  VocabRepository({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static const String _lessonsTable = 'lessons';
  static const String _vocabulariesTable = 'vocabularies';
  static const String _progressTable = 'user_vocab_progress';

  /// Lấy danh sách tất cả bài học
  Future<List<Map<String, dynamic>>> getLessons() async {
    final response = await _supabaseClient
        .from(_lessonsTable)
        .select()
        .order('order_index', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Lấy danh sách từ vựng của 1 bài học
  Future<List<Map<String, dynamic>>> getVocabulariesByLesson(
    String lessonId,
  ) async {
    final response = await _supabaseClient
        .from(_vocabulariesTable)
        .select()
        .eq('lesson_id', lessonId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Lấy tiến trình ôn tập SRS của User
  Future<List<Map<String, dynamic>>> getUserVocabProgress(String userId) async {
    final response = await _supabaseClient
        .from(_progressTable)
        .select('*, vocabularies(*)')
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Cập nhật tiến trình thuộc bài SRS
  Future<void> updateVocabProgress({
    required String userId,
    required String vocabId,
    required int masteryLevel,
    required DateTime nextReviewAt,
  }) async {
    final existing = await _supabaseClient
        .from(_progressTable)
        .select('review_count')
        .eq('user_id', userId)
        .eq('vocab_id', vocabId)
        .maybeSingle();

    final int currentReviewCount =
        (existing?['review_count'] as num?)?.toInt() ?? 0;

    await _supabaseClient.from(_progressTable).upsert({
      'user_id': userId,
      'vocab_id': vocabId,
      'mastery_level': masteryLevel,
      'review_count': currentReviewCount + 1,
      'last_reviewed_at': DateTime.now().toIso8601String(),
      'next_review_at': nextReviewAt.toIso8601String(),
    });
  }
}
