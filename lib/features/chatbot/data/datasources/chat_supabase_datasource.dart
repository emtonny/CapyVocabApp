import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Supabase Data Source cho Chatbot AI với Supabase Realtime Channel
class ChatSupabaseDataSource {
  final SupabaseClient _supabaseClient;

  ChatSupabaseDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static const String _chatMessagesTable = 'chat_messages';

  /// Lấy lịch sử nhắn tin với Trợ lý AI Capy
  Future<List<Map<String, dynamic>>> getChatHistory(String userId) async {
    final response = await _supabaseClient
        .from(_chatMessagesTable)
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Gửi tin nhắn mới (người dùng hoặc phản hồi từ AI)
  Future<Map<String, dynamic>> sendMessage({
    required String userId,
    required String message,
    required bool isAiResponse,
  }) async {
    final response = await _supabaseClient
        .from(_chatMessagesTable)
        .insert({
          'user_id': userId,
          'message': message,
          'is_ai_response': isAiResponse,
          'timestamp': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return response;
  }

  /// Stream tin nhắn Chat Realtime sử dụng Supabase Realtime Channel (onPostgresChanges)
  Stream<List<Map<String, dynamic>>> streamChatMessages(String userId) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    List<Map<String, dynamic>> currentMessages = [];

    // 1. Nạp lịch sử ban đầu
    getChatHistory(userId).then((messages) {
      currentMessages = messages;
      if (!controller.isClosed) {
        controller.add(List.from(currentMessages));
      }
    });

    // 2. Đăng ký Realtime Channel lắng nghe tin nhắn mới
    final channel = _supabaseClient
        .channel('public:chat_messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: _chatMessagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (!controller.isClosed && payload.newRecord.isNotEmpty) {
              currentMessages.add(payload.newRecord);
              controller.add(List.from(currentMessages));
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      _supabaseClient.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
