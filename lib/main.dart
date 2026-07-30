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

  var isSupabaseConnected = false;

  try {
    await SupabaseService.initialize();
    isSupabaseConnected = await SupabaseService.testConnection();
  } catch (e) {
    debugPrint('❌ Supabase error: $e');
  }

  runApp(
    ProviderScope(
      child: SupabaseHealthGate(
        initiallyConnected: isSupabaseConnected,
      ),
    ),
  );
}

class SupabaseHealthGate extends StatefulWidget {
  const SupabaseHealthGate({
    required this.initiallyConnected,
    super.key,
  });

  final bool initiallyConnected;

  @override
  State<SupabaseHealthGate> createState() => _SupabaseHealthGateState();
}

class _SupabaseHealthGateState extends State<SupabaseHealthGate> {
  late bool _isConnected;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.initiallyConnected;
  }

  Future<void> _retryConnection() async {
    setState(() => _isRetrying = true);

    final isConnected = await SupabaseService.testConnection();
    if (!mounted) return;

    setState(() {
      _isConnected = isConnected;
      _isRetrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isConnected) {
      return const CapyVocabApp();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 64,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Không thể kết nối đến máy chủ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Vui lòng kiểm tra kết nối mạng rồi thử lại.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isRetrying ? null : _retryConnection,
                  child: _isRetrying
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
