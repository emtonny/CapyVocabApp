import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/friend_entity.dart';
import '../../domain/friend_shared_contact.dart';
import 'friends_provider.dart';

final friendContactProvider = FutureProvider.autoDispose
    .family<FriendSharedContact, FriendSharedContactRequest>(
  (ref, request) async {
    if (ref.watch(friendsOwnerProvider) != request.owner) {
      throw const FriendRefreshSuperseded();
    }
    final client = ref.watch(friendsClientProvider);
    final response = await client.rpc(
      'get_accepted_friend_contact',
      params: {'p_friend_id': request.friendId},
    );
    if (ref.read(friendsOwnerProvider) != request.owner) {
      throw const FriendRefreshSuperseded();
    }
    if (response is! List || response.length != 1 || response.first is! Map) {
      throw const FriendDataException(
        'The contact response was not a single row.',
      );
    }
    final row = Map<String, dynamic>.from(response.first as Map);
    return FriendSharedContact(
      email: _optionalContact(row['email']),
      phone: _optionalContact(row['phone']),
    );
  },
);

String? _optionalContact(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FriendDataException('The shared contact value was invalid.');
  }
  return value.trim();
}
