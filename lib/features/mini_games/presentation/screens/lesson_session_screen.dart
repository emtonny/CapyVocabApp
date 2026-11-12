import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/graph_paper_background.dart';
import '../../../../shared/widgets/sticker_button.dart';
import '../../../library/presentation/providers/library_provider.dart';
import '../../application/lesson_question_builder.dart';
import '../../application/lesson_session_controller.dart';
import '../../application/lesson_source_builder.dart';
import '../../domain/lesson_session.dart';
import '../../photo_letter_fill/presentation/screens/photo_letter_fill_screen.dart';
import '../../photo_letter_fill/presentation/screens/photo_multi_fill_screen.dart';
import '../../photo_order_quiz/presentation/screens/photo_order_quiz_screen.dart';
import '../providers/lesson_session_provider.dart';
import '../providers/lesson_completion_sync_provider.dart';

class LessonSessionScreen extends ConsumerStatefulWidget {
  const LessonSessionScreen({required this.request, super.key});

  final LessonStartRequest request;

  @override
  ConsumerState<LessonSessionScreen> createState() =>
      _LessonSessionScreenState();
}

class _LessonSessionScreenState extends ConsumerState<LessonSessionScreen>
    with WidgetsBindingObserver {
  LessonSessionController? _controller;
  Timer? _checkpointTimer;
  String? _draftJson;
  String? _visibleQuestionId;
  bool _leaving = false;
  Object? _initializationError;

  DailyLessonSessionKey? get _sessionKey {
    final request = widget.request;
    return request is DailyLessonStartRequest
        ? (userId: request.userId, missionDate: request.missionDate)
        : null;
  }

  String get _exitLabel =>
      widget.request is ReviewLessonStartRequest ? 'Về Library' : 'Về Home';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final currentUserId = ref.read(currentLibraryUserIdProvider);
    if (currentUserId != widget.request.userId) {
      if (mounted) {
        setState(() {
          _initializationError = StateError(
            'Phiên đăng nhập không khớp chủ sở hữu bài học.',
          );
        });
      }
      return;
    }
    final store = await ref.read(lessonSessionStoreProvider.future);
    final repository = await ref.read(libraryRepositoryProvider.future);
    if (!mounted) return;
    final controller = LessonSessionController(
      store: store,
      sourceLoader: LessonSourceLoader(
        repository: repository,
        mediaLoader: ref.read(libraryMediaLoaderProvider),
      ),
      sessionIdFactory: _newId,
      questionIdFactory: _newId,
      attemptIdFactory: _newId,
    );
    controller.addListener(_onControllerChanged);
    setState(() => _controller = controller);
    switch (widget.request) {
      case DailyLessonStartRequest request:
        await controller.openDaily(request);
      case ReviewLessonStartRequest request:
        await controller.openReview(request);
      case RewardedReplayLessonStartRequest request:
        await controller.openRewardedReplay(request);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final state = _controller!.state;
    final questionId = state.question?.id;
    if (questionId != null && questionId != _visibleQuestionId) {
      _visibleQuestionId = questionId;
      _draftJson = state.session?.draftJson;
    }
    if (state.phase != LessonFlowPhase.answering) {
      _checkpointTimer?.cancel();
    }
    if (state.phase == LessonFlowPhase.feedback) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    final sessionKey = _sessionKey;
    if (sessionKey != null) {
      ref.invalidate(dailyLessonSessionProvider(sessionKey));
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_pauseWithoutLeaving());
    } else if (state == AppLifecycleState.resumed) {
      final controller = _controller;
      if (controller != null) {
        unawaited(controller.resume(now: DateTime.now().toUtc()));
      }
    }
  }

  void _onDraftChanged(String draftJson) {
    _draftJson = draftJson;
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer(const Duration(milliseconds: 350), () {
      final controller = _controller;
      if (controller != null) {
        unawaited(controller.checkpointDraft(draftJson));
      }
    });
  }

  Future<void> _pauseWithoutLeaving() async {
    _checkpointTimer?.cancel();
    final controller = _controller;
    if (controller == null ||
        controller.state.phase == LessonFlowPhase.paused) {
      return;
    }
    await controller.pause(draftJson: _draftJson, now: DateTime.now().toUtc());
  }

  Future<void> _leave({bool toHome = false}) async {
    if (_leaving) return;
    _leaving = true;
    await _pauseWithoutLeaving();
    if (!mounted) return;
    if (_controller?.state.phase == LessonFlowPhase.error) {
      _leaving = false;
      return;
    }
    final sessionKey = _sessionKey;
    if (sessionKey != null) {
      ref.invalidate(dailyLessonSessionProvider(sessionKey));
    }
    if (toHome) {
      context.go('/home');
    } else {
      context.pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkpointTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller
        ..removeListener(_onControllerChanged)
        ..dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final state = controller?.state ?? const LessonFlowState.loading();
    return Theme(
      // Lesson surfaces currently use an always-light graph-paper canvas.
      // Keep inherited Material colors aligned with that canvas even when the
      // device is in dark mode; otherwise labels and icons become near-white.
      data: AppTheme.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_leave());
        },
        child: GraphPaperScaffold(
          maxContentWidth: 760,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Center(
                child: SizedBox.square(
                  dimension: 44,
                  child: StickerButton(
                    key: const Key('lesson-close'),
                    semanticLabel: 'Đóng và lưu bài học',
                    onPressed: _leave,
                    icon: const Icon(Icons.close_rounded),
                    surfaceColor: AppColors.softWhite,
                    radius: 14,
                    padding: EdgeInsets.zero,
                    fontSize: 18,
                    minHeight: 44,
                    expand: true,
                  ),
                ),
              ),
            ),
            title: _LessonProgress(session: state.session),
            actions: [
              if (state.session?.status == LessonSessionStatus.active &&
                  {
                    LessonFlowPhase.answering,
                    LessonFlowPhase.feedback,
                    LessonFlowPhase.paused,
                  }.contains(state.phase))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 80,
                    height: 44,
                    child: StickerButton(
                      key: const Key('lesson-home'),
                      semanticLabel: 'Về trang chủ và lưu bài học',
                      onPressed: () => _leave(toHome: true),
                      text: 'Home',
                      surfaceColor: AppColors.softWhite,
                      radius: 14,
                      padding: EdgeInsets.zero,
                      fontSize: 18,
                      minHeight: 44,
                      expand: true,
                    ),
                  ),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: _initializationError == null
                ? _buildBody(state, controller)
                : _statusBody(
                    icon: Icons.lock_outline,
                    title: 'Không thể mở bài học',
                    message: '$_initializationError',
                    actionLabel: _exitLabel,
                    onAction: () => context.pop(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    LessonFlowState state,
    LessonSessionController? controller,
  ) {
    if (controller == null || state.phase == LessonFlowPhase.loading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('lesson-loading')),
      );
    }
    switch (state.phase) {
      case LessonFlowPhase.ready:
      case LessonFlowPhase.submitting:
        return const Center(child: CircularProgressIndicator());
      case LessonFlowPhase.answering:
        return _questionBody(state, enabled: true);
      case LessonFlowPhase.feedback:
        return _feedbackBody(state);
      case LessonFlowPhase.completed:
        return _completionBody(state.session!);
      case LessonFlowPhase.empty:
        final request = widget.request;
        return _statusBody(
          icon: Icons.add_a_photo_outlined,
          title: 'Chưa đủ từ có vùng nhận diện',
          message: request is ReviewLessonStartRequest
              ? 'Photo Note đã chọn chưa có từ kèm vùng đồ vật hợp lệ trên máy.'
              : 'Snapshot của bài học chưa còn đủ ảnh local để bắt đầu.',
          actionLabel: _exitLabel,
          onAction: _leave,
        );
      case LessonFlowPhase.blocked:
        return _statusBody(
          icon: Icons.broken_image_outlined,
          title: 'Bài học đang bị chặn',
          message:
              'Một ảnh nguồn đã bị xóa hoặc không còn trên máy. Tiến trình vẫn được giữ nguyên.',
          actionLabel: _exitLabel,
          onAction: _leave,
        );
      case LessonFlowPhase.abandoned:
        return _statusBody(
          icon: Icons.flag_outlined,
          title: 'Đã bỏ bài',
          message:
              'Tiến trình đã lưu, nhưng bài này không còn quyền nhận thưởng.',
          actionLabel: _exitLabel,
          onAction: _leave,
        );
      case LessonFlowPhase.expired:
        return _statusBody(
          icon: Icons.event_busy_outlined,
          title: 'Nhiệm vụ đã hết hạn',
          message:
              'Bạn có thể chọn từ trong Library để tạo một phiên ôn lại mới.',
          actionLabel: _exitLabel,
          onAction: _leave,
        );
      case LessonFlowPhase.paused:
        return _statusBody(
          icon: Icons.pause_circle_outline,
          title: 'Đã lưu tiến trình',
          message: 'Bạn có thể tiếp tục từ Home bất cứ lúc nào.',
          actionLabel: _exitLabel,
          onAction: _leave,
        );
      case LessonFlowPhase.error:
        return _statusBody(
          icon: Icons.error_outline,
          title: 'Chưa mở được bài học',
          message: '${state.error ?? 'Lỗi không xác định'}',
          actionLabel: 'Thử lại',
          onAction: () {
            switch (widget.request) {
              case DailyLessonStartRequest request:
                unawaited(controller.openDaily(request));
              case ReviewLessonStartRequest request:
                unawaited(controller.openReview(request));
              case RewardedReplayLessonStartRequest request:
                unawaited(controller.openRewardedReplay(request));
            }
          },
        );
      case LessonFlowPhase.loading:
        return const SizedBox.shrink();
    }
  }

  Widget _questionBody(LessonFlowState state, {required bool enabled}) {
    return SingleChildScrollView(
      key: const Key('lesson-question-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: _questionContent(state, enabled: enabled),
    );
  }

  Widget _questionContent(
    LessonFlowState state, {
    required bool enabled,
    String? draftJson,
  }) {
    final question = state.question!;
    final session = state.session!;
    final mediaLoader = ref.read(libraryMediaLoaderProvider);
    final itemById = {for (final item in session.items) item.id: item};
    final content = switch (question) {
      BuiltPhotoMultiFillQuestion fill => PhotoMultiFillScreen(
          key: ValueKey(fill.id),
          question: fill,
          items: [for (final id in fill.itemIds) itemById[id]!],
          mediaLoader: mediaLoader,
          initialDraftJson: draftJson ?? session.draftJson,
          enabled: enabled,
          onChanged: _onDraftChanged,
          onSubmit: _controller!.submitMultiFill,
          loadHints: (item) async {
            final repository = await ref.read(libraryRepositoryProvider.future);
            final snapshot = await repository.getPhotoNoteSnapshot(
                userId: session.userId, photoNoteId: item.photoNoteId);
            return buildLessonWordHints(item, snapshot);
          },
        ),
      BuiltPhotoOrderQuestion order => PhotoOrderQuizScreen(
          key: ValueKey(order.id),
          question: order,
          sequential: session.requiresBothGames,
          items: [for (final id in order.itemIds) itemById[id]!],
          mediaLoader: mediaLoader,
          initialDraftJson: draftJson ?? session.draftJson,
          enabled: enabled,
          onChanged: _onDraftChanged,
          onSubmit: _controller!.submitOrder,
        ),
      BuiltPhotoLetterFillQuestion fill => PhotoLetterFillScreen(
          key: ValueKey(fill.id),
          question: fill,
          item: itemById[fill.question.itemId]!,
          mediaLoader: mediaLoader,
          initialDraftJson: draftJson ?? session.draftJson,
          enabled: enabled,
          onChanged: _onDraftChanged,
          onSubmit: _controller!.submitLetterFill,
        ),
    };
    return content;
  }

  Widget _feedbackBody(LessonFlowState state) {
    final attempt = state.feedbackAttempt!;
    final itemById = {
      for (final item in state.session!.items) item.id: item,
    };
    final correct = attempt.verdicts.where((item) => item.isCorrect).length;
    return Stack(
      fit: StackFit.expand,
      children: [
        _questionBody(state, enabled: false),
        BlockSemantics(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: .28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    key: const Key('lesson-feedback'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: correct == attempt.verdicts.length
                          ? AppColors.mint
                          : AppColors.yellow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink,
                          offset: Offset(3, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '$correct/${attempt.verdicts.length} từ đúng',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        for (final verdict in attempt.verdicts.where(
                          (item) => !item.isCorrect,
                        ))
                          Text(
                            'Đáp án: ${itemById[verdict.itemId]!.answer}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        const SizedBox(height: 12),
                        if (_controller!.advancesToFill) ...[
                          const Text(
                            'Đã xong game 1! Bạn muốn về Home hay tiếp tục game 2?',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                          StickerButton(
                            key: const Key('lesson-game-one-home'),
                            text: 'Về Home',
                            onPressed: () => _leave(toHome: true),
                            surfaceColor: AppColors.softWhite,
                            textColor: AppColors.ink,
                            radius: 16,
                            minHeight: 52,
                            expand: true,
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: StickerButton(
                            key: const Key('lesson-feedback-continue'),
                            text: _controller!.advancesToFill
                                ? 'Tiếp đến game điền từ'
                                : 'Tiếp tục',
                            onPressed: _controller!.continueAfterFeedback,
                            surfaceColor: AppColors.duoGreen,
                            edgeColor: const Color(0xFF3A8F0A),
                            textColor: Colors.white,
                            radius: 16,
                            fontSize: 16,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            minHeight: 52,
                            expand: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBody({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
    Key? key,
    String? secondaryActionLabel,
    VoidCallback? onSecondaryAction,
  }) {
    return Center(
      key: key,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.softWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(0, 5),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppColors.darkGreen),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: StickerButton(
                  text: actionLabel,
                  onPressed: onAction,
                  surfaceColor: AppColors.duoGreen,
                  edgeColor: const Color(0xFF3A8F0A),
                  textColor: Colors.white,
                  radius: 16,
                  fontSize: 15,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  minHeight: 52,
                  expand: true,
                ),
              ),
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _completionBody(LessonSession session) {
    if (widget.request is ReviewLessonStartRequest) {
      return _statusBody(
        key: const Key('lesson-completion-review'),
        icon: Icons.celebration_rounded,
        title: 'Hoàn thành 100%!',
        message: 'Phiên ôn lại đã được lưu trên máy và không tạo phần thưởng.',
        actionLabel: _exitLabel,
        onAction: _leave,
      );
    }
    final completion = ref
        .watch(
          lessonCompletionProvider((
            userId: session.userId,
            sessionId: session.id,
          )),
        )
        .valueOrNull;
    final pendingYuzu = _projectedYuzu(
      session.mastery.totalCount,
      switch (widget.request) {
        DailyLessonStartRequest request => request.targetWords,
        RewardedReplayLessonStartRequest request => request.targetWords,
        ReviewLessonStartRequest _ => session.mastery.totalCount,
      },
    );
    final displayedPendingYuzu =
        widget.request is RewardedReplayLessonStartRequest
            ? pendingYuzu ~/ 3
            : pendingYuzu;
    switch (completion?.syncStatus) {
      case LessonCompletionSyncStatus.synced:
        final rewardMessage = switch (completion?.rewardStatus) {
          LessonRewardStatus.awarded =>
            '${completion!.rewardYuzu} xu vàng đã được cộng vào số dư'
                '${completion.weeklyYuzu == 0 ? '' : ' và xu vàng tuần'}.',
          LessonRewardStatus.rejected => switch (completion?.rewardTiming) {
              LessonRewardTiming.expired =>
                'Kết quả được xác nhận nhưng đã quá hạn nhận thưởng.',
              _ =>
                'Kết quả được xác nhận nhưng lượt này không phát sinh thưởng.',
            },
          _ => 'Server đã xác nhận kết quả và đang hoàn tất chốt thưởng.',
        };
        return _statusBody(
          key: const Key('lesson-completion-synced'),
          icon: Icons.cloud_done_rounded,
          title: 'Đã đồng bộ',
          message: 'Server đã xác nhận kết quả 100%. $rewardMessage',
          actionLabel: _exitLabel,
          onAction: _leave,
        );
      case LessonCompletionSyncStatus.failed:
        return _statusBody(
          key: const Key('lesson-completion-sync-failed'),
          icon: Icons.sync_problem_rounded,
          title: 'Đồng bộ lỗi',
          message:
              'Kết quả và $displayedPendingYuzu xu vàng chờ vẫn được giữ trên máy. '
              'Bạn không cần chơi lại.',
          actionLabel: 'Thử đồng bộ lại',
          onAction: () => unawaited(
            retryLessonCompletionSync(
              ref,
              userId: session.userId,
              resultId: completion!.id,
            ),
          ),
          secondaryActionLabel: _exitLabel,
          onSecondaryAction: _leave,
        );
      case LessonCompletionSyncStatus.notApplicable:
        return _statusBody(
          key: const Key('lesson-completion-local'),
          icon: Icons.save_rounded,
          title: 'Hoàn thành 100%!',
          message: 'Kết quả đã được lưu trên máy.',
          actionLabel: _exitLabel,
          onAction: _leave,
        );
      case LessonCompletionSyncStatus.pending:
      case LessonCompletionSyncStatus.syncing:
      case null:
        return _statusBody(
          key: const Key('lesson-completion-pending'),
          icon: Icons.cloud_upload_outlined,
          title: 'Đã hoàn thành — chờ đồng bộ',
          message: 'Kết quả đã được lưu trên máy. '
              '$displayedPendingYuzu xu vàng đang chờ, chưa thể chi tiêu và chưa được '
              'tính vào bảng xếp hạng.',
          actionLabel: _exitLabel,
          onAction: _leave,
        );
    }
  }
}

class _LessonProgress extends StatelessWidget {
  const _LessonProgress({required this.session});

  final LessonSession? session;

  @override
  Widget build(BuildContext context) {
    final current = session?.mastery.completedCount ?? 0;
    final total = session?.mastery.totalCount ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          total == 0 ? 'Bài học hôm nay' : '$current/$total từ',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 150,
          child: LinearProgressIndicator(
            key: const Key('lesson-mastery-progress'),
            value: total == 0 ? 0 : current / total,
            minHeight: 8,
            color: AppColors.duoGreen,
            backgroundColor: AppColors.yellow.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
  }
}

String _newId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

int _projectedYuzu(int completedItems, int targetWords) {
  if (completedItems < targetWords) return 0;
  if (completedItems >= targetWords * 2) return 150;
  if (completedItems * 2 >= targetWords * 3) return 130;
  return 100;
}
