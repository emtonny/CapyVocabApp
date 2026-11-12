import '../entities/friend_entity.dart';

abstract interface class FriendsRemoteGateway {
  Stream<FriendRemoteSignal> get signals;

  Future<FriendConnection?> searchFriend({
    required FriendSearchMethod method,
    required String query,
  });

  Future<FriendDiscoverySettings> getDiscoverySettings();

  Future<FriendDiscoverySettings> updateDiscoverySettings({
    required bool discoverableByEmail,
    required bool discoverableByPhone,
  });

  Future<void> syncVerifiedPhone();

  Future<FriendMutationResult> sendRequest(String targetUserId);

  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  });

  Future<FriendPage> listRequests({
    required FriendRequestDirection direction,
    FriendCursor? cursor,
    int limit = 100,
  });

  Future<FriendPage> listAccepted({
    FriendCursor? cursor,
    int limit = 100,
  });

  Future<void> dispose();
}

abstract interface class FriendsRepository {
  Stream<FriendRemoteSignal> get remoteSignals;

  Stream<List<FriendConnection>> watchCached(FriendListKind kind);

  Future<List<FriendConnection>> readCached(FriendListKind kind);

  Future<void> refresh(FriendListKind kind);

  Future<FriendConnection?> searchFriend({
    required FriendSearchMethod method,
    required String query,
  });

  Future<FriendDiscoverySettings> getDiscoverySettings();

  Future<FriendDiscoverySettings> updateDiscoverySettings({
    required bool discoverableByEmail,
    required bool discoverableByPhone,
  });

  Future<void> syncVerifiedPhone();

  Future<FriendMutationResult> sendRequest(String targetUserId);

  Future<FriendMutationResult> respondToRequest({
    required String requesterId,
    required FriendDecision decision,
  });

  Future<void> dispose();
}
