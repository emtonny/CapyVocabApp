import 'dart:convert';
import 'dart:io';

import 'package:capy_vocab/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('signUp chuyển Web origin xuống Supabase làm redirect URL', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
      ),
    );
    const redirectUrl = 'https://demo.capy-vocab.example';
    final repository = AuthRepositoryImpl(
      supabaseClient: client,
      emailRedirectTo: redirectUrl,
    );

    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final signUpFuture = repository.signUpWithEmailAndPassword(
      email: 'an@example.com',
      password: 'secret123',
      displayName: 'Nguyễn Văn An',
    );
    final request = await server.first;
    final requestBody = jsonDecode(await utf8.decoder.bind(request).join())
        as Map<String, dynamic>;

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{}');
    await request.response.close();
    await signUpFuture;

    expect(request.uri.path, '/auth/v1/signup');
    expect(request.uri.queryParameters['redirect_to'], redirectUrl);
    expect(requestBody['data'], {'display_name': 'Nguyễn Văn An'});
  });
}

class _MemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  const _MemoryGotrueAsyncStorage();

  static final Map<String, String> _values = {};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<void> setItem({
    required String key,
    required String value,
  }) async {
    _values[key] = value;
  }
}
