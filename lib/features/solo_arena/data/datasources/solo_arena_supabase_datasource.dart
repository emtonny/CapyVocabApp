import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/supabase_service.dart';

/// Supabase Data Source cho Solo Arena (Thách đấu từ vựng 1v1 Realtime)
class SoloArenaSupabaseDataSource {
  final SupabaseClient _supabaseClient;

  SoloArenaSupabaseDataSource({SupabaseClient? supabaseClient})
      : _supabaseClient = supabaseClient ?? SupabaseService.client;

  static const String _matchesTable = 'solo_arena_matches';

  /// Tạo phòng thách đấu 1v1 mới
  Future<String> createMatch({
    required String hostUserId,
    required int betCoins,
  }) async {
    final response = await _supabaseClient
        .from(_matchesTable)
        .insert({
          'host_user_id': hostUserId,
          'guest_user_id': null,
          'bet_amount': betCoins,
          'status': 'waiting', // waiting, in_progress, completed, cancelled
          'host_score': 0,
          'guest_score': 0,
          'winner_id': null,
          'matched_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Tham gia vào phòng đấu có sẵn
  Future<void> joinMatch({
    required String matchId,
    required String guestUserId,
  }) async {
    await _supabaseClient.from(_matchesTable).update({
      'guest_user_id': guestUserId,
      'status': 'in_progress',
    }).eq('id', matchId);
  }

  /// Cập nhật điểm số khi trả lời câu hỏi trong trận đấu
  Future<void> updateMatchScore({
    required String matchId,
    required bool isHost,
    required int newScore,
  }) async {
    final fieldToUpdate = isHost ? 'host_score' : 'guest_score';

    await _supabaseClient.from(_matchesTable).update({
      fieldToUpdate: newScore,
    }).eq('id', matchId);
  }

  /// Hoàn tất trận đấu và chốt người chiến thắng
  Future<void> finishMatch({
    required String matchId,
    required String? winnerUserId,
  }) async {
    await _supabaseClient.from(_matchesTable).update({
      'status': 'completed',
      'winner_id': winnerUserId,
      'finished_at': DateTime.now().toIso8601String(),
    }).eq('id', matchId);
  }

  /// Stream thông tin trận đấu Realtime sử dụng Supabase Realtime Channel (onPostgresChanges)
  Stream<Map<String, dynamic>?> streamMatchState(String matchId) {
    final controller = StreamController<Map<String, dynamic>?>();

    // Fetch dữ liệu ban đầu
    _supabaseClient
        .from(_matchesTable)
        .select()
        .eq('id', matchId)
        .maybeSingle()
        .then((initialData) {
      if (!controller.isClosed) {
        controller.add(initialData);
      }
    });

    // Lắng nghe thay đổi Postgres Realtime Channel
    final channel = _supabaseClient
        .channel('public:solo_arena_matches:$matchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _matchesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: matchId,
          ),
          callback: (payload) {
            if (!controller.isClosed && payload.newRecord.isNotEmpty) {
              controller.add(payload.newRecord);
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
