import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/group_models.dart';
import '../domain/groups_repository.dart';
import 'groups_provider.dart';

typedef GroupLearningKey = ({
  GroupOwner owner,
  String groupId,
  bool isOwner,
});

final groupLearningProvider = StateNotifierProvider.autoDispose
    .family<GroupLearningNotifier, GroupLearningState, GroupLearningKey>(
  (ref, key) => GroupLearningNotifier(
    groupId: key.groupId,
    isOwner: key.isOwner,
    repository: ref.watch(groupsRepositoryProvider(key.owner)).asData?.value,
  ),
);

final class GroupLearningState {
  const GroupLearningState({
    this.ready = false,
    this.tasks = const [],
    this.students = const [],
    this.sharingEnabled = false,
    this.isRefreshing = false,
    this.isMutating = false,
    this.message,
  });

  final bool ready;
  final List<LearningGroupSystemTask> tasks;
  final List<LearningGroupStudentOverview> students;
  final bool sharingEnabled;
  final bool isRefreshing;
  final bool isMutating;
  final String? message;

  GroupLearningState copyWith({
    bool? ready,
    List<LearningGroupSystemTask>? tasks,
    List<LearningGroupStudentOverview>? students,
    bool? sharingEnabled,
    bool? isRefreshing,
    bool? isMutating,
    Object? message = _unsetLearning,
  }) =>
      GroupLearningState(
        ready: ready ?? this.ready,
        tasks: tasks ?? this.tasks,
        students: students ?? this.students,
        sharingEnabled: sharingEnabled ?? this.sharingEnabled,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isMutating: isMutating ?? this.isMutating,
        message: identical(message, _unsetLearning)
            ? this.message
            : message as String?,
      );
}

const Object _unsetLearning = Object();

final class GroupLearningNotifier extends StateNotifier<GroupLearningState> {
  GroupLearningNotifier({
    required this.groupId,
    required this.isOwner,
    required GroupsRepository? repository,
  })  : _repository = repository,
        super(const GroupLearningState()) {
    requireGroupUuid(groupId, 'groupId');
    if (repository != null) unawaited(refresh());
  }

  final String groupId;
  final bool isOwner;
  final GroupsRepository? _repository;
  bool _disposed = false;

  Future<void> refresh() async {
    final repository = _repository;
    if (repository == null || _disposed || state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true, message: null);
    try {
      final results = await Future.wait<Object?>([
        repository.listSystemTasks(groupId),
        if (isOwner)
          repository.listLearningOverview(groupId)
        else
          repository.getVocabularySharing(groupId),
      ]);
      if (_disposed) return;
      state = state.copyWith(
        ready: true,
        tasks: results[0] as List<LearningGroupSystemTask>,
        students: isOwner
            ? results[1] as List<LearningGroupStudentOverview>
            : const [],
        sharingEnabled: isOwner ? false : results[1] as bool,
        isRefreshing: false,
      );
    } on GroupException catch (error) {
      if (_disposed) return;
      final revoke = error.kind == GroupFailureKind.denied ||
          error.kind == GroupFailureKind.unauthenticated ||
          error.kind == GroupFailureKind.notFound;
      state = state.copyWith(
        ready: true,
        tasks: revoke ? const [] : null,
        students: revoke ? const [] : null,
        sharingEnabled: revoke ? false : null,
        isRefreshing: false,
        message: error.message,
      );
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          ready: true,
          isRefreshing: false,
          message: 'Chưa tải được tiến độ học tập.',
        );
      }
    }
  }

  Future<bool> setVocabularySharing(bool enabled) => _mutate(
        () => _repository!.setVocabularySharing(
          groupId: groupId,
          enabled: enabled,
        ),
      );

  Future<bool> createSystemTask({
    required String title,
    required int targetWordCount,
    required int dueDays,
  }) =>
      _mutate(() async {
        await _repository!.createSystemTask(
          groupId: groupId,
          title: title,
          targetWordCount: targetWordCount,
          dueAt: DateTime.now().toUtc().add(Duration(days: dueDays)),
          requestId: createGroupRequestId(),
        );
      });

  Future<bool> closeSystemTask(String taskId) => _mutate(
        () => _repository!.closeSystemTask(
          groupId: groupId,
          taskId: taskId,
          requestId: createGroupRequestId(),
        ),
      );

  Future<List<LearningGroupSharedVocabulary>?> loadStudentVocabulary(
    String studentUserId,
  ) async {
    final repository = _repository;
    if (repository == null || _disposed || state.isMutating) return null;
    state = state.copyWith(isMutating: true, message: null);
    try {
      final result = await repository.listStudentVocabulary(
        groupId: groupId,
        studentUserId: studentUserId,
      );
      if (!_disposed) state = state.copyWith(isMutating: false);
      return result;
    } on GroupException catch (error) {
      if (!_disposed) {
        state = state.copyWith(isMutating: false, message: error.message);
      }
      return null;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          isMutating: false,
          message: 'Không tải được danh sách từ vựng.',
        );
      }
      return null;
    }
  }

  Future<bool> _mutate(Future<void> Function() action) async {
    if (_repository == null || _disposed || state.isMutating) return false;
    state = state.copyWith(isMutating: true, message: null);
    try {
      await action();
      if (!_disposed) state = state.copyWith(isMutating: false);
      await refresh();
      return true;
    } on GroupException catch (error) {
      if (!_disposed) {
        state = state.copyWith(isMutating: false, message: error.message);
      }
      return false;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          isMutating: false,
          message: 'Không thể cập nhật tiến độ lúc này.',
        );
      }
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
