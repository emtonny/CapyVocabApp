import 'dart:convert';
import 'dart:io';

import 'package:capy_vocab/features/onboarding/data/repositories/onboarding_repository.dart';
import 'package:capy_vocab/features/onboarding/domain/entities/onboarding_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  for (final testCase in <({
    String rpcName,
    String parameterName,
    String input,
    String expectedValue,
    Future<bool> Function(OnboardingRepository repository, String value) call,
  })>[
    (
      rpcName: 'check_username_available',
      parameterName: 'p_username',
      input: ' Capy_May ',
      expectedValue: 'capy_may',
      call: (repository, value) => repository.isUsernameAvailable(value),
    ),
    (
      rpcName: 'check_phone_available',
      parameterName: 'p_phone',
      input: ' 0987654321 ',
      expectedValue: '0987654321',
      call: (repository, value) => repository.isPhoneAvailable(value),
    ),
  ]) {
    test('gọi RPC ${testCase.rpcName} với tham số đã chuẩn hóa', () async {
      final harness = await _RepositoryHarness.create();
      addTearDown(harness.close);

      final resultFuture = testCase.call(harness.repository, testCase.input);
      final request = await harness.server.first;
      final body = jsonDecode(await utf8.decoder.bind(request).join())
          as Map<String, dynamic>;

      expect(request.uri.path, '/rest/v1/rpc/${testCase.rpcName}');
      expect(body, {testCase.parameterName: testCase.expectedValue});

      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write('true');
      await request.response.close();

      expect(await resultFuture, isTrue);
    });
  }

  test('gửi đủ giờ bắt đầu và kết thúc cho complete_onboarding', () async {
    final harness = await _RepositoryHarness.create();
    addTearDown(harness.close);

    final resultFuture = harness.repository.completeOnboarding(
      const OnboardingData(
        displayName: ' Capy Mây ',
        username: 'Capy_May',
        age: 20,
        phone: ' 0987654321 ',
        accountRole: 'personal',
        reminderTime: '20:00',
        studyEndTime: '21:00',
        dailyTargetWords: 10,
      ),
    );
    final request = await harness.server.first;
    final body = jsonDecode(await utf8.decoder.bind(request).join())
        as Map<String, dynamic>;

    expect(request.uri.path, '/rest/v1/rpc/complete_onboarding');
    expect(body['p_reminder_time'], '20:00');
    expect(body['p_study_end_time'], '21:00');

    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write('true');
    await request.response.close();

    await resultFuture;
  });

  for (final testCase in <({
    String constraintName,
    OnboardingConflictField expectedField,
    String expectedMessage,
  })>[
    (
      constraintName: 'users_username_key',
      expectedField: OnboardingConflictField.username,
      expectedMessage: 'Tên đăng nhập đã được sử dụng.',
    ),
    (
      constraintName: 'users_phone_key',
      expectedField: OnboardingConflictField.phone,
      expectedMessage: 'Số điện thoại đã được sử dụng.',
    ),
    (
      constraintName: 'users_email_key',
      expectedField: OnboardingConflictField.email,
      expectedMessage: 'Email đã được sử dụng.',
    ),
  ]) {
    test('phân loại 23505 của ${testCase.constraintName}', () async {
      final harness = await _RepositoryHarness.create();
      addTearDown(harness.close);

      final resultFuture = harness.repository.completeOnboarding(
        const OnboardingData(
          displayName: 'Capy Mây',
          username: 'capy_may',
          age: 20,
          phone: '0987654321',
          accountRole: 'personal',
          reminderTime: '20:00',
          studyEndTime: '21:00',
          dailyTargetWords: 10,
        ),
      );
      final expectation = expectLater(
        resultFuture,
        throwsA(
          isA<OnboardingRepositoryException>()
              .having(
                (error) => error.conflictingField,
                'conflictingField',
                testCase.expectedField,
              )
              .having(
                (error) => error.message,
                'message',
                contains(testCase.expectedMessage),
              ),
        ),
      );
      final request = await harness.server.first;

      expect(request.uri.path, '/rest/v1/rpc/complete_onboarding');
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = HttpStatus.conflict
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'code': '23505',
          'message':
              'duplicate key value violates unique constraint "${testCase.constraintName}"',
          'details': null,
          'hint': null,
        }));
      await request.response.close();

      await expectation;
    });
  }
}

class _RepositoryHarness {
  _RepositoryHarness({
    required this.server,
    required this.client,
  }) : repository = SupabaseOnboardingRepository(client: client);

  final HttpServer server;
  final SupabaseClient client;
  final OnboardingRepository repository;

  static Future<_RepositoryHarness> create() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient(
      'http://${server.address.address}:${server.port}',
      'sb_publishable_test',
      authOptions: const AuthClientOptions(
        pkceAsyncStorage: _MemoryGotrueAsyncStorage(),
      ),
    );
    return _RepositoryHarness(server: server, client: client);
  }

  Future<void> close() async {
    await client.dispose();
    await server.close(force: true);
  }
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
