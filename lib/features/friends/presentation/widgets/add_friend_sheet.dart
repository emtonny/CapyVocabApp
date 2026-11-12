import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/app_user_avatar.dart';
import '../../domain/entities/friend_entity.dart';
import '../providers/friends_provider.dart';

Future<void> showAddFriendSheet(
  BuildContext context, {
  required FriendOwner owner,
}) {
  return showDialog<void>(
    context: context,
    useSafeArea: true,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 380,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.88,
        ),
        child: AddFriendSheet(owner: owner),
      ),
    ),
  );
}

class AddFriendSheet extends ConsumerStatefulWidget {
  const AddFriendSheet({super.key, required this.owner});

  final FriendOwner owner;

  @override
  ConsumerState<AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<AddFriendSheet> {
  final _queryController = TextEditingController();
  final _queryFocus = FocusNode();
  bool _closingForOwnerChange = false;
  bool _emptyQueryError = false;

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOwner = ref.watch(friendsOwnerProvider);
    if (activeOwner != widget.owner) {
      if (!_closingForOwnerChange) {
        _closingForOwnerChange = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
      }
      return const SizedBox.shrink();
    }
    final state = ref.watch(friendsSearchProvider(widget.owner));
    final notifier = ref.read(friendsSearchProvider(widget.owner).notifier);
    final result = state.result;
    final isSearching = state.phase == FriendSearchPhase.searching;
    final canSubmit = state.ready &&
        !state.isSending &&
        !isSearching &&
        state.validationMessage == null &&
        (result == null ||
            result.state == FriendRelationshipState.none ||
            result.state == FriendRelationshipState.incomingPending);

    void submit() {
      if (!canSubmit) return;
      if (result == null) {
        if (_queryController.text.trim().isEmpty) {
          setState(() => _emptyQueryError = true);
          _queryFocus.requestFocus();
          return;
        }
        setState(() => _emptyQueryError = false);
        notifier.searchNow();
        return;
      }

      switch (result.state) {
        case FriendRelationshipState.none:
          notifier.sendRequest();
        case FriendRelationshipState.incomingPending:
          Navigator.of(context).pop();
        case FriendRelationshipState.outgoingPending:
        case FriendRelationshipState.accepted:
        case FriendRelationshipState.rejected:
          return;
      }
    }

    final actionLabel = state.isSending
        ? 'Đang gửi…'
        : isSearching
            ? 'Đang tìm…'
            : result == null
                ? 'Kết Bạn'
                : _actionLabel(result.state);

    return Container(
      key: const Key('add-friend-sheet'),
      decoration: BoxDecoration(
        color: AppColors.softWhite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.softWhite,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Thêm Bạn Mới 👥',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Nhập username của bạn bè để kết nối học chung nhé!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('friend-search-field'),
                controller: _queryController,
                focusNode: _queryFocus,
                enabled: state.ready && !state.isSending,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 20,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                onChanged: (value) {
                  if (_emptyQueryError) {
                    setState(() => _emptyQueryError = false);
                  }
                  notifier.queryChanged(value);
                },
                onSubmitted: (_) => notifier.searchNow(),
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Ví dụ: deer_friend',
                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                  suffixIcon: state.phase == FriendSearchPhase.searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          ),
                        )
                      : state.query.isNotEmpty
                          ? IconButton(
                              key: const Key('friend-search-clear'),
                              tooltip: 'Xóa nội dung tìm kiếm',
                              onPressed: () {
                                _queryController.clear();
                                notifier.queryChanged('');
                                _queryFocus.requestFocus();
                              },
                              icon: const Icon(Icons.close_rounded),
                            )
                          : null,
                  errorText: state.validationMessage ??
                      (_emptyQueryError
                          ? 'Hãy nhập username bạn muốn tìm.'
                          : null),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: AppColors.ink, width: 2.5),
                  ),
                ),
              ),
              if (!state.ready)
                const _StatusPanel(
                  key: Key('friend-search-starting'),
                  icon: Icons.hourglass_top_rounded,
                  text: 'Đang chuẩn bị chức năng Bạn bè…',
                  progress: true,
                )
              else if (state.phase == FriendSearchPhase.waiting)
                const _StatusPanel(
                  key: Key('friend-search-waiting'),
                  icon: Icons.search_rounded,
                  text: 'Sẽ tìm sau khi bạn nhập xong.',
                )
              else if (state.phase == FriendSearchPhase.searching)
                const _StatusPanel(
                  key: Key('friend-search-loading'),
                  icon: Icons.travel_explore_rounded,
                  text: 'Đang tìm tài khoản…',
                  progress: true,
                )
              else if (state.phase == FriendSearchPhase.notFound)
                const _StatusPanel(
                  key: Key('friend-search-empty'),
                  icon: Icons.person_search_rounded,
                  text: 'Không tìm thấy tài khoản phù hợp.',
                )
              else if (state.phase == FriendSearchPhase.failure)
                _StatusPanel(
                  key: const Key('friend-search-error'),
                  icon: Icons.wifi_off_rounded,
                  text: state.message ?? 'Chưa thể tìm kiếm lúc này.',
                  action: TextButton.icon(
                    key: const Key('friend-search-retry'),
                    onPressed: notifier.retrySearch,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Thử lại'),
                  ),
                )
              else if (result != null) ...[
                const SizedBox(height: 4),
                _FriendResultCard(
                  connection: result,
                  message: state.message,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        key: const Key('cancel-add-friend'),
                        onPressed: state.isSending
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.ink,
                          elevation: 3,
                          shadowColor: AppColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: AppColors.ink,
                              width: 2,
                            ),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        key: const Key('friend-result-action'),
                        onPressed: canSubmit ? submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.ink,
                          disabledBackgroundColor:
                              AppColors.mutedInk.withValues(alpha: 0.12),
                          disabledForegroundColor: AppColors.mutedInk,
                          elevation: 3,
                          shadowColor: AppColors.ink,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(
                              color: AppColors.ink,
                              width: 2,
                            ),
                          ),
                        ),
                        icon: state.isSending || isSearching
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                result == null
                                    ? Icons.person_search_rounded
                                    : _actionIcon(result.state),
                              ),
                        label: Text(
                          actionLabel,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendResultCard extends StatelessWidget {
  const _FriendResultCard({
    required this.connection,
    required this.message,
  });

  final FriendConnection connection;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final profile = connection.profile;
    final displayName = profile.displayName.trim().isEmpty
        ? '@${profile.username}'
        : profile.displayName;
    final avatar = profile.avatarUrl?.trim();
    return Semantics(
      key: const Key('friend-search-result'),
      container: true,
      label:
          '$displayName, username ${profile.username}, streak ${profile.streakDays} ngày, cấp ${profile.userLevel}',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF9F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ink, width: 2.2),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppUserAvatar(
                  avatarUrl: avatar,
                  size: 52,
                  backgroundColor: AppColors.mint,
                  borderWidth: 0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '🔥 ${profile.streakDays} ngày  ·  Cấp ${profile.userLevel}',
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Semantics(
                liveRegion: true,
                child: Text(
                  message!,
                  key: const Key('friend-result-message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    super.key,
    required this.icon,
    required this.text,
    this.progress = false,
    this.action,
  });

  final IconData icon;
  final String text;
  final bool progress;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            progress
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : Icon(icon, color: AppColors.mutedInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}

String _actionLabel(FriendRelationshipState state) => switch (state) {
      FriendRelationshipState.none => 'Gửi lời mời',
      FriendRelationshipState.outgoingPending => 'Đã gửi',
      FriendRelationshipState.incomingPending => 'Xem lời mời',
      FriendRelationshipState.accepted => 'Đã là bạn',
      FriendRelationshipState.rejected => 'Đã từ chối',
    };

IconData _actionIcon(FriendRelationshipState state) => switch (state) {
      FriendRelationshipState.none => Icons.person_add_alt_1_rounded,
      FriendRelationshipState.outgoingPending => Icons.schedule_send_rounded,
      FriendRelationshipState.incomingPending =>
        Icons.mark_email_unread_outlined,
      FriendRelationshipState.accepted => Icons.people_alt_rounded,
      FriendRelationshipState.rejected => Icons.person_off_outlined,
    };
