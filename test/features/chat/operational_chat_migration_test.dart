import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Album label validator remains callable by chat insert roles', () async {
    final migration = await File(
      'supabase/migrations/'
      '20260930130000_restore_chat_label_validator_execute.sql',
    ).readAsString();

    expect(
      migration,
      contains(
        'grant execute on function '
        'private.valid_chat_album_image_labels(jsonb)',
      ),
    );
    expect(migration, contains('to authenticated, service_role'));
    expect(migration, isNot(contains('to public')));
    expect(migration, isNot(contains('to anon')));
  });
}
