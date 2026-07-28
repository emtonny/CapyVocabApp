import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Supabase Service wrapper cho ứng dụng Capy Vocab
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => client.auth;

  static SupabaseStorageClient get storage => client.storage;

  /// Interface truy vấn bảng trong Supabase DB
  static SupabaseQueryBuilder from(String table) => client.from(table);

  /// Interface lắng nghe kênh Realtime
  static RealtimeChannel channel(String name) => client.channel(name);

  /// Khởi tạo Supabase Client đọc URL & ANON_KEY từ .env
  static Future<void> initialize() async {
    final String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      debugPrint(
        'WARNING: SUPABASE_URL hoặc SUPABASE_ANON_KEY chưa được cấu hình trong file .env!',
      );
    }

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      debug: kDebugMode,
    );

    debugPrint('SupabaseService đã khởi tạo thành công.');
  }

  /// Thử kết nối đến Supabase bằng cách query 1 bản ghi từ bảng 'vocabularies'
  static Future<bool> testConnection() async {
    try {
      await client.from('vocabularies').select().limit(1);
      debugPrint('✅ Supabase connected');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase error: $e');
      return false;
    }
  }
}
