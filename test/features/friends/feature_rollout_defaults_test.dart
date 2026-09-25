import 'package:capy_vocab/features/chat/presentation/operational_chat_provider.dart';
import 'package:capy_vocab/features/friends/presentation/providers/friends_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Friends và Chat được bật mặc định cho build đủ điều kiện', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(friendsEnabledProvider), isTrue);
    expect(container.read(operationalChatEnabledProvider), isTrue);
  });
}
