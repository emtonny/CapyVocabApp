import 'dart:async';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/friend_entity.dart';

final class FriendsStore {
  FriendsStore({required this.database, required this.owner});

  final Database database;
  final FriendOwner owner;
  final _changes = StreamController<void>.broadcast(sync: true);

  Future<void> reconcileSnapshot({
    required FriendListKind kind,
    required List<FriendConnection> connections,
    required DateTime refreshStartedAt,
    required DateTime completedAt,
    required bool Function() isCurrent,
  }) async {
    final peerIds =
        connections.map((connection) => connection.profile.id).toSet();
    if (peerIds.length != connections.length ||
        connections.any(
          (connection) =>
              connection.state != kind.relationshipState ||
              connection.updatedAt == null ||
              connection.profile.id == owner.userId,
        )) {
      throw const FriendDataException('Invalid complete friend snapshot.');
    }
    final startedMicros = refreshStartedAt.toUtc().microsecondsSinceEpoch;
    final completedMicros = completedAt.toUtc().microsecondsSinceEpoch;
    await database.transaction((tx) async {
      _guardCurrent(isCurrent);
      for (final connection in connections) {
        await tx.rawInsert(
          '''INSERT INTO friend_connections(
            project_ref,owner_id,peer_id,display_name,username,avatar_url,
            study_points,streak_days,user_level,relationship_state,
            server_updated_at,cached_at
          ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
          ON CONFLICT(project_ref,owner_id,peer_id) DO UPDATE SET
            display_name=excluded.display_name,
            username=excluded.username,
            avatar_url=excluded.avatar_url,
            study_points=excluded.study_points,
            streak_days=excluded.streak_days,
            user_level=excluded.user_level,
            relationship_state=excluded.relationship_state,
            server_updated_at=excluded.server_updated_at,
            cached_at=excluded.cached_at
          WHERE excluded.server_updated_at >= friend_connections.server_updated_at''',
          [
            owner.projectRef,
            owner.userId,
            connection.profile.id,
            connection.profile.displayName,
            connection.profile.username,
            connection.profile.avatarUrl,
            connection.profile.studyPoints,
            connection.profile.streakDays,
            connection.profile.userLevel,
            connection.state.wireValue,
            connection.updatedAt!.microsecondsSinceEpoch,
            completedMicros,
          ],
        );
      }
      final where = StringBuffer('''project_ref=? AND owner_id=?
        AND relationship_state=? AND cached_at<=?''');
      final args = <Object?>[
        owner.projectRef,
        owner.userId,
        kind.relationshipState.wireValue,
        startedMicros,
      ];
      if (peerIds.isNotEmpty) {
        where.write(
            ' AND peer_id NOT IN (${List.filled(peerIds.length, '?').join(',')})');
        args.addAll(peerIds);
      }
      await tx.delete(
        'friend_connections',
        where: where.toString(),
        whereArgs: args,
      );
      await tx.rawInsert(
        '''INSERT INTO friend_sync_meta(
          project_ref,owner_id,list_kind,refreshed_at
        ) VALUES(?,?,?,?)
        ON CONFLICT(project_ref,owner_id,list_kind) DO UPDATE SET
          refreshed_at=excluded.refreshed_at
        WHERE excluded.refreshed_at >= friend_sync_meta.refreshed_at''',
        [
          owner.projectRef,
          owner.userId,
          kind.storageValue,
          completedMicros,
        ],
      );
      _guardCurrent(isCurrent);
    });
    _notify();
  }

  Future<List<FriendConnection>> list(FriendListKind kind) async {
    final rows = await database.query(
      'friend_connections',
      where: 'project_ref=? AND owner_id=? AND relationship_state=?',
      whereArgs: [
        owner.projectRef,
        owner.userId,
        kind.relationshipState.wireValue,
      ],
      orderBy: 'server_updated_at DESC, peer_id DESC',
    );
    return rows.map(_decode).toList(growable: false);
  }

  Stream<List<FriendConnection>> watch(FriendListKind kind) {
    return Stream.multi((controller) {
      var canceled = false;
      Future<void> tail = Future.value();
      void emit() {
        tail = tail.then((_) async {
          if (canceled) return;
          try {
            final result = await list(kind);
            if (!canceled) controller.add(result);
          } catch (_) {
            if (!canceled) {
              controller.addError(StateError('Cannot read local friends.'));
            }
          }
        });
      }

      final subscription = _changes.stream.listen((_) => emit(), onDone: () {
        canceled = true;
        controller.close();
      });
      controller.onCancel = () {
        canceled = true;
        return subscription.cancel();
      };
      emit();
    });
  }

  Future<DateTime?> refreshedAt(FriendListKind kind) async {
    final rows = await database.query(
      'friend_sync_meta',
      columns: ['refreshed_at'],
      where: 'project_ref=? AND owner_id=? AND list_kind=?',
      whereArgs: [owner.projectRef, owner.userId, kind.storageValue],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMicrosecondsSinceEpoch(
      rows.single['refreshed_at'] as int,
      isUtc: true,
    );
  }

  FriendConnection _decode(Map<String, Object?> row) {
    return FriendConnection(
      profile: FriendPublicProfile(
        id: row['peer_id'] as String,
        displayName: row['display_name'] as String,
        username: row['username'] as String,
        avatarUrl: row['avatar_url'] as String?,
        studyPoints: row['study_points'] as int,
        streakDays: row['streak_days'] as int,
        userLevel: row['user_level'] as int,
      ),
      state: FriendRelationshipState.fromWire(row['relationship_state']),
      updatedAt: DateTime.fromMicrosecondsSinceEpoch(
        row['server_updated_at'] as int,
        isUtc: true,
      ),
    );
  }

  void _guardCurrent(bool Function() isCurrent) {
    if (!isCurrent()) throw const FriendRefreshSuperseded();
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
