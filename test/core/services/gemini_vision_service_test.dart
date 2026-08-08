import 'dart:convert';

import 'package:capy_vocab/core/services/gemini_vision_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _testEndpoint = Uri.parse(
  'https://test-project.supabase.co/functions/v1/gemini-vision-scan',
);

void main() {
  test('endpoint mặc định dùng đúng project host từ Supabase runtime',
      () async {
    late Uri capturedUrl;
    final service = GeminiVisionService(
      httpClient: MockClient((request) async {
        capturedUrl = request.url;
        return http.Response(jsonEncode({'words': []}), 200);
      }),
      accessTokenProvider: () => 'valid-user-jwt',
      supabaseRestUrlProvider: () =>
          'https://configured-project.supabase.co/rest/v1',
    );

    await service.analyzeBase64Image('compressed-base64');

    expect(
      capturedUrl,
      Uri.parse(
        'https://configured-project.supabase.co/functions/v1/'
        'gemini-vision-scan',
      ),
    );
  });

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
      endpoint: _testEndpoint,
    );

    final result = await service.analyzeBase64Image('compressed-base64');

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url, _testEndpoint);
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
      endpoint: _testEndpoint,
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
          endpoint: _testEndpoint,
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
      endpoint: _testEndpoint,
    );

    await expectLater(
      service.analyzeBase64Image('image'),
      throwsA(isA<GeminiInvalidResponseException>()),
    );
  });

  test('bounding box chạm biên phải và dưới vẫn hợp lệ', () {
    final result = GeminiVisionResult.fromJson({
      'words': [
        {
          'word': 'edge',
          'phonetic': '/edʒ/',
          'meaning_vi': 'cạnh',
          'box': {'x': 750, 'y': 800, 'w': 250, 'h': 200},
        },
      ],
    });

    expect(result.words.single.x + result.words.single.w, 1.0);
    expect(result.words.single.y + result.words.single.h, 1.0);
  });

  final overflowingBoxes = <Map<String, int>>[
    {'x': 800, 'y': 100, 'w': 201, 'h': 100},
    {'x': 100, 'y': 900, 'w': 100, 'h': 101},
  ];

  for (final box in overflowingBoxes) {
    test('bounding box tràn biên ảnh bị từ chối: $box', () {
      expect(
        () => GeminiVisionResult.fromJson({
          'words': [
            {
              'word': 'overflow',
              'phonetic': '/ˌəʊvəˈfləʊ/',
              'meaning_vi': 'tràn',
              'box': box,
            },
          ],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'Word box must stay within the 0-1000 image bounds.',
          ),
        ),
      );
    });
  }
}
