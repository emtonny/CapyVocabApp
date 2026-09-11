import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const baselinePath = 'supabase/migrations/20260725204011_initial_schema.sql';
  const migrationPath =
      'supabase/migrations/20260903120000_add_library_cloud_storage_contract.sql';
  late String baseline;
  late String migration;
  late String pullMigration;
  late String schemaSnapshot;
  late String productionAuditHarness;
  late String productionRollout;

  setUpAll(() async {
    baseline = await File(baselinePath).readAsString();
    migration = await File(migrationPath).readAsString();
    pullMigration = await File(
      'supabase/migrations/20260910120000_add_library_cloud_pull_feed.sql',
    ).readAsString();
    schemaSnapshot = await File(
      'supabase/schema/supabase_schema_final_secure.sql',
    ).readAsString();
    productionAuditHarness = await File(
      'tool/audit_supabase_library_rollout.ps1',
    ).readAsString();
    productionRollout = await File(
      'docs/data/production_library_rollout.md',
    ).readAsString();
  });

  test('Production rollout audit chỉ có read/list và không sửa migration', () {
    expect(productionAuditHarness, contains("[ValidateSet('GET', 'POST')]"));
    expect(
      productionAuditHarness,
      contains('/storage/v1/object/list/\$bucketName'),
    );
    expect(productionAuditHarness, contains('service_role_read_only'));
    expect(
      productionAuditHarness,
      isNot(matches(
          RegExp(r'-Method\s+(DELETE|PATCH|PUT)', caseSensitive: false))),
    );
    expect(productionAuditHarness, isNot(contains('migration repair')));
    expect(productionAuditHarness, isNot(contains('db push')));
  });

  test('Production rollout ghi đúng Gate 3 và giữ client sync mặc định off',
      () {
    expect(
      productionRollout,
      contains('GATE 3 COMPLETE / PRODUCTION CLOUD CONTRACT VERIFIED'),
    );
    expect(productionRollout, contains('Production history now matches'));
    expect(productionRollout, contains('Full Library flow'));
    expect(productionRollout, contains('Auth fixture marker count was 0'));
    expect(productionRollout, contains('Conditional legacy backfill'));
    expect(productionRollout, contains('Operational rollback'));
    expect(productionRollout, contains('LIBRARY_SYNC_ENABLED=false'));
  });

  test('M4.5 change feed is owner-scoped and contains no binary payload', () {
    expect(pullMigration,
        contains('create table if not exists public.library_change_events'));
    expect(pullMigration, contains('generated always as identity'));
    expect(pullMigration, contains('library_change_events_owner_sequence'));
    expect(pullMigration, contains('(select auth.uid()) = user_id'));
    expect(pullMigration, contains('security invoker'));
    expect(pullMigration, contains('p_after_sequence'));
    expect(pullMigration, contains('p_limit > 500'));
    expect(pullMigration,
        contains('grant execute on function public.pull_library_delta'));
    expect(pullMigration, isNot(contains('bytea')));
    expect(pullMigration, isNot(contains('service_role')));
  });

  test('M4.5 captures hard deletes and returns normalized JSON metadata', () {
    for (final table in [
      'media_assets',
      'scan_runs',
      'vocab_detections',
      'vocab_annotations',
      'photo_notes',
    ]) {
      expect(pullMigration, contains('trg_${table}_library_change'));
    }
    expect(pullMigration, contains("tg_op = 'DELETE'"));
    expect(pullMigration, contains("'deletions', deletion_rows"));
    expect(pullMigration, contains('jsonb_agg(to_jsonb(s)'));
    expect(pullMigration, contains("'media_assets'"));
    expect(pullMigration, contains("'photo_notes'"));
  });

  test('migration chain có baseline trước mọi migration tăng dần', () async {
    final migrationFiles = await Directory('supabase/migrations')
        .list()
        .where((entry) => entry is File && entry.path.endsWith('.sql'))
        .map((entry) => entry.uri.pathSegments.last)
        .toList()
      ..sort();

    expect(migrationFiles.first, '20260725204011_initial_schema.sql');
    for (final table in [
      'users',
      'user_settings',
      'photo_notes',
      'subscriptions',
      'notifications',
    ]) {
      expect(baseline, contains('create table if not exists public.$table'));
    }
    expect(baseline, isNot(contains('media_assets')));
    expect(baseline, isNot(contains('ai_scan_requests')));
    expect(
      baseline,
      contains("values ('photo_notes', 'photo_notes', true)"),
    );
  });

  test('M3A migration định nghĩa đủ normalized cloud evidence', () {
    for (final table in [
      'media_assets',
      'scan_runs',
      'vocab_detections',
      'vocab_annotations',
    ]) {
      expect(migration, contains('create table if not exists public.$table'));
      expect(migration,
          contains('alter table public.$table enable row level security'));
    }
    expect(migration, contains('raw_response_json jsonb'));
    expect(migration, contains('unique (user_id, request_id)'));
    expect(migration, contains('photo_notes_media_asset_owner_fkey'));
    expect(migration, contains('photo_notes_primary_scan_owner_fkey'));
  });

  test('M3A migration khóa bucket theo authenticated owner', () {
    expect(
      migration,
      contains("values ('photo_notes', 'photo_notes', false)"),
    );
    expect(
        migration, contains('on conflict (id) do update set public = false'));
    expect(migration, contains('(storage.foldername(name))[1]'));
    expect(migration, contains('(select auth.uid())::text'));
    for (final action in ['read', 'upload', 'update', 'delete']) {
      expect(
        migration,
        contains('Users $action their own photo note media'),
      );
    }
    expect(
      migration,
      isNot(contains('for select using (bucket_id = \'photo_notes\')')),
      reason: 'không được khôi phục public bucket listing policy cũ',
    );
  });

  test('schema snapshot phản ánh cloud contract private của M3A', () {
    for (final table in [
      'media_assets',
      'scan_runs',
      'vocab_detections',
      'vocab_annotations',
    ]) {
      expect(
        schemaSnapshot,
        contains('CREATE TABLE IF NOT EXISTS public.$table'),
      );
    }
    expect(
      schemaSnapshot,
      contains("VALUES ('photo_notes', 'photo_notes', false)"),
    );
    expect(schemaSnapshot, isNot(contains('Public Access Photo Notes')));
    expect(schemaSnapshot, contains('Users delete their own photo note media'));
    expect(
      schemaSnapshot,
      contains('CREATE TABLE IF NOT EXISTS public.library_change_events'),
    );
    expect(schemaSnapshot, contains('public.pull_library_delta'));
  });
}
