import 'dart:convert';
import 'dart:io';

import 'package:capy_vocab/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('native file URI omits email redirect instead of reading origin', () {
    expect(defaultEmailRedirectTo(Uri.parse('file:///')), isNull);
  });

  test('Web URI uses only its HTTP origin', () {
    expect(
      defaultEmailRedirectTo(Uri.parse('https://demo.example/auth?code=1')),
      'https://demo.example',
    );
  });

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

  test('signUp dùng mobile deep link mặc định trên native runtime', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
      ),
    );
    final repository = AuthRepositoryImpl(supabaseClient: client);

    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final signUpFuture = repository.signUpWithEmailAndPassword(
      email: 'mobile@example.com',
      password: 'secret123',
      displayName: 'Mobile User',
    );
    final request = await server.first;

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{}');
    await request.response.close();
    await signUpFuture;

    expect(
      request.uri.queryParameters['redirect_to'],
      AuthRepositoryImpl.mobileLoginRedirectUrl,
    );
  });

  test('signUp nhận diện phản hồi identities rỗng là email đã tồn tại',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
      ),
    );
    final repository = AuthRepositoryImpl(supabaseClient: client);

    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final signUpFuture = repository.signUpWithEmailAndPassword(
      email: 'existing@example.com',
      password: 'secret123',
      displayName: 'Existing User',
    );
    final duplicateExpectation = expectLater(
      signUpFuture,
      throwsA(
        isA<AuthException>().having(
          (error) => error.code,
          'code',
          'user_already_exists',
        ),
      ),
    );
    final request = await server.first;
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({
        'id': 'obfuscated-user-id',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'aud': 'authenticated',
        'email': 'existing@example.com',
        'created_at': '2026-09-05T00:00:00.000Z',
        'identities': <dynamic>[],
      }));
    await request.response.close();
    await duplicateExpectation;
  });

  test('password reset dùng mobile deep link trên native runtime', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
      ),
    );
    final repository = AuthRepositoryImpl(supabaseClient: client);

    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final resetFuture = repository.sendPasswordResetEmail('mobile@example.com');
    final request = await server.first;

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{}');
    await request.response.close();
    await resetFuture;

    expect(request.uri.path, '/auth/v1/recover');
    expect(
      request.uri.queryParameters['redirect_to'],
      AuthRepositoryImpl.mobileResetRedirectUrl,
    );
  });

  test('password reset dùng redirect URL được cấu hình', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
      ),
    );
    const redirectUrl = 'https://demo.capy-vocab.example/reset-password';
    final repository = AuthRepositoryImpl(
      supabaseClient: client,
      passwordResetRedirectTo: redirectUrl,
    );

    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });

    final resetFuture = repository.sendPasswordResetEmail('web@example.com');
    final request = await server.first;
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('{}');
    await request.response.close();
    await resetFuture;

    expect(request.uri.path, '/auth/v1/recover');
    expect(request.uri.queryParameters['redirect_to'], redirectUrl);
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
