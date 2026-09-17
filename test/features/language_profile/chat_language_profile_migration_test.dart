import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/20260914120000_add_chat_language_profiles.sql',
    ).readAsStringSync();
  });

  test('migration is owner-scoped and does not guess existing profiles', () {
    expect(sql, contains('CREATE TABLE public.user_language_profiles'));
    expect(sql, contains('ENABLE ROW LEVEL SECURITY'));
    expect(sql, contains('(SELECT auth.uid()) = user_id'));
    expect(sql,
        isNot(contains('INSERT INTO public.user_language_profiles\nSELECT')));
    expect(sql, contains("native_language_code IN ('vi', 'en')"));
    expect(sql, contains('native_language_code <> learning_language_code'));
    expect(sql, contains('BEFORE UPDATE ON public.user_language_profiles'));
    expect(sql, contains('NEW.updated_at = NOW()'));
  });

  test('new onboarding overload persists the language pair atomically', () {
    expect(sql, contains('p_native_language_code TEXT'));
    expect(sql, contains('p_learning_language_code TEXT'));
    expect(sql, contains('p_proficiency_level TEXT'));
    expect(sql, contains('ON CONFLICT (user_id) DO UPDATE'));
    expect(
      sql,
      contains(
        'TEXT, TEXT, INT, TEXT, TEXT, TEXT, TEXT, INT, TEXT, TEXT, TEXT',
      ),
    );
    expect(sql, contains('Keep the existing 8-argument RPC'));
  });
}
