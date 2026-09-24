import 'package:capy_vocab/features/auth/domain/account_phone.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chuẩn hóa số quốc tế mà không tự đoán mã quốc gia', () {
    expect(normalizeAccountPhone(' +84 987-654-321 '), '+84987654321');
    expect(normalizeAccountPhone('+1 (415) 555-2671'), '+14155552671');
    expect(normalizeAccountPhone('0987654321'), isNull);
    expect(normalizeAccountPhone('+01234567'), isNull);
    expect(normalizeAccountPhone('+123456'), isNull);
    expect(normalizeAccountPhone('+1234567890123456'), isNull);
  });

  test('che số điện thoại nhưng giữ mã gọi và bốn số cuối', () {
    expect(maskAccountPhone('+84987654321'), '+84 ••• 4321');
    expect(maskAccountPhone('invalid'), '••••••••');
  });
}
