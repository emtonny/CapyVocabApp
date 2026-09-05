import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('email xác nhận và khôi phục có branding và link Supabase hợp lệ', () {
    final confirmation =
        File('supabase/templates/confirmation.html').readAsStringSync();
    final recovery =
        File('supabase/templates/recovery.html').readAsStringSync();

    for (final template in [confirmation, recovery]) {
      expect(template, contains('lang="vi"'));
      expect(template, contains('Deery Vocab'));
      expect(template, contains('{{ .ConfirmationURL }}'));
      expect(template, isNot(contains('{{ .SiteURL }}/assets')));
    }

    expect(recovery, contains('Đặt lại mật khẩu'));
  });
}
