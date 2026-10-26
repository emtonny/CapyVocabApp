import 'dart:async';

import 'package:capy_vocab/features/groups/domain/group_models.dart';
import 'package:capy_vocab/features/groups/domain/groups_repository.dart';
import 'package:capy_vocab/features/groups/presentation/groups_provider.dart';
import 'package:capy_vocab/features/groups/presentation/groups_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const ownerId = '10000000-0000-4000-8000-000000000001';
const studentId = '10000000-0000-4000-8000-000000000002';
const groupId = '20000000-0000-4000-8000-000000000001';
const announcementId = '30000000-0000-4000-8000-000000000001';
const taskId = '40000000-0000-4000-8000-000000000001';
final testOwner =
    GroupOwner(projectRef: 'nxteaznowkfennxpqjmt', userId: ownerId);

final class ScreenGroupsRepository implements GroupsRepository {
  ScreenGroupsRepository({
    required this.capabilities,
    required this.groups,
    this.members = const [],
    this.announcements = const [],
    this.inviteStatus,
    this.moderationEvents = const [],
    this.tasks = const [],
    this.studentOverviews = const [],
    this.sharedVocabulary = const [],
    this.vocabularySharing = false,
    this.offlineFallback = false,
  });

  final GroupCapabilities capabilities;
  final List<LearningGroupSummary> groups;
  final List<LearningGroupMember> members;
  final List<LearningGroupAnnouncement> announcements;
  final LearningGroupInviteStatus? inviteStatus;
  final List<LearningGroupModerationEvent> moderationEvents;
  final List<LearningGroupSystemTask> tasks;
  final List<LearningGroupStudentOverview> studentOverviews;
  final List<LearningGroupSharedVocabulary> sharedVocabulary;
  bool vocabularySharing;
  final bool offlineFallback;
  final signals = StreamController<GroupRemoteSignal>.broadcast();
  final approvedStudents = <String>[];

  @override
  Stream<GroupRemoteSignal> get remoteSignals => signals.stream;

  @override
  Stream<List<LearningGroupSummary>> watchCached() => Stream.value(groups);

  @override
  Future<List<LearningGroupSummary>> readCached() async => groups;

  @override
  Future<DateTime?> refreshedAt() async => DateTime.utc(2026, 10, 13, 8);

  @override
  Future<GroupCapabilities> getCapabilities() async => capabilities;

  @override
  Future<void> refresh() async {}

  @override
  Future<String> createGroup({
    required String title,
    required String description,
    required String requestId,
  }) async =>
      groupId;

  @override
  Future<String> requestJoin({
    required String inviteToken,
    required String requestId,
  }) async =>
      groupId;

  @override
  Future<List<LearningGroupMember>> listMembers(String groupId) async =>
      members;

  @override
  Future<List<LearningGroupAnnouncement>> listAnnouncements(
    String groupId,
  ) async =>
      announcements;

  @override
  Future<LearningGroupDetails> loadDetails(
    String groupId, {
    required bool includeManagement,
  }) async =>
      LearningGroupDetails(
        members: members,
        announcements: announcements,
        inviteStatus: includeManagement
            ? inviteStatus ??
                LearningGroupInviteStatus(
                  hasActiveInvite: false,
                  expiresAt: null,
                  useCount: 0,
                  lastUsedAt: null,
                  createdAt: null,
                )
            : null,
        moderationEvents: includeManagement ? moderationEvents : const [],
        includesManagement: includeManagement,
        refreshedAt: DateTime.utc(2026, 10, 20, 8),
        offlineFallback: offlineFallback,
      );

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
  }) async {
    if (approve) approvedStudents.add(studentUserId);
  }

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
      LearningGroupInviteSecret(
        token: List.filled(64, 'a').join(),
        expiresAt: expiresAt,
      );

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
  Future<void> dispose() => signals.close();
}

LearningGroupSummary groupSummary({
  LearningGroupRole role = LearningGroupRole.ownerTeacher,
  LearningGroupStatus status = LearningGroupStatus.active,
}) =>
    LearningGroupSummary(
      id: groupId,
      title: 'Lớp tiếng Anh A',
      description: '',
      status: status,
      role: role,
      membershipStatus: LearningGroupMembershipStatus.active,
      isMuted: false,
      activeStudentCount: 12,
      pendingStudentCount: 2,
      updatedAt: DateTime.utc(2026, 10, 13, 8),
    );

LearningGroupMember pendingStudent() => LearningGroupMember(
      userId: studentId,
      displayName: 'Học viên chờ duyệt',
      username: 'pending.student',
      avatarUrl: null,
      role: LearningGroupRole.student,
      status: LearningGroupMembershipStatus.pending,
      isMuted: false,
      updatedAt: DateTime.utc(2026, 10, 13, 8),
    );

LearningGroupAnnouncement announcement() => LearningGroupAnnouncement(
      id: announcementId,
      authorUserId: ownerId,
      authorDisplayName: 'Giáo viên Capy',
      body: 'Ôn 20 từ mới trước thứ Sáu.',
      isPinned: true,
      createdAt: DateTime.utc(2026, 10, 13, 8),
      updatedAt: DateTime.utc(2026, 10, 13, 8),
    );

LearningGroupModerationEvent moderationEvent() => LearningGroupModerationEvent(
      id: 1,
      actorUserId: ownerId,
      actorDisplayName: 'Giáo viên Capy',
      targetUserId: studentId,
      targetDisplayName: 'Học viên chờ duyệt',
      targetMessageId: null,
      action: 'join_approved',
      reasonCode: null,
      occurredAt: DateTime.utc(2026, 10, 20, 8),
    );

LearningGroupSystemTask systemTask({bool ownerView = true}) =>
    LearningGroupSystemTask(
      id: taskId,
      title: 'Học 10 từ mới',
      targetWordCount: 10,
      dueAt: DateTime.utc(2026, 10, 27, 8),
      status: 'active',
      createdAt: DateTime.utc(2026, 10, 20, 8),
      learnedWordCount: ownerView ? 0 : 4,
      masteryPercent: ownerView ? 0 : 40,
      progressStatus: ownerView ? 'owner_view' : 'in_progress',
      sharingEnabled: !ownerView,
      assignedStudentCount: ownerView ? 12 : 0,
      completedStudentCount: ownerView ? 4 : 0,
    );

LearningGroupStudentOverview learningOverview() => LearningGroupStudentOverview(
      userId: studentId,
      displayName: 'Học viên A',
      sharingEnabled: true,
      totalLearnedWordCount: 24,
      activeTaskCount: 2,
      completedTaskCount: 1,
      averageMasteryPercent: 75,
      lastLearnedAt: DateTime.utc(2026, 10, 20, 8),
    );

LearningGroupSharedVocabulary sharedWord() => LearningGroupSharedVocabulary(
      word: 'apple',
      firstLearnedAt: DateTime.utc(2026, 10, 19, 8),
      lastLearnedAt: DateTime.utc(2026, 10, 20, 8),
    );

Future<void> pumpGroups(
  WidgetTester tester,
  ScreenGroupsRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/groups',
    routes: [
      GoRoute(path: '/groups', builder: (_, __) => const GroupsScreen()),
      GoRoute(
        path: '/friends',
        builder: (_, __) => const Scaffold(body: Text('Friends')),
      ),
      for (final path in ['/home', '/storage', '/pet-shop', '/scan'])
        GoRoute(path: path, builder: (_, __) => const SizedBox.shrink()),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupsOwnerProvider.overrideWithValue(testOwner),
        groupsRepositoryProvider.overrideWith(
          (ref, owner) async => repository,
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('verified teacher sees management title and create action',
      (tester) async {
    await pumpGroups(
      tester,
      ScreenGroupsRepository(
        capabilities: const GroupCapabilities(
          accountRole: 'teacher',
          teacherVerificationStatus: 'verified',
          canManageGroups: true,
        ),
        groups: [groupSummary()],
      ),
    );

    expect(find.text('Quản lý lớp'), findsOneWidget);
    expect(find.byKey(const Key('groups-create')), findsOneWidget);
    expect(find.byKey(const Key('groups-join')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-card-$groupId')), findsOneWidget);
    expect(find.text('12/50 học viên · 2 chờ duyệt'), findsOneWidget);
  });

  testWidgets('pending teacher cannot see a management mutation',
      (tester) async {
    await pumpGroups(
      tester,
      ScreenGroupsRepository(
        capabilities: const GroupCapabilities(
          accountRole: 'teacher',
          teacherVerificationStatus: 'pending',
          canManageGroups: false,
        ),
        groups: const [],
      ),
    );

    expect(find.text('Nhóm của tôi'), findsOneWidget);
    expect(find.byKey(const Key('groups-create')), findsNothing);
    expect(find.byKey(const Key('groups-join')), findsOneWidget);
    expect(find.byKey(const Key('groups-teacher-pending-message')),
        findsOneWidget);
  });

  testWidgets('owner opens dashboard and approves pending student',
      (tester) async {
    final repository = ScreenGroupsRepository(
      capabilities: const GroupCapabilities(
        accountRole: 'teacher',
        teacherVerificationStatus: 'verified',
        canManageGroups: true,
      ),
      groups: [groupSummary()],
      members: [pendingStudent()],
      announcements: [announcement()],
      inviteStatus: LearningGroupInviteStatus(
        hasActiveInvite: true,
        expiresAt: DateTime.now().toUtc().add(const Duration(days: 7)),
        useCount: 2,
        lastUsedAt: DateTime.utc(2026, 10, 20, 7),
        createdAt: DateTime.utc(2026, 10, 19, 8),
      ),
      moderationEvents: [moderationEvent()],
    );
    await pumpGroups(tester, repository);

    await tester.tap(find.byKey(const ValueKey('group-card-$groupId')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-dashboard-list')), findsOneWidget);
    expect(find.text('Chờ duyệt: 1'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Học viên chờ duyệt'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const Key('group-dashboard-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Học viên chờ duyệt'), findsOneWidget);
    expect(find.text('Mã mời đang hoạt động'), findsOneWidget);

    final approve = find.byKey(
      const ValueKey('group-member-approve-$studentId'),
    );
    await tester.drag(
      find.byKey(const Key('group-dashboard-list')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(approve);
    await tester.pumpAndSettle();

    expect(repository.approvedStudents, [studentId]);

    await tester.scrollUntilVisible(
      find.text('Ôn 20 từ mới trước thứ Sáu.'),
      180,
      scrollable: find.descendant(
        of: find.byKey(const Key('group-dashboard-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Ôn 20 từ mới trước thứ Sáu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owner sees aggregate progress and text-only learned words',
      (tester) async {
    final repository = ScreenGroupsRepository(
      capabilities: const GroupCapabilities(
        accountRole: 'teacher',
        teacherVerificationStatus: 'verified',
        canManageGroups: true,
      ),
      groups: [groupSummary()],
      tasks: [systemTask()],
      studentOverviews: [learningOverview()],
      sharedVocabulary: [sharedWord()],
    );
    await pumpGroups(tester, repository);

    await tester.tap(find.byKey(const ValueKey('group-card-$groupId')));
    await tester.pumpAndSettle();

    expect(find.text('Học 10 từ mới'), findsOneWidget);
    expect(find.text('4/12 học viên hoàn thành'), findsOneWidget);
    final vocabularyButton = find.byKey(
      const ValueKey('group-student-vocabulary-$studentId'),
    );
    await tester.dragUntilVisible(
      vocabularyButton,
      find.byKey(const Key('group-dashboard-list')),
      const Offset(0, -200),
    );
    await tester.tap(vocabularyButton);
    await tester.pumpAndSettle();

    expect(find.text('Từ đã học · Học viên A'), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
    expect(find.textContaining('capy_scans'), findsNothing);
    expect(find.textContaining('bounding'), findsNothing);
  });

  testWidgets('student explicitly enables text-only progress sharing',
      (tester) async {
    final repository = ScreenGroupsRepository(
      capabilities: const GroupCapabilities(
        accountRole: 'student',
        teacherVerificationStatus: 'not_applicable',
        canManageGroups: false,
      ),
      groups: [groupSummary(role: LearningGroupRole.student)],
      tasks: [systemTask(ownerView: false)],
    );
    await pumpGroups(tester, repository);

    await tester.tap(find.byKey(const ValueKey('group-card-$groupId')));
    await tester.pumpAndSettle();

    final sharing = find.byKey(const Key('group-vocabulary-sharing'));
    await tester.dragUntilVisible(
      sharing,
      find.byKey(const Key('group-dashboard-list')),
      const Offset(0, -160),
    );
    expect(
      find.text(
        'Giáo viên chỉ thấy từ đã học và tổng tiến độ; không thấy ảnh, vị trí ảnh hoặc dữ liệu Vision.',
      ),
      findsOneWidget,
    );
    await tester.tap(sharing);
    await tester.pumpAndSettle();

    expect(repository.vocabularySharing, isTrue);
    expect(find.text('4/10 từ · 40%'), findsOneWidget);
    expect(find.byKey(const Key('group-learning-task-create')), findsNothing);
  });

  testWidgets('student dashboard hides owner-only management data',
      (tester) async {
    await pumpGroups(
      tester,
      ScreenGroupsRepository(
        capabilities: const GroupCapabilities(
          accountRole: 'personal',
          teacherVerificationStatus: null,
          canManageGroups: false,
        ),
        groups: [groupSummary(role: LearningGroupRole.student)],
        members: [pendingStudent()],
        announcements: [announcement()],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('group-card-$groupId')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-invite-status')), findsNothing);
    expect(find.byKey(const Key('group-invite-rotate')), findsNothing);
    expect(find.byKey(const Key('group-archive')), findsNothing);
    expect(find.text('Nhật ký quản trị'), findsNothing);
  });

  testWidgets('archived owner sees read-only audit and offline cache timestamp',
      (tester) async {
    await pumpGroups(
      tester,
      ScreenGroupsRepository(
        capabilities: const GroupCapabilities(
          accountRole: 'teacher',
          teacherVerificationStatus: 'verified',
          canManageGroups: true,
        ),
        groups: [groupSummary(status: LearningGroupStatus.archived)],
        moderationEvents: [moderationEvent()],
        offlineFallback: true,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('group-card-$groupId')));
    await tester.pumpAndSettle();

    expect(find.textContaining('chế độ chỉ đọc'), findsOneWidget);
    expect(find.textContaining('Đang xem dữ liệu đã lưu lúc'), findsOneWidget);
    expect(find.byKey(const Key('group-invite-rotate')), findsNothing);
    expect(find.byKey(const Key('group-archive')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('group-audit-1')),
      180,
      scrollable: find.descendant(
        of: find.byKey(const Key('group-dashboard-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Đã duyệt Học viên chờ duyệt'), findsOneWidget);
  });

  testWidgets('320px and text scale 1.3 render without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await pumpGroups(
      tester,
      ScreenGroupsRepository(
        capabilities: const GroupCapabilities(
          accountRole: 'teacher',
          teacherVerificationStatus: 'verified',
          canManageGroups: true,
        ),
        groups: [groupSummary()],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byKey(const Key('groups-create'))).height, 48);
    expect(tester.getSize(find.byKey(const Key('groups-join'))).height, 48);

    await tester.tap(find.byKey(const ValueKey('group-card-$groupId')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-dashboard-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
