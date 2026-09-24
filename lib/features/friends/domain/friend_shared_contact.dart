import 'entities/friend_entity.dart';

class FriendSharedContactRequest {
  const FriendSharedContactRequest({
    required this.owner,
    required this.friendId,
  });

  final FriendOwner owner;
  final String friendId;

  @override
  bool operator ==(Object other) =>
      other is FriendSharedContactRequest &&
      other.owner == owner &&
      other.friendId == friendId;

  @override
  int get hashCode => Object.hash(owner, friendId);
}

class FriendSharedContact {
  const FriendSharedContact({this.email, this.phone});

  final String? email;
  final String? phone;

  bool get isEmpty => email == null && phone == null;
}
