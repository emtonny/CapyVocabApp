import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_models.dart';
import '../domain/groups_repository.dart';

/// A session-fenced client: a token/account change invalidates every result.
final class GroupsSupabaseGateway implements GroupsRemoteGateway {
  static const stagingRef = 'nxteaznowkfennxpqjmt';

  factory GroupsSupabaseGateway.staging({
    required GroupOwner owner,
    required Session session,
    required String publishableKey,
    required bool Function() isCurrentSession,
    Duration requestTimeout = const Duration(seconds: 12),
    http.Client? httpClient,
    RealtimeClientOptions realtimeOptions = const RealtimeClientOptions(),
  }) {
    if (owner.projectRef != stagingRef ||
        owner.userId != session.user.id ||
        session.accessToken.isEmpty ||
        publishableKey.trim().isEmpty ||
        requestTimeout <= Duration.zero) {
      throw const FormatException('Invalid Staging groups session.');
    }
    final token = session.accessToken;
    final client = SupabaseClient(
      'https://$stagingRef.supabase.co',
      publishableKey,
      accessToken: () async => token,
      headers: {'Authorization': 'Bearer $token'},
      httpClient: httpClient,
      realtimeClientOptions: realtimeOptions,
    );
    client.realtime.customAccessToken = null;
    return GroupsSupabaseGateway._(
      owner,
      client,
      isCurrentSession,
      requestTimeout,
    );
  }

  GroupsSupabaseGateway._(
    this.owner,
    this._client,
    this._isCurrentSession,
    this._timeout,
  );

  final GroupOwner owner;
  final SupabaseClient _client;
  final bool Function() _isCurrentSession;
  final Duration _timeout;
  bool _closed = false;
  StreamController<GroupRemoteSignal>? _signals;
  RealtimeChannel? _channel;
  Future<void> _channelTail = Future.value();
  Future<void>? _disposal;
  int _channelGeneration = 0;

  @override
  Future<GroupCapabilities> getCapabilities() => _request(() async {
        final rows = _rows(
          await _client.rpc('get_my_learning_group_capabilities'),
        );
        if (rows.length != 1) {
          throw const GroupDataException('Invalid capabilities row count.');
        }
        return GroupCapabilities.fromRemote(rows.single);
      });

  @override
  Future<List<LearningGroupSummary>> listGroups() => _request(() async {
        final rows = _rows(await _client.rpc('list_my_learning_groups'));
        final result = rows.map(LearningGroupSummary.fromRemote).toList();
        if (result.map((item) => item.id).toSet().length != result.length) {
          throw const GroupDataException('Duplicate group returned by server.');
        }
        return result;
      });

  @override
  Future<String> createGroup({
    required String title,
    required String description,
    required String requestId,
  }) {
    final normalizedTitle = title.trim();
    final normalizedDescription = description.trim();
    requireGroupUuid(requestId, 'requestId');
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 80 ||
        normalizedDescription.length > 500) {
      throw const GroupException(
        GroupFailureKind.invalidInput,
        'Tên lớp phải có 1–80 ký tự và mô tả tối đa 500 ký tự.',
      );
    }
    return _request(() async {
      final value = await _client.rpc('create_learning_group', params: {
        'p_title': normalizedTitle,
        'p_description': normalizedDescription,
        'p_request_id': requestId,
      });
      if (value is! String) {
        throw const GroupDataException('Invalid create group response.');
      }
      return requireGroupUuid(value, 'groupId');
    });
  }

  @override
  Future<String> requestJoin({
    required String inviteToken,
    required String requestId,
  }) {
    final token = inviteToken.trim().toLowerCase();
    requireGroupUuid(requestId, 'requestId');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) {
      throw const GroupException(
        GroupFailureKind.invalidInput,
        'Mã mời không hợp lệ hoặc đã hết hạn.',
      );
    }
    return _request(() async {
      final value = await _client.rpc('request_learning_group_join', params: {
        'p_invite_token': token,
        'p_request_id': requestId,
      });
      if (value == null) {
        throw const GroupException(
          GroupFailureKind.notFound,
          'Mã mời không hợp lệ, đã hết hạn hoặc bạn thao tác quá nhanh.',
        );
      }
      if (value is! String) {
        throw const GroupDataException('Invalid join group response.');
      }
      return requireGroupUuid(value, 'groupId');
    });
  }

  @override
  Future<List<LearningGroupMember>> listMembers(String groupId) {
    final id = requireGroupUuid(groupId, 'groupId');
    return _request(() async {
      final rows = _rows(await _client.rpc(
        'list_learning_group_members',
        params: {'p_group_id': id},
      ));
      final result = rows.map(LearningGroupMember.fromRemote).toList();
      if (result.map((item) => item.userId).toSet().length != result.length) {
        throw const GroupDataException('Duplicate group member returned.');
      }
      return result;
    });
  }

  @override
  Future<List<LearningGroupAnnouncement>> listAnnouncements(String groupId) {
    final id = requireGroupUuid(groupId, 'groupId');
    return _request(() async {
      final rows = _rows(await _client.rpc(
        'list_learning_group_announcements',
        params: {'p_group_id': id},
      ));
      final result = rows.map(LearningGroupAnnouncement.fromRemote).toList();
      if (result.map((item) => item.id).toSet().length != result.length) {
        throw const GroupDataException('Duplicate announcement returned.');
      }
      return result;
    });
  }

  @override
  Future<LearningGroupInviteStatus> getInviteStatus(String groupId) {
    final id = requireGroupUuid(groupId, 'groupId');
    return _request(() async {
      final rows = _rows(await _client.rpc(
        'get_learning_group_invite_status',
        params: {'p_group_id': id},
      ));
      if (rows.length != 1) {
        throw const GroupDataException('Invalid invite status row count.');
      }
      return LearningGroupInviteStatus.fromRemote(rows.single);
    });
  }

  @override
  Future<List<LearningGroupModerationEvent>> listModerationEvents(
    String groupId, {
    int limit = 100,
  }) {
    final id = requireGroupUuid(groupId, 'groupId');
    if (limit < 1 || limit > 200) {
      throw const GroupException(
        GroupFailureKind.invalidInput,
        'Giới hạn nhật ký quản trị phải từ 1–200.',
      );
    }
    return _request(() async {
      final rows = _rows(await _client.rpc(
        'list_learning_group_moderation_events',
        params: {'p_group_id': id, 'p_limit': limit},
      ));
      final result = rows.map(LearningGroupModerationEvent.fromRemote).toList();
      if (result.map((item) => item.id).toSet().length != result.length) {
        throw const GroupDataException('Duplicate moderation event returned.');
      }
      return result;
    });
  }

  @override
  Future<List<LearningGroupSystemTask>> listSystemTasks(String groupId) {
    final id = requireGroupUuid(groupId, 'groupId');
    return _request(() async {
      final rows = _rows(await _client.rpc(
        'list_learning_group_system_tasks',
        params: {'p_group_id': id},
      ));
      final result = rows.map(LearningGroupSystemTask.fromRemote).toList();
      if (result.map((item) => item.id).toSet().length != result.length) {
        throw const GroupDataException('Duplicate learning task returned.');
      }
      return result;
    });
  }

  @override
  Future<bool> getVocabularySharing(String groupId) async {
    final value = await _rpc(
      'get_my_learning_group_vocabulary_sharing',
      {'p_group_id': requireGroupUuid(groupId, 'groupId')},
    );
    if (value is! bool) {
      throw const GroupDataException('Invalid vocabulary sharing response.');
    }
    return value;
  }

  @override
  Future<void> setVocabularySharing({
    required String groupId,
    required bool enabled,
  }) =>
      _request(() async {
        final value = await _client.rpc(
          'set_learning_group_vocabulary_sharing',
          params: {
            'p_group_id': requireGroupUuid(groupId, 'groupId'),
            'p_enabled': enabled,
          },
        );
        if (value != enabled) {
          throw const GroupDataException('Invalid sharing mutation response.');
        }
      });

  @override
  Future<String> createSystemTask({
    required String groupId,
    required String title,
    required int targetWordCount,
    required DateTime dueAt,
    required String requestId,
  }) {
    final normalizedTitle = title.trim();
    final deadline = dueAt.toUtc();
    if (normalizedTitle.isEmpty ||
        normalizedTitle.length > 120 ||
        targetWordCount < 1 ||
        targetWordCount > 100 ||
        !deadline.isAfter(DateTime.now().toUtc())) {
      throw const GroupException(
        GroupFailureKind.invalidInput,
        'Nhiệm vụ cần tên, mục tiêu 1–100 từ và hạn trong tương lai.',
      );
    }
    return _request(() async {
      final value = await _client.rpc(
        'create_learning_group_system_task',
        params: {
          'p_group_id': requireGroupUuid(groupId, 'groupId'),
          'p_title': normalizedTitle,
          'p_target_word_count': targetWordCount,
          'p_due_at': deadline.toIso8601String(),
          'p_request_id': requireGroupUuid(requestId, 'requestId'),
        },
      );
      if (value is! String) {
        throw const GroupDataException('Invalid task creation response.');
      }
      return requireGroupUuid(value, 'taskId');
    });
  }

  @override
  Future<void> closeSystemTask({
    required String groupId,
    required String taskId,
    required String requestId,
  }) =>
      _boolRpc('close_learning_group_system_task', {
        'p_group_id': requireGroupUuid(groupId, 'groupId'),
        'p_task_id': requireGroupUuid(taskId, 'taskId'),
        'p_request_id': requireGroupUuid(requestId, 'requestId'),
      });

  @override
  Future<List<LearningGroupStudentOverview>> listLearningOverview(
    String groupId,
  ) {
    final id = requireGroupUuid(groupId, 'groupId');
    return _request(() async {
      final rows = _rows(await _client.rpc(
        'list_learning_group_learning_overview',
        params: {'p_group_id': id},
      ));
      final result = rows.map(LearningGroupStudentOverview.fromRemote).toList();
      if (result.map((item) => item.userId).toSet().length != result.length) {
        throw const GroupDataException('Duplicate student overview returned.');
      }
      return result;
    });
  }

  @override
  Future<List<LearningGroupSharedVocabulary>> listStudentVocabulary({
    required String groupId,
    required String studentUserId,
    int limit = 200,
  }) {
    if (limit < 1 || limit > 500) {
      throw const GroupException(
        GroupFailureKind.invalidInput,
        'Giới hạn từ vựng phải từ 1–500.',
      );
    }
    return _request(() async {
      final rows = _rows(await _client.rpc(
        'list_learning_group_student_vocabulary',
        params: {
          'p_group_id': requireGroupUuid(groupId, 'groupId'),
          'p_student_user_id': requireGroupUuid(studentUserId, 'studentUserId'),
          'p_limit': limit,
        },
      ));
      final result =
          rows.map(LearningGroupSharedVocabulary.fromRemote).toList();
      if (result.map((item) => item.word.toLowerCase()).toSet().length !=
          result.length) {
        throw const GroupDataException('Duplicate shared vocabulary returned.');
      }
      return result;
    });
  }

  @override
  Future<void> respondJoin({
    required String groupId,
    required String studentUserId,
    required bool approve,
    required String requestId,
  }) async {
    final result = await _rpc(
      'respond_learning_group_join',
      {
        'p_group_id': requireGroupUuid(groupId, 'groupId'),
        'p_student_user_id': requireGroupUuid(studentUserId, 'studentUserId'),
        'p_decision': approve ? 'approve' : 'reject',
        'p_request_id': requireGroupUuid(requestId, 'requestId'),
        'p_reason_code': null,
      },
    );
    if (result != (approve ? 'active' : 'rejected')) {
      throw const GroupDataException('Invalid join decision response.');
    }
  }

  @override
  Future<void> setMemberMute({
    required String groupId,
    required String studentUserId,
    required bool muted,
    required String requestId,
  }) =>
      _boolRpc('set_learning_group_member_mute', {
        'p_group_id': requireGroupUuid(groupId, 'groupId'),
        'p_student_user_id': requireGroupUuid(studentUserId, 'studentUserId'),
        'p_is_muted': muted,
        'p_request_id': requireGroupUuid(requestId, 'requestId'),
        'p_reason_code': null,
      });

  @override
  Future<void> removeMember({
    required String groupId,
    required String studentUserId,
    required String requestId,
  }) =>
      _boolRpc('remove_learning_group_member', {
        'p_group_id': requireGroupUuid(groupId, 'groupId'),
        'p_student_user_id': requireGroupUuid(studentUserId, 'studentUserId'),
        'p_request_id': requireGroupUuid(requestId, 'requestId'),
        'p_reason_code': null,
      });

  @override
  Future<void> archiveGroup({
    required String groupId,
    required String requestId,
  }) =>
      _boolRpc('archive_learning_group', {
        'p_group_id': requireGroupUuid(groupId, 'groupId'),
        'p_request_id': requireGroupUuid(requestId, 'requestId'),
      });

  @override
  Future<LearningGroupInviteSecret> rotateInvite({
    required String groupId,
    required DateTime expiresAt,
    required String requestId,
  }) async {
    final expiry = expiresAt.toUtc();
    final now = DateTime.now().toUtc();
    if (!expiry.isAfter(now) ||
        expiry.isAfter(now.add(const Duration(days: 90)))) {
      throw const GroupException(
        GroupFailureKind.invalidInput,
        'Hạn dùng mã mời phải trong vòng 90 ngày.',
      );
    }
    final value = await _rpc('rotate_learning_group_invite', {
      'p_group_id': requireGroupUuid(groupId, 'groupId'),
      'p_expires_at': expiry.toIso8601String(),
      'p_request_id': requireGroupUuid(requestId, 'requestId'),
    });
    if (value is! String) {
      throw const GroupDataException('Invalid invite rotation response.');
    }
    return LearningGroupInviteSecret(token: value, expiresAt: expiry);
  }

  @override
  Future<void> revokeInvite({
    required String groupId,
    required String requestId,
  }) =>
      _boolRpc('revoke_learning_group_invite', {
        'p_group_id': requireGroupUuid(groupId, 'groupId'),
        'p_request_id': requireGroupUuid(requestId, 'requestId'),
      });

  @override
  Future<void> createAnnouncement({
    required String groupId,
    required String body,
    required String requestId,
  }) async {
    final normalized = body.trim();
    if (normalized.isEmpty || normalized.length > 2000) {
      throw const GroupException(
        GroupFailureKind.invalidInput,
        'Thông báo phải có 1–2000 ký tự.',
      );
    }
    final value = await _rpc('create_learning_group_announcement', {
      'p_group_id': requireGroupUuid(groupId, 'groupId'),
      'p_body': normalized,
      'p_request_id': requireGroupUuid(requestId, 'requestId'),
    });
    if (value is! String) {
      throw const GroupDataException('Invalid announcement response.');
    }
    requireGroupUuid(value, 'announcementId');
  }

  @override
  Future<void> setAnnouncementPinned({
    required String groupId,
    required String announcementId,
    required bool pinned,
    required String requestId,
  }) =>
      _boolRpc('set_learning_group_announcement_pinned', {
        'p_group_id': requireGroupUuid(groupId, 'groupId'),
        'p_announcement_id': requireGroupUuid(
          announcementId,
          'announcementId',
        ),
        'p_is_pinned': pinned,
        'p_request_id': requireGroupUuid(requestId, 'requestId'),
      });

  @override
  Future<String> getGroupConversationId(String groupId) {
    final id = requireGroupUuid(groupId, 'groupId');
    return _request(() async {
      final row = await _client
          .from('chat_conversations')
          .select('id')
          .eq('kind', 'group')
          .eq('learning_group_id', id)
          .single();
      final value = row['id'];
      if (value is! String) {
        throw const GroupDataException('Invalid group chat response.');
      }
      return requireGroupUuid(value, 'conversationId');
    });
  }

  Future<Object?> _rpc(String function, Map<String, Object?> params) =>
      _request(() => _client.rpc(function, params: params));

  Future<void> _boolRpc(
    String function,
    Map<String, Object?> params,
  ) async {
    final value = await _rpc(function, params);
    if (value != true) {
      throw const GroupDataException('Invalid group mutation response.');
    }
  }

  Future<T> _request<T>(Future<T> Function() action) async {
    _checkSession();
    try {
      final result = await action().timeout(_timeout);
      _checkSession();
      return result;
    } on PostgrestException catch (error) {
      final kind = switch (error.code) {
        '22023' => GroupFailureKind.invalidInput,
        '23505' => GroupFailureKind.conflict,
        '42501' => GroupFailureKind.denied,
        'P0001' => GroupFailureKind.rateLimited,
        'P0002' => GroupFailureKind.notFound,
        '55000' => GroupFailureKind.conflict,
        _ => GroupFailureKind.unavailable,
      };
      throw GroupException(kind, _safeMessage(kind));
    } on GroupException {
      rethrow;
    } on ArgumentError catch (_) {
      throw const GroupDataException('Dữ liệu Groups từ server không hợp lệ.');
    } on FormatException catch (_) {
      throw const GroupDataException('Dữ liệu Groups từ server không hợp lệ.');
    } on TypeError catch (_) {
      throw const GroupDataException('Dữ liệu Groups từ server không hợp lệ.');
    } catch (_) {
      throw const GroupException(
        GroupFailureKind.unavailable,
        'Chưa kết nối được dịch vụ nhóm học.',
      );
    }
  }

  void _checkSession() {
    if (_closed || !_isCurrentSession()) throw const GroupSessionChanged();
  }

  @override
  Stream<GroupRemoteSignal> get signals {
    _checkSession();
    return (_signals ??= StreamController<GroupRemoteSignal>.broadcast(
      onListen: () => _queueChannel(true),
      onCancel: () => _queueChannel(false),
    ))
        .stream;
  }

  void _queueChannel(bool attach) {
    final generation = ++_channelGeneration;
    _channelTail = _channelTail.then((_) async {
      final previous = _channel;
      _channel = null;
      if (previous != null) await _client.removeChannel(previous);
      if (!attach ||
          _closed ||
          !_isCurrentSession() ||
          generation != _channelGeneration ||
          !_signals!.hasListener) {
        return;
      }
      final channel = _client.channel('learning-groups:${owner.userId}');
      _channel = channel;
      for (final table in const [
        'learning_groups',
        'learning_group_members',
        'learning_group_announcements',
      ]) {
        channel.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: table,
          callback: (_) => _emit(GroupRemoteSignal.changed, generation),
        );
      }
      channel.subscribe((status, _) {
        _emit(
          status == RealtimeSubscribeStatus.subscribed
              ? GroupRemoteSignal.connected
              : GroupRemoteSignal.disconnected,
          generation,
        );
      });
    }).catchError((Object _) {
      _emit(GroupRemoteSignal.disconnected, generation);
    });
  }

  void _emit(GroupRemoteSignal signal, int generation) {
    if (!_closed &&
        _isCurrentSession() &&
        generation == _channelGeneration &&
        _signals != null &&
        !_signals!.isClosed &&
        _signals!.hasListener) {
      _signals!.add(signal);
    }
  }

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _closed = true;
    _channelGeneration++;
    await _channelTail;
    final channel = _channel;
    _channel = null;
    if (channel != null) await _client.removeChannel(channel);
    await _client.dispose();
    await _signals?.close();
  }
}

List<Map<String, dynamic>> _rows(Object? raw) {
  if (raw is! List) {
    throw const GroupDataException(
        'Groups service returned an invalid row set.');
  }
  return raw.map((item) {
    if (item is! Map) {
      throw const GroupDataException('Groups service returned an invalid row.');
    }
    return Map<String, dynamic>.from(item);
  }).toList(growable: false);
}

String _safeMessage(GroupFailureKind kind) => switch (kind) {
      GroupFailureKind.invalidInput => 'Yêu cầu nhóm học không hợp lệ.',
      GroupFailureKind.unauthenticated => 'Hãy đăng nhập lại để tiếp tục.',
      GroupFailureKind.denied => 'Bạn không có quyền thực hiện thao tác này.',
      GroupFailureKind.notFound => 'Không tìm thấy nhóm hoặc mã mời hợp lệ.',
      GroupFailureKind.conflict => 'Dữ liệu nhóm đã thay đổi. Hãy làm mới.',
      GroupFailureKind.rateLimited =>
        'Bạn thao tác quá nhanh. Hãy thử lại sau.',
      GroupFailureKind.invalidResponse =>
        'Dữ liệu Groups từ server không hợp lệ.',
      GroupFailureKind.unavailable => 'Chưa kết nối được dịch vụ nhóm học.',
    };
