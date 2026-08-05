import 'dart:convert';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('gửi JWT, base64 và chuẩn hóa box 0-1000', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'words': [
            {
              'word': 'apple',
              'phonetic': '/ˈæp.əl/',
              'meaning_vi': 'quả táo',
              'box': {'x': 125, 'y': 250, 'w': 500, 'h': 100},
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = GeminiVisionService(
      httpClient: client,
      accessTokenProvider: () => 'valid-user-jwt',
    );

    final result = await service.analyzeBase64Image('compressed-base64');

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url, GeminiVisionService.endpoint);
    expect(
      capturedRequest.headers['authorization'],
      'Bearer valid-user-jwt',
    );
    expect(
      jsonDecode(capturedRequest.body),
      {'image_base64': 'compressed-base64'},
    );
    expect(result.words, hasLength(1));
    expect(result.words.single.word, 'apple');
    expect(result.words.single.meaningVi, 'quả táo');
    expect(result.words.single.x, 0.125);
    expect(result.words.single.y, 0.25);
    expect(result.words.single.w, 0.5);
    expect(result.words.single.h, 0.1);
    expect(
      result.toJson()['words'],
      [
        {
          'word': 'apple',
          'phonetic': '/ˈæp.əl/',
          'meaning_vi': 'quả táo',
          'box': {'x': 125, 'y': 250, 'w': 500, 'h': 100},
        },
      ],
    );
  });

  test('không gửi request khi không có access token', () async {
    var requestCount = 0;
    final service = GeminiVisionService(
      httpClient: MockClient((request) async {
        requestCount++;
        return http.Response('{}', 200);
      }),
      accessTokenProvider: () => null,
    );

    await expectLater(
      service.analyzeBase64Image('image'),
      throwsA(
        isA<GeminiAuthenticationException>().having(
          (error) => error.message,
          'message',
          'Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại.',
        ),
      ),
    );
    expect(requestCount, 0);
  });

  final errorCases = <({
    int status,
    String code,
    Type type,
    String message,
  })>[
    (
      status: 429,
      code: 'quota_exceeded',
      type: GeminiQuotaException,
      message: 'Hệ thống đang bận, thử lại sau',
    ),
    (
      status: 422,
      code: 'truncated_response',
      type: GeminiRecognitionException,
      message: 'Không nhận diện được, thử ảnh khác',
    ),
    (
      status: 422,
      code: 'empty_response',
      type: GeminiRecognitionException,
      message: 'Không nhận diện được, thử ảnh khác',
    ),
    (
      status: 504,
      code: 'timeout',
      type: GeminiTimeoutException,
      message: 'Quá thời gian chờ, thử lại',
    ),
    (
      status: 413,
      code: 'image_too_large',
      type: GeminiImageTooLargeException,
      message: 'Ảnh quá lớn, vui lòng chọn ảnh khác',
    ),
    (
      status: 500,
      code: 'internal_error',
      type: GeminiApiException,
      message: 'Đã có lỗi, thử lại',
    ),
    (
      status: 502,
      code: 'upstream_error',
      type: GeminiApiException,
      message: 'Đã có lỗi, thử lại',
    ),
  ];

  for (final errorCase in errorCases) {
    test(
      'HTTP ${errorCase.status} ${errorCase.code} được ánh xạ riêng',
      () async {
        final service = GeminiVisionService(
          httpClient: MockClient(
            (request) async => http.Response(
              jsonEncode({'error': errorCase.code}),
              errorCase.status,
            ),
          ),
          accessTokenProvider: () => 'valid-user-jwt',
        );

        try {
          await service.analyzeBase64Image('image');
          fail('Expected a GeminiVisionException.');
        } catch (error) {
          expect(error.runtimeType, errorCase.type);
          expect((error as GeminiVisionException).message, errorCase.message);
        }
      },
    );
  }

  test('response 200 sai schema không bị coi là thành công rỗng', () async {
    final service = GeminiVisionService(
      httpClient: MockClient(
        (request) async => http.Response(jsonEncode({'words': 'invalid'}), 200),
      ),
      accessTokenProvider: () => 'valid-user-jwt',
    );

    await expectLater(
      service.analyzeBase64Image('image'),
      throwsA(isA<GeminiInvalidResponseException>()),
    );
  });
}
