import 'package:capy_vocab/features/home/data/remote/streak_flame_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final row = <String, Object?>{
    'user_id': 'owner',
    'streak_days': 8,
    'incremented': true,
    'updated_at': '2026-10-08T08:00:00Z'
  };
  test('decodes confirmed streak and duplicate-day result', () {
    expect(streakFlameFromRpc([row], 'owner').streakDays, 8);
    expect(
        streakFlameFromRpc([
          {...row, 'incremented': false}
        ], 'owner')
            .incremented,
        isFalse);
  });
  test('rejects another account and malformed server counts', () {
    for (final response in [
      [],
      [row, row],
      [
        {...row, 'user_id': 'other'}
      ],
      [
        {...row, 'streak_days': -1}
      ],
      [
        {...row, 'streak_days': 1.5}
      ],
      [
        {...row, 'updated_at': 'invalid'}
      ],
      [
        {...row, 'incremented': 1}
      ]
    ]) {
      expect(
          () => streakFlameFromRpc(response, 'owner'), throwsFormatException);
    }
  });
}
