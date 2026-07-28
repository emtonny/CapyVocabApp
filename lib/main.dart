import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/supabase_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Dotenv load warning: $e');
  }

  try {
    await SupabaseService.initialize();
    await SupabaseService.testConnection();
  } catch (e) {
    debugPrint('❌ Supabase error: $e');
  }

  runApp(const ProviderScope(child: CapyVocabApp()));
}
