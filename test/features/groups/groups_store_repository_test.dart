import 'dart:async';
import 'dart:io';

import 'package:capy_vocab/features/groups/data/cached_groups_repository.dart';
import 'package:capy_vocab/features/groups/data/local/groups_database.dart';
import 'package:capy_vocab/features/groups/data/local/groups_store.dart';
import 'package:capy_vocab/features/groups/domain/group_models.dart';
import 'package:capy_vocab/features/groups/domain/groups_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const project = 'nxteaznowkfennxpqjmt';
const accountA = '10000000-0000-4000-8000-000000000001';
const accountB = '10000000-0000-4000-8000-000000000002';
String groupId(int value) =>
    '20000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';
final instant = DateTime.utc(2026, 10, 13, 8);
final inviteToken = List.filled(64, 'a').join();
const student = '10000000-0000-4000-8000-000000000003';
const announcementId = '30000000-0000-4000-8000-000000000003';

LearningGroupSummary summary(
  int value, {
  LearningGroupRole role = LearningGroupRole.student,
  LearningGroupMembershipStatus membership =
      LearningGroupMembershipStatus.active,
}) =>
    LearningGroupSummary(
      id: groupId(value),
      title: 'Group $value',
      description: 'Description $value',
      status: LearningGroupStatus.active,
      role: role,
      membershipStatus: membership,
      isMuted: false,
      activeStudentCount: value,
      pendingStudentCount: 0,
      updatedAt: instant.add(Duration(minutes: value)),
    );

final class FakeGroupsGateway implements GroupsRemoteGateway {
  List<LearningGroupSummary> groups = [];
  List<LearningGroupMember> members = [];
  List<LearningGroupAnnouncement> announcements = [];
  List<LearningGroupModerationEvent> moderationEvents = [];
  List<LearningGroupSystemTask> tasks = [];
  List<LearningGroupStudentOverview> studentOverviews = [];
  List<LearningGroupSharedVocabulary> sharedVocabulary = [];
  bool vocabularySharing = false;
  GroupException? detailFailure;
  Completer<List<LearningGroupSummary>>? barrier;
  int listCalls = 0;
  int createCalls = 0;
  int joinCalls = 0;

  @override
  Stream<GroupRemoteSignal> get signals => const Stream.empty();

  @override
  Future<GroupCapabilities> getCapabilities() async => const GroupCapabilities(
        accountRole: 'teacher',
        teacherVerificationStatus: 'verified',
        canManageGroups: true,
      );

  @override
  Future<List<LearningGroupSummary>> listGroups() async {
    listCalls++;
    final pending = barrier;
    if (pending != null) return await pending.future;
    return groups;
  }

  @override
  Future<String> createGroup({
    required String title,
    required String description,
    required String requestId,
  }) async {
    createCalls++;
    groups = [
      summary(9, role: LearningGroupRole.ownerTeacher),
      ...groups,
    ];
    return groupId(9);
  }

  @override
  Future<String> requestJoin({
    required String inviteToken,
    required String requestId,
  }) async {
    joinCalls++;
    groups = [
      summary(8, membership: LearningGroupMembershipStatus.pending),
      ...groups,
    ];
    return groupId(8);
  }

  @override
  Future<List<LearningGroupMember>> listMembers(String groupId) async {
    if (detailFailure case final failure?) throw failure;
    return members;
  }

  @override
  Future<List<LearningGroupAnnouncement>> listAnnouncements(
    String groupId,
  ) async {
    if (detailFailure case final failure?) throw failure;
    return announcements;
  }

  @override
  Future<LearningGroupInviteStatus> getInviteStatus(String groupId) async =>
      detailFailure == null
          ? LearningGroupInviteStatus(
              hasActiveInvite: true,
              expiresAt: instant.add(const Duration(days: 7)),
              useCount: 2,
              lastUsedAt: instant,
              createdAt: instant.subtract(const Duration(days: 1)),
            )
          : throw detailFailure!;

  @override
  Future<List<LearningGroupModerationEvent>> listModerationEvents(
    String groupId, {
    int limit = 100,
  }) async {
    if (detailFailure case final failure?) throw failure;
    return moderationEvents;
  }

  @override
  Future<List<LearningGroupSystemTask>> listSystemTasks(String groupId) async =>
      tasks;

  @override
  Future<bool> getVocabularySharing(String groupId) async => vocabularySharing;

  @override
  Future<void> setVocabularySharing({
    required String groupId,
    required bool enabled,
  }) async {
    vocabularySharing = enabled;
  }

  @override
  Future<String> createSystemTask({
    required String groupId,
    required String title,
    required int targetWordCount,
    required DateTime dueAt,
    required String requestId,
  }) async =>
      groupId;

  @override
  Future<void> closeSystemTask({
    required String groupId,
    required String taskId,
    required String requestId,
  }) async {}

  @override
  Future<List<LearningGroupStudentOverview>> listLearningOverview(
    String groupId,
  ) async =>
      studentOverviews;

  @override
  Future<List<LearningGroupSharedVocabulary>> listStudentVocabulary({
    required String groupId,
    required String studentUserId,
    int limit = 200,
  }) async =>
      sharedVocabulary;

  @override
  Future<void> respondJoin({
    required String groupId,
    required String studentUserId,
    required bool approve,
    required String requestId,
  }) async {}

  @override
  Future<void> setMemberMute({
    required String groupId,
    required String studentUserId,
    required bool muted,
    required String requestId,
  }) async {}

  @override
  Future<void> removeMember({
    required String groupId,
    required String studentUserId,
    required String requestId,
  }) async {}

  @override
  Future<void> archiveGroup({
    required String groupId,
    required String requestId,
  }) async {}

  @override
  Future<LearningGroupInviteSecret> rotateInvite({
    required String groupId,
    required DateTime expiresAt,
    required String requestId,
  }) async =>
      LearningGroupInviteSecret(token: inviteToken, expiresAt: expiresAt);

  @override
  Future<void> revokeInvite({
    required String groupId,
    required String requestId,
  }) async {}

  @override
  Future<void> createAnnouncement({
    required String groupId,
    required String body,
    required String requestId,
  }) async {}

  @override
  Future<void> setAnnouncementPinned({
    required String groupId,
    required String announcementId,
    required bool pinned,
    required String requestId,
  }) async {}

  @override
  Future<String> getGroupConversationId(String groupId) async => groupId;

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory directory;
  late GroupsDatabase local;
  late Database database;
  late GroupsStore store;
  late FakeGroupsGateway remote;
  late CachedGroupsRepository repository;
  late bool active;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('capy_groups_gt2_');
    local = GroupsDatabase(
      factory: databaseFactoryFfi,
      path: '${directory.path}/groups.db',
    );
    database = await local.open();
    store = GroupsStore(
      database: database,
      owner: GroupOwner(projectRef: project, userId: accountA),
    );
    remote = FakeGroupsGateway();
    active = true;
    repository = CachedGroupsRepository(
      remote: remote,
      store: store,
      isCurrentSession: () => active,
      now: () => instant.add(const Duration(hours: 1)),
    );
  });

  tearDown(() async {
    await repository.dispose();
    await local.close();
    await directory.delete(recursive: true);
  });

  test('v2 database contains owner-scoped summary and detail cache', () async {
    final tables = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    expect(
      tables.map((row) => row['name']).toSet(),
      {
        'learning_group_summaries',
        'learning_group_sync_meta',
        'learning_group_detail_sync',
        'learning_group_member_cache',
        'learning_group_announcement_cache',
        'learning_group_invite_status_cache',
        'learning_group_moderation_event_cache',
      },
    );
    expect(await database.getVersion(), 2);
  });

  test('v1 database upgrades additively and preserves summaries', () async {
    final path = '${directory.path}/groups_v1.db';
    final old = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''CREATE TABLE learning_group_summaries (
            project_ref TEXT NOT NULL,
            owner_id TEXT NOT NULL,
            group_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            group_status TEXT NOT NULL,
            member_role TEXT NOT NULL,
            membership_status TEXT NOT NULL,
            is_muted INTEGER NOT NULL CHECK(is_muted IN (0,1)),
            active_student_count INTEGER NOT NULL CHECK(active_student_count >= 0),
            pending_student_count INTEGER NOT NULL CHECK(pending_student_count >= 0),
            server_updated_at INTEGER NOT NULL,
            cached_at INTEGER NOT NULL,
            PRIMARY KEY(project_ref,owner_id,group_id)
          )''');
          await db.execute('''CREATE TABLE learning_group_sync_meta (
            project_ref TEXT NOT NULL,
            owner_id TEXT NOT NULL,
            refreshed_at INTEGER NOT NULL,
            PRIMARY KEY(project_ref,owner_id)
          )''');
        },
      ),
    );
    await old.insert('learning_group_summaries', {
      'project_ref': project,
      'owner_id': accountA,
      'group_id': groupId(7),
      'title': 'Legacy group',
      'description': '',
      'group_status': 'active',
      'member_role': 'student',
      'membership_status': 'active',
      'is_muted': 0,
      'active_student_count': 1,
      'pending_student_count': 0,
      'server_updated_at': instant.microsecondsSinceEpoch,
      'cached_at': instant.microsecondsSinceEpoch,
    });
    await old.close();

    final upgradedResource = GroupsDatabase(
      factory: databaseFactoryFfi,
      path: path,
    );
    final upgraded = await upgradedResource.open();
    addTearDown(upgradedResource.close);
    final upgradedStore = GroupsStore(
      database: upgraded,
      owner: GroupOwner(projectRef: project, userId: accountA),
    );
    addTearDown(upgradedStore.dispose);

    expect(await upgraded.getVersion(), 2);
    expect((await upgradedStore.list()).single.title, 'Legacy group');
    expect(
      await upgraded.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='learning_group_detail_sync'",
      ),
      hasLength(1),
    );
  });

  test('cache is isolated by project and account', () async {
    await store.reconcileSnapshot(
      groups: [summary(1)],
      completedAt: instant,
      isCurrent: () => true,
    );
    final accountBStore = GroupsStore(
      database: database,
      owner: GroupOwner(projectRef: project, userId: accountB),
    );
    final otherProjectStore = GroupsStore(
      database: database,
      owner: GroupOwner(projectRef: 'other-project', userId: accountA),
    );
    addTearDown(accountBStore.dispose);
    addTearDown(otherProjectStore.dispose);

    expect((await store.list()).single.id, groupId(1));
    expect(await accountBStore.list(), isEmpty);
    expect(await otherProjectStore.list(), isEmpty);
  });

  test('successful empty server snapshot purges lost group access', () async {
    await store.reconcileSnapshot(
      groups: [summary(1)],
      completedAt: instant,
      isCurrent: () => true,
    );
    remote.groups = [];

    await repository.refresh();

    expect(await repository.readCached(), isEmpty);
    expect(
        await repository.refreshedAt(), instant.add(const Duration(hours: 1)));
  });

  test('account switch rejects in-flight response before cache commit',
      () async {
    remote.barrier = Completer<List<LearningGroupSummary>>();
    final pending = repository.refresh();
    await Future<void>.delayed(Duration.zero);
    active = false;
    remote.barrier!.complete([summary(2)]);

    await expectLater(pending, throwsA(isA<GroupSessionChanged>()));
    expect(await store.list(), isEmpty);
  });

  test('create and join are online mutations followed by a safe refresh',
      () async {
    final created = await repository.createGroup(
      title: 'Class',
      description: '',
      requestId: '30000000-0000-4000-8000-000000000001',
    );
    final joined = await repository.requestJoin(
      inviteToken: inviteToken,
      requestId: '30000000-0000-4000-8000-000000000002',
    );

    expect(created, groupId(9));
    expect(joined, groupId(8));
    expect(remote.createCalls, 1);
    expect(remote.joinCalls, 1);
    expect(remote.listCalls, 2);
    expect((await repository.readCached()).map((item) => item.id),
        [groupId(9), groupId(8)]);
  });

  test('detail cache falls back offline and purges on revoked access',
      () async {
    remote.groups = [summary(1, role: LearningGroupRole.ownerTeacher)];
    remote.members = [
      LearningGroupMember(
        userId: student,
        displayName: 'Student',
        username: 'student',
        avatarUrl: null,
        role: LearningGroupRole.student,
        status: LearningGroupMembershipStatus.active,
        isMuted: false,
        updatedAt: instant,
      ),
    ];
    remote.announcements = [
      LearningGroupAnnouncement(
        id: announcementId,
        authorUserId: accountA,
        authorDisplayName: 'Teacher',
        body: 'Review lesson',
        isPinned: true,
        createdAt: instant,
        updatedAt: instant,
      ),
    ];
    remote.moderationEvents = [
      LearningGroupModerationEvent(
        id: 1,
        actorUserId: accountA,
        actorDisplayName: 'Teacher',
        targetUserId: student,
        targetDisplayName: 'Student',
        targetMessageId: null,
        action: 'member_muted',
        reasonCode: 'class_rule',
        occurredAt: instant,
      ),
    ];
    await repository.refresh();

    final online = await repository.loadDetails(
      groupId(1),
      includeManagement: true,
    );
    expect(online.offlineFallback, isFalse);
    expect(online.members.single.userId, student);
    expect(online.inviteStatus?.hasActiveInvite, isTrue);
    expect(online.moderationEvents.single.action, 'member_muted');

    final accountBStore = GroupsStore(
      database: database,
      owner: GroupOwner(projectRef: project, userId: accountB),
    );
    addTearDown(accountBStore.dispose);
    expect(await accountBStore.readDetails(groupId(1)), isNull);

    remote.detailFailure = const GroupException(
      GroupFailureKind.unavailable,
      'offline',
    );
    final offline = await repository.loadDetails(
      groupId(1),
      includeManagement: true,
    );
    expect(offline.offlineFallback, isTrue);
    expect(offline.announcements.single.body, 'Review lesson');

    remote.detailFailure = const GroupException(
      GroupFailureKind.denied,
      'revoked',
    );
    await expectLater(
      repository.loadDetails(groupId(1), includeManagement: true),
      throwsA(
        isA<GroupException>().having(
          (error) => error.kind,
          'kind',
          GroupFailureKind.denied,
        ),
      ),
    );
    expect(await store.readDetails(groupId(1)), isNull);
    expect(
      await database.query(
        'learning_group_moderation_event_cache',
        where: 'project_ref=? AND owner_id=? AND group_id=?',
        whereArgs: [project, accountA, groupId(1)],
      ),
      isEmpty,
    );
  });
}
