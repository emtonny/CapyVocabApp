import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/'
    '20260917120000_merge_onboarding_language_contracts.sql',
  ).readAsStringSync();

  test('combined onboarding overload persists both language contracts', () {
    expect(sql, contains('p_interface_locale TEXT'));
    expect(sql, contains('p_learning_locale TEXT'));
    expect(sql, contains('p_native_language_code TEXT'));
    expect(sql, contains('p_learning_language_code TEXT'));
    expect(sql, contains('p_proficiency_level TEXT'));
    expect(
      RegExp(r'private\.complete_onboarding_for_current_user\(')
          .allMatches(sql),
      hasLength(2),
    );
    expect(sql, contains('SECURITY INVOKER'));
    expect(sql, contains('TO authenticated'));
  });
}
