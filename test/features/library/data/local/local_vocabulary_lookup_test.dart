import 'dart:io';

import 'package:capy_vocab/features/library/data/local/library_database.dart';
import 'package:capy_vocab/features/library/data/local/sqlite_library_store.dart';
import 'package:capy_vocab/features/library/domain/entities/local_vocabulary_match.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _owner = '10000000-0000-0000-0000-000000000001';
const _otherOwner = '10000000-0000-0000-0000-000000000002';
const _time = '2026-09-19T12:00:00.000Z';
const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  late Directory directory;
  late LibraryDatabase libraryDatabase;
  late Database database;
  late SqliteLibraryStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('chat_c6b_lookup_');
    libraryDatabase = LibraryDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}${Platform.pathSeparator}library.db',
    );
    database = await libraryDatabase.open();
    store = SqliteLibraryStore(
      database: database,
      idGenerator: () => '90000000-0000-0000-0000-000000000001',
    );
    await _seedVocabulary(
      database,
      owner: _owner,
      suffix: '1',
      meaning: 'cái cốc',
    );
    await _seedVocabulary(
      database,
      owner: _otherOwner,
      suffix: '2',
      meaning: 'không được lộ',
    );
  });

  tearDown(() async {
    await store.dispose();
    await libraryDatabase.close();
    await directory.delete(recursive: true);
  });

  test('lookup is offline, owner-scoped and normalizes selected punctuation',
      () async {
    final matches = await store.lookupLocalVocabulary(
      userId: _owner,
      query: '  CUP,  ',
    );

    expect(matches, hasLength(1));
    expect(matches.single.word, 'Cup');
    expect(matches.single.meaningVi, 'cái cốc');
    expect(matches.single.occurrenceCount, 1);
    expect(matches.single.corrected, isFalse);
  });

  test('latest active correction wins and trashed Photo Notes are excluded',
      () async {
    await database.insert('vocab_annotations', {
      'id': '60000000-0000-0000-0000-000000000001',
      'user_id': _owner,
      'detection_id': '50000000-0000-0000-0000-000000000001',
      'source': 'user_corrected',
      'quality_status': 'corrected',
      'corrected_word': 'Mug',
      'corrected_phonetic': '/mʌɡ/',
      'corrected_meaning_vi': 'cái ca',
      'revision': 2,
      'created_at': _time,
      'updated_at': _time,
    });

    expect(
      await store.lookupLocalVocabulary(userId: _owner, query: 'cup'),
      isEmpty,
    );
    final corrected =
        await store.lookupLocalVocabulary(userId: _owner, query: 'Mug!');
    expect(corrected, hasLength(1));
    expect(corrected.single.word, 'Mug');
    expect(corrected.single.phonetic, '/mʌɡ/');
    expect(corrected.single.meaningVi, 'cái ca');
    expect(corrected.single.corrected, isTrue);

    await database.update(
      'photo_notes',
      {'deleted_at': _time},
      where: 'id = ?',
      whereArgs: ['40000000-0000-0000-0000-000000000001'],
    );
    expect(
      await store.lookupLocalVocabulary(userId: _owner, query: 'mug'),
      isEmpty,
    );
  });

  test('query normalization keeps Unicode and rejects blank boundaries', () {
    expect(normalizeLocalVocabularyQuery(' “Café” '), 'café');
    expect(normalizeLocalVocabularyQuery('...'), isEmpty);
  });
}

Future<void> _seedVocabulary(
  Database database, {
  required String owner,
  required String suffix,
  required String meaning,
}) async {
  String id(String prefix) =>
      '${prefix}0000000-0000-0000-0000-00000000000$suffix';
  await database.insert('local_accounts', {
    'user_id': owner,
    'account_state': 'active',
    'created_at': _time,
    'updated_at': _time,
  });
  await database.insert('media_assets', {
    'id': id('2'),
    'user_id': owner,
    'content_hash_sha256': _sha,
    'display_relative_path': 'accounts/$owner/display.jpg',
    'mime_type': 'image/jpeg',
    'width': 100,
    'height': 100,
    'orientation': 0,
    'byte_size_display': 10,
    'preprocessing_version': 'v1',
    'capture_source': 'camera',
    'created_at': _time,
    'sync_status': 'local_only',
  });
  await database.insert('scan_runs', {
    'id': id('3'),
    'user_id': owner,
    'media_asset_id': id('2'),
    'request_id': 'request-$suffix',
    'provider': 'google_gemini',
    'model_name': 'gemini-flash',
    'prompt_version': 'prompt-v1',
    'response_schema_version': 'schema-v1',
    'preprocessing_version': 'v1',
    'raw_response_json': '{}',
    'response_hash_sha256': _sha,
    'status': 'succeeded',
    'started_at': _time,
    'completed_at': _time,
  });
  await database.insert('photo_notes', {
    'id': id('4'),
    'user_id': owner,
    'media_asset_id': id('2'),
    'primary_scan_run_id': id('3'),
    'title': 'Kitchen $suffix',
    'template_id': 'default-v1',
    'created_at': _time,
    'updated_at': _time,
    'sync_status': 'local_only',
  });
  await database.insert('vocab_detections', {
    'id': id('5'),
    'scan_run_id': id('3'),
    'word_raw': 'Cup',
    'word_normalized': 'cup',
    'phonetic': '/kʌp/',
    'meaning_vi': meaning,
    'part_of_speech': 'noun',
    'example_en': 'A cup of tea.',
    'example_vi': 'Một tách trà.',
    'display_order': 0,
    'created_at': _time,
  });
}
