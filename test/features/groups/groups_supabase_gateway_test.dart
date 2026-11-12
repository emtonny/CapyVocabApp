import 'dart:async';
import 'dart:convert';

import 'package:capy_vocab/features/groups/data/groups_supabase_gateway.dart';
import 'package:capy_vocab/features/groups/domain/group_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const account = '10000000-0000-4000-8000-000000000001';
const student = '10000000-0000-4000-8000-000000000002';
const group = '20000000-0000-4000-8000-000000000001';
const requestId = '30000000-0000-4000-8000-000000000001';
const announcement = '40000000-0000-4000-8000-000000000001';
const conversation = '50000000-0000-4000-8000-000000000001';
const task = '60000000-0000-4000-8000-000000000001';
final instant = DateTime.utc(2026, 10, 13, 8);
final inviteToken = List.filled(64, 'a').join();

String token(String user) => '${base64Url.encode(utf8.encode('{}'))}.'
    '${base64Url.encode(utf8.encode(jsonEncode({
          'sub': user,
          'exp': 4102444800
        })))}.test';

Session session(String user) => Session(
      accessToken: token(user),
      tokenType: 'bearer',
      user: User(
        id: user,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: instant.toIso8601String(),
      ),
    );

http.Response response(Object? value, [int status = 200]) => http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late GroupsSupabaseGateway gateway;
  late MockClient client;
  late bool active;
  late List<http.Request> requests;
  late FutureOr<http.Response> Function(http.Request) handler;

  setUp(() {
    active = true;
    requests = [];
    handler = (_) => response([]);
    client = MockClient((request) async {
      requests.add(request);
      final result = await handler(request);
      return http.Response.bytes(
        result.bodyBytes,
        result.statusCode,
        headers: result.headers,
        request: request,
      );
    });
    gateway = GroupsSupabaseGateway.staging(
      owner: GroupOwner(
        projectRef: GroupsSupabaseGateway.stagingRef,
        userId: account,
      ),
      session: session(account),
      publishableKey: 'sb_publishable_test',
      isCurrentSession: () => active,
      httpClient: client,
    );
  });

  tearDown(() async {
    await gateway.dispose();
    client.close();
  });

  test('capability and list RPC decode only the GT2 contract', () async {
    handler = (request) {
      if (request.url.path.endsWith('/get_my_learning_group_capabilities')) {
        return response([
          {
            'account_role': 'teacher',
            'teacher_verification_status': 'verified',
            'can_manage_groups': true,
          }
        ]);
      }
      return response([
        {
          'group_id': group,
          'title': 'Class A',
          'description': '',
          'group_status': 'active',
          'member_role': 'owner_teacher',
          'membership_status': 'active',
          'is_muted': false,
          'active_student_count': 2,
          'pending_student_count': 1,
          'updated_at': instant.toIso8601String(),
        }
      ]);
    };

    expect((await gateway.getCapabilities()).canManageGroups, isTrue);
    expect((await gateway.listGroups()).single.id, group);
    expect(requests.map((item) => item.url.path), [
      '/rest/v1/rpc/get_my_learning_group_capabilities',
      '/rest/v1/rpc/list_my_learning_groups',
    ]);
  });

  test('create and join send bounded inputs and request ids', () async {
    handler = (_) => response(group);
    await gateway.createGroup(
      title: '  Class A ',
      description: '  Description ',
      requestId: requestId,
    );
    await gateway.requestJoin(
      inviteToken: inviteToken.toUpperCase(),
      requestId: requestId,
    );

    expect(jsonDecode(requests.first.body), {
      'p_title': 'Class A',
      'p_description': 'Description',
      'p_request_id': requestId,
    });
    expect(jsonDecode(requests.last.body), {
      'p_invite_token': inviteToken,
      'p_request_id': requestId,
    });
  });

  test('member and announcement RPCs decode the GT4 safe projections',
      () async {
    handler = (request) {
      if (request.url.path.endsWith('/list_learning_group_members')) {
        return response([
          {
            'user_id': student,
            'display_name': 'Student A',
            'username': 'student.a',
            'avatar_url': null,
            'member_role': 'student',
            'membership_status': 'pending',
            'is_muted': false,
            'updated_at': instant.toIso8601String(),
          }
        ]);
      }
      return response([
        {
          'announcement_id': announcement,
          'author_user_id': account,
          'author_display_name': 'Teacher A',
          'body': 'Review lesson 1',
          'is_pinned': true,
          'created_at': instant.toIso8601String(),
          'updated_at': instant.toIso8601String(),
        }
      ]);
    };

    final member = (await gateway.listMembers(group)).single;
    final notice = (await gateway.listAnnouncements(group)).single;

    expect(member.userId, student);
    expect(member.status, LearningGroupMembershipStatus.pending);
    expect(notice.id, announcement);
    expect(notice.isPinned, isTrue);
    expect(requests.map((item) => jsonDecode(item.body)), [
      {'p_group_id': group},
      {'p_group_id': group},
    ]);
  });

  test('management mutations use bounded RPC payloads', () async {
    handler = (request) {
      if (request.url.path.endsWith('/respond_learning_group_join')) {
        return response('active');
      }
      if (request.url.path.endsWith('/create_learning_group_announcement')) {
        return response(announcement);
      }
      return response(true);
    };

    await gateway.respondJoin(
      groupId: group,
      studentUserId: student,
      approve: true,
      requestId: requestId,
    );
    await gateway.setMemberMute(
      groupId: group,
      studentUserId: student,
      muted: true,
      requestId: requestId,
    );
    await gateway.createAnnouncement(
      groupId: group,
      body: '  Review lesson 1  ',
      requestId: requestId,
    );
    await gateway.setAnnouncementPinned(
      groupId: group,
      announcementId: announcement,
      pinned: true,
      requestId: requestId,
    );

    expect(jsonDecode(requests[0].body), {
      'p_group_id': group,
      'p_student_user_id': student,
      'p_decision': 'approve',
      'p_request_id': requestId,
      'p_reason_code': null,
    });
    expect(jsonDecode(requests[1].body), {
      'p_group_id': group,
      'p_student_user_id': student,
      'p_is_muted': true,
      'p_request_id': requestId,
      'p_reason_code': null,
    });
    expect(jsonDecode(requests[2].body), {
      'p_group_id': group,
      'p_body': 'Review lesson 1',
      'p_request_id': requestId,
    });
    expect(jsonDecode(requests[3].body), {
      'p_group_id': group,
      'p_announcement_id': announcement,
      'p_is_pinned': true,
      'p_request_id': requestId,
    });
  });

  test('owner management projections decode invite status and audit', () async {
    handler = (request) {
      if (request.url.path.endsWith('/get_learning_group_invite_status')) {
        return response([
          {
            'has_active_invite': true,
            'expires_at':
                instant.add(const Duration(days: 7)).toIso8601String(),
            'use_count': 2,
            'last_used_at': instant.toIso8601String(),
            'created_at':
                instant.subtract(const Duration(days: 1)).toIso8601String(),
          }
        ]);
      }
      return response([
        {
          'event_id': 42,
          'actor_user_id': account,
          'actor_display_name': 'Teacher A',
          'target_user_id': student,
          'target_display_name': 'Student A',
          'target_message_id': null,
          'action': 'member_muted',
          'reason_code': 'class_rule',
          'occurred_at': instant.toIso8601String(),
        }
      ]);
    };

    final invite = await gateway.getInviteStatus(group);
    final event = (await gateway.listModerationEvents(group)).single;

    expect(invite.hasActiveInvite, isTrue);
    expect(invite.useCount, 2);
    expect(event.id, 42);
    expect(event.action, 'member_muted');
    expect(jsonDecode(requests[0].body), {'p_group_id': group});
    expect(jsonDecode(requests[1].body), {
      'p_group_id': group,
      'p_limit': 100,
    });
  });

  test('learning RPCs decode task overview and text-only vocabulary', () async {
    handler = (request) {
      if (request.url.path.endsWith('/list_learning_group_system_tasks')) {
        return response([
          {
            'task_id': task,
            'title': 'Learn 10 new words',
            'target_word_count': 10,
            'due_at': instant.add(const Duration(days: 7)).toIso8601String(),
            'task_status': 'active',
            'created_at': instant.toIso8601String(),
            'learned_word_count': 4,
            'mastery_percent': 40,
            'progress_status': 'in_progress',
            'sharing_enabled': true,
            'assigned_student_count': 0,
            'completed_student_count': 0,
          }
        ]);
      }
      if (request.url.path
          .endsWith('/get_my_learning_group_vocabulary_sharing')) {
        return response(true);
      }
      if (request.url.path.endsWith('/list_learning_group_learning_overview')) {
        return response([
          {
            'student_user_id': student,
            'display_name': 'Student A',
            'sharing_enabled': true,
            'total_learned_word_count': 12,
            'active_task_count': 2,
            'completed_task_count': 1,
            'average_mastery_percent': 60,
            'last_learned_at': instant.toIso8601String(),
          }
        ]);
      }
      return response([
        {
          'word': 'apple',
          'first_learned_at': instant.toIso8601String(),
          'last_learned_at': instant.toIso8601String(),
        }
      ]);
    };

    final learnedTask = (await gateway.listSystemTasks(group)).single;
    final sharing = await gateway.getVocabularySharing(group);
    final overview = (await gateway.listLearningOverview(group)).single;
    final word = (await gateway.listStudentVocabulary(
      groupId: group,
      studentUserId: student,
      limit: 50,
    ))
        .single;

    expect(learnedTask.id, task);
    expect(learnedTask.masteryPercent, 40);
    expect(sharing, isTrue);
    expect(overview.totalLearnedWordCount, 12);
    expect(word.word, 'apple');
    expect(requests.map((item) => jsonDecode(item.body)), [
      {'p_group_id': group},
      {'p_group_id': group},
      {'p_group_id': group},
      {
        'p_group_id': group,
        'p_student_user_id': student,
        'p_limit': 50,
      },
    ]);
  });

  test('learning mutations use bounded RPC payloads', () async {
    final dueAt = DateTime.now().toUtc().add(const Duration(days: 7));
    handler = (request) {
      if (request.url.path.endsWith('/set_learning_group_vocabulary_sharing')) {
        return response(true);
      }
      if (request.url.path.endsWith('/create_learning_group_system_task')) {
        return response(task);
      }
      return response(true);
    };

    await gateway.setVocabularySharing(groupId: group, enabled: true);
    expect(
      await gateway.createSystemTask(
        groupId: group,
        title: '  Learn 10 new words  ',
        targetWordCount: 10,
        dueAt: dueAt,
        requestId: requestId,
      ),
      task,
    );
    await gateway.closeSystemTask(
      groupId: group,
      taskId: task,
      requestId: requestId,
    );

    expect(jsonDecode(requests[0].body), {
      'p_group_id': group,
      'p_enabled': true,
    });
    expect(jsonDecode(requests[1].body), {
      'p_group_id': group,
      'p_title': 'Learn 10 new words',
      'p_target_word_count': 10,
      'p_due_at': dueAt.toIso8601String(),
      'p_request_id': requestId,
    });
    expect(jsonDecode(requests[2].body), {
      'p_group_id': group,
      'p_task_id': task,
      'p_request_id': requestId,
    });
  });

  test('group conversation query is scoped to group kind and id', () async {
    handler = (_) => response({'id': conversation});

    expect(await gateway.getGroupConversationId(group), conversation);
    expect(requests.single.url.path, '/rest/v1/chat_conversations');
    expect(requests.single.url.queryParameters['kind'], 'eq.group');
    expect(
      requests.single.url.queryParameters['learning_group_id'],
      'eq.$group',
    );
  });

  test('null join response remains non-disclosing', () async {
    handler = (_) => response(null);
    await expectLater(
      gateway.requestJoin(inviteToken: inviteToken, requestId: requestId),
      throwsA(
        isA<GroupException>()
            .having((error) => error.kind, 'kind', GroupFailureKind.notFound)
            .having(
                (error) => error.message, 'message', isNot(contains(group))),
      ),
    );
  });

  test('session fence rejects before and after an in-flight response',
      () async {
    active = false;
    await expectLater(
        gateway.listGroups(), throwsA(isA<GroupSessionChanged>()));
    expect(requests, isEmpty);

    active = true;
    final barrier = Completer<http.Response>();
    handler = (_) => barrier.future;
    final pending = gateway.listGroups();
    await Future<void>.delayed(Duration.zero);
    active = false;
    barrier.complete(response([]));
    await expectLater(pending, throwsA(isA<GroupSessionChanged>()));
  });
}
