import 'package:capy_vocab/core/services/storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const userId = '11111111-1111-4111-8111-111111111111';
  const mediaId = '22222222-2222-4222-8222-222222222222';

  test('tạo private object key xác định theo owner và media asset', () {
    expect(
      StorageService.photoNoteObjectPath(
        userId: userId,
        mediaAssetId: mediaId,
      ),
      '$userId/$mediaId/display.jpg',
    );
    expect(
      StorageService.photoNoteObjectPath(
        userId: userId.toUpperCase(),
        mediaAssetId: mediaId.toUpperCase(),
        variant: PhotoNoteMediaVariant.modelInput,
        extension: 'JPEG',
      ),
      '$userId/$mediaId/model_input.jpeg',
    );
  });

  test('object key từ chối id và extension có thể thoát owner prefix', () {
    expect(
      () => StorageService.photoNoteObjectPath(
        userId: '../another-user',
        mediaAssetId: mediaId,
      ),
      throwsArgumentError,
    );
    expect(
      () => StorageService.photoNoteObjectPath(
        userId: userId,
        mediaAssetId: mediaId,
        extension: '../png',
      ),
      throwsArgumentError,
    );
    expect(
      () => StorageService.photoNoteObjectPath(
        userId: userId,
        mediaAssetId: mediaId,
        extension: 'exe',
      ),
      throwsArgumentError,
    );
  });

  test('signed URL từ chối thời hạn nhỏ hơn một giây trước network call', () {
    final service = StorageService(
      supabaseClient: SupabaseClient('https://example.supabase.co', 'anon-key'),
    );

    expect(
      () => service.createSignedPhotoNoteUrl(
        userId: userId,
        mediaAssetId: mediaId,
        validFor: const Duration(milliseconds: 500),
      ),
      throwsArgumentError,
    );
  });

  test('legacy metadata writer từ chối URL public và path traversal', () async {
    final service = StorageService(
      supabaseClient: SupabaseClient('https://example.supabase.co', 'anon-key'),
    );

    for (final imagePath in [
      'https://example.supabase.co/public/photo.jpg',
      '$userId/../display.jpg',
    ]) {
      await expectLater(
        service.savePhotoNoteRecord(
          userId: userId,
          imagePath: imagePath,
          noteTitle: 'Test',
        ),
        throwsArgumentError,
      );
    }
  });
}
