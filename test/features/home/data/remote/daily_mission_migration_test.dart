import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/20260928120000_add_daily_mission_contract.sql',
  ).readAsStringSync();

  test('stores nullable account IANA timezone for safe existing-user rollout',
      () {
    expect(sql, contains('ADD COLUMN IF NOT EXISTS time_zone TEXT'));
    expect(sql, contains('pg_catalog.pg_timezone_names'));
    expect(sql, contains("position('/' IN p_name) > 1"));
    expect(sql, contains('time_zone IS NULL'));
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION private.is_supported_iana_time_zone(TEXT)',
      ),
    );
  });

  test('defines one immutable mission snapshot per account day', () {
    expect(sql, contains('CREATE TABLE public.daily_missions'));
    expect(sql, contains('PRIMARY KEY (user_id, mission_date)'));
    expect(sql, contains('target_words INTEGER NOT NULL'));
    expect(sql, contains('trg_daily_missions_immutable'));
    expect(sql, contains("ERRCODE = '55000'"));
  });

  test('allows authenticated owners to read but not mutate mission rows', () {
    expect(
        sql,
        contains(
            'ALTER TABLE public.daily_missions ENABLE ROW LEVEL SECURITY'));
    expect(sql, contains('USING ((SELECT auth.uid()) = user_id)'));
    expect(sql,
        contains('GRANT SELECT ON public.daily_missions TO authenticated'));
    expect(
      sql,
      isNot(matches(RegExp(
        r'GRANT\s+(?:INSERT|UPDATE|DELETE)',
        caseSensitive: false,
      ))),
    );
  });
}
