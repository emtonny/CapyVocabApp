import 'package:capy_vocab/core/routes/app_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('recovery chỉ kết thúc khi đăng nhập mới, đăng xuất hoặc khởi tạo lại',
      () {
    var recovering = nextPasswordRecoveryState(
      current: false,
      event: AuthChangeEvent.passwordRecovery,
    );
    expect(recovering, isTrue);

    recovering = nextPasswordRecoveryState(
      current: recovering,
      event: AuthChangeEvent.userUpdated,
    );
    expect(recovering, isTrue);

    recovering = nextPasswordRecoveryState(
      current: recovering,
      event: AuthChangeEvent.signedOut,
    );
    expect(recovering, isFalse);
  });
}
