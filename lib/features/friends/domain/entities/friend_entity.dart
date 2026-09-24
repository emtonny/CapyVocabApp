final RegExp _friendUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);

String validateFriendUuid(String value, {required String field}) {
  final normalized = value.trim().toLowerCase();
  if (!_friendUuidPattern.hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'must be a valid UUID');
  }
  return normalized;
}

class FriendOwner {
  FriendOwner({required String projectRef, required String userId})
      : projectRef = _requiredText(projectRef, 'projectRef').toLowerCase(),
        userId = validateFriendUuid(userId, field: 'userId');

  final String projectRef;
  final String userId;

  String get scope => '$projectRef:$userId';

  @override
  bool operator ==(Object other) =>
      other is FriendOwner && other.scope == scope;

  @override
  int get hashCode => scope.hashCode;
}

enum FriendSearchMethod {
  username('username'),
  email('email'),
  phone('phone');

  const FriendSearchMethod(this.wireValue);

  final String wireValue;
}

enum FriendRelationshipState {
  none('none'),
  outgoingPending('outgoing_pending'),
  incomingPending('incoming_pending'),
  accepted('accepted'),
  rejected('rejected');

  const FriendRelationshipState(this.wireValue);

  final String wireValue;

  static FriendRelationshipState fromWire(Object? value) {
    return FriendRelationshipState.values.firstWhere(
      (state) => state.wireValue == value,
      orElse: () => throw const FriendDataException(
        'Invalid relationship state returned by the server.',
      ),
    );
  }
}

enum FriendRequestDirection {
  incoming('incoming'),
  outgoing('outgoing');

  const FriendRequestDirection(this.wireValue);

  final String wireValue;
}

enum FriendDecision {
  accept('accept'),
  reject('reject');

  const FriendDecision(this.wireValue);

  final String wireValue;
}

enum FriendListKind {
  incoming,
  outgoing,
  accepted;

  String get storageValue => name;

  FriendRelationshipState get relationshipState => switch (this) {
        FriendListKind.incoming => FriendRelationshipState.incomingPending,
        FriendListKind.outgoing => FriendRelationshipState.outgoingPending,
        FriendListKind.accepted => FriendRelationshipState.accepted,
      };
}

enum FriendMutationResult {
  outgoingPending('outgoing_pending'),
  incomingPending('incoming_pending'),
  alreadyAccepted('already_accepted'),
  accepted('accepted'),
  rejected('rejected');

  const FriendMutationResult(this.wireValue);

  final String wireValue;

  static FriendMutationResult fromWire(Object? value) {
    return FriendMutationResult.values.firstWhere(
      (result) => result.wireValue == value,
      orElse: () => throw const FriendDataException(
        'Invalid friend mutation result returned by the server.',
      ),
    );
  }
}

enum FriendRemoteSignal { connected, changed, disconnected }

enum FriendFailureKind {
  invalidInput,
  invalidUsername,
  invalidEmail,
  invalidPhone,
  phoneConflict,
  contactNotVerified,
  userNotFound,
  selfRequest,
  alreadyAccepted,
  incomingPending,
  staleRequest,
  offline,
  unauthenticated,
  denied,
  notFound,
  conflict,
  rateLimited,
  unavailable,
  invalidResponse,
}

class FriendException implements Exception {
  const FriendException(this.kind, this.message);

  final FriendFailureKind kind;
  final String message;

  @override
  String toString() => 'FriendException($kind, $message)';
}

class FriendDataException extends FriendException {
  const FriendDataException(String message)
      : super(FriendFailureKind.invalidResponse, message);
}

class FriendRefreshSuperseded extends FriendException {
  const FriendRefreshSuperseded()
      : super(
          FriendFailureKind.unauthenticated,
          'The active account changed during refresh.',
        );
}

class FriendPublicProfile {
  FriendPublicProfile({
    required String id,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.studyPoints,
    required this.streakDays,
    required this.userLevel,
  }) : id = validateFriendUuid(id, field: 'id') {
    if (studyPoints < 0 || streakDays < 0 || userLevel < 1) {
      throw ArgumentError('Profile counters are outside the valid range.');
    }
  }

  factory FriendPublicProfile.fromRemote(
    Map<String, dynamic> row, {
    String idKey = 'id',
  }) {
    return FriendPublicProfile(
      id: _requiredString(row, idKey),
      displayName: _optionalString(row, 'display_name'),
      username: _optionalString(row, 'username'),
      avatarUrl: _nullableString(row, 'avatar_url'),
      studyPoints: _requiredInt(row, 'study_points'),
      streakDays: _requiredInt(row, 'streak_days'),
      userLevel: _requiredInt(row, 'user_level'),
    );
  }

  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final int studyPoints;
  final int streakDays;
  final int userLevel;
}

class FriendConnection {
  const FriendConnection({
    required this.profile,
    required this.state,
    required this.updatedAt,
  });

  factory FriendConnection.fromSearchRemote(Map<String, dynamic> row) {
    return FriendConnection(
      profile: FriendPublicProfile.fromRemote(row),
      state: FriendRelationshipState.fromWire(row['relationship_state']),
      updatedAt: null,
    );
  }

  factory FriendConnection.fromRequestRemote(
    Map<String, dynamic> row, {
    required FriendRequestDirection expectedDirection,
  }) {
    if (row['direction'] != expectedDirection.wireValue) {
      throw const FriendDataException(
        'Friend request direction did not match the requested list.',
      );
    }
    return FriendConnection(
      profile: FriendPublicProfile.fromRemote(row, idKey: 'peer_id'),
      state: expectedDirection == FriendRequestDirection.incoming
          ? FriendRelationshipState.incomingPending
          : FriendRelationshipState.outgoingPending,
      updatedAt: _requiredDateTime(row, 'request_updated_at'),
    );
  }

  factory FriendConnection.fromAcceptedRemote(Map<String, dynamic> row) {
    return FriendConnection(
      profile: FriendPublicProfile.fromRemote(row, idKey: 'peer_id'),
      state: FriendRelationshipState.accepted,
      updatedAt: _requiredDateTime(row, 'relationship_updated_at'),
    );
  }

  final FriendPublicProfile profile;
  final FriendRelationshipState state;
  final DateTime? updatedAt;
}

class FriendCursor {
  FriendCursor({required DateTime updatedAt, required String peerId})
      : updatedAt = updatedAt.toUtc(),
        peerId = validateFriendUuid(peerId, field: 'peerId');

  final DateTime updatedAt;
  final String peerId;
}

class FriendPage {
  FriendPage({required List<FriendConnection> items})
      : items = List.unmodifiable(items),
        nextCursor = items.isEmpty
            ? null
            : FriendCursor(
                updatedAt: items.last.updatedAt ??
                    (throw const FriendDataException(
                      'A paged friend row must include its update timestamp.',
                    )),
                peerId: items.last.profile.id,
              );

  final List<FriendConnection> items;
  final FriendCursor? nextCursor;
}

class FriendDiscoverySettings {
  const FriendDiscoverySettings({
    required this.discoverableByEmail,
    required this.discoverableByPhone,
    required this.emailConfirmed,
    required this.phoneVerified,
  });

  factory FriendDiscoverySettings.fromRemote(Map<String, dynamic> row) {
    return FriendDiscoverySettings(
      discoverableByEmail: _requiredBool(row, 'discoverable_by_email'),
      discoverableByPhone: _requiredBool(row, 'discoverable_by_phone'),
      emailConfirmed: _requiredBool(row, 'email_confirmed'),
      phoneVerified: _requiredBool(row, 'phone_verified'),
    );
  }

  final bool discoverableByEmail;
  final bool discoverableByPhone;
  final bool emailConfirmed;
  final bool phoneVerified;
}

String _requiredText(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'must not be empty');
  }
  return normalized;
}

String _requiredString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String || value.trim().isEmpty) {
    throw FriendDataException('Missing or invalid $key in server response.');
  }
  return value;
}

String _optionalString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return '';
  if (value is! String) {
    throw FriendDataException('Invalid $key in server response.');
  }
  return value;
}

String? _nullableString(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value == null) return null;
  if (value is! String) {
    throw FriendDataException('Invalid $key in server response.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! int) {
    throw FriendDataException('Missing or invalid $key in server response.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! bool) {
    throw FriendDataException('Missing or invalid $key in server response.');
  }
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> row, String key) {
  final value = row[key];
  if (value is! String) {
    throw FriendDataException('Missing or invalid $key in server response.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null ||
      (!value.endsWith('Z') && !value.contains(RegExp(r'[+-]\d\d:\d\d$')))) {
    throw FriendDataException('Invalid $key in server response.');
  }
  return parsed.toUtc();
}
