import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/friend_entity.dart';
import '../providers/friends_provider.dart';

Future<void> showAddFriendSheet(
  BuildContext context, {
  required FriendOwner owner,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(context).height * 0.92,
          ),
          child: AddFriendSheet(owner: owner),
        ),
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

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _selectMethod(FriendSearchMethod method) {
    ref.read(friendsSearchProvider(widget.owner).notifier).selectMethod(method);
    _queryController.clear();
    _queryFocus.requestFocus();
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
    return Material(
      key: const Key('add-friend-sheet'),
      color: AppColors.softWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: AppColors.ink, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.mutedInk.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thêm bạn',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('add-friend-close'),
                  tooltip: 'Đóng',
                  constraints:
                      const BoxConstraints.tightFor(width: 48, height: 48),
                  onPressed: state.isSending
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              'Tìm chính xác bằng username, email hoặc số điện thoại.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.35,
                color: AppColors.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FriendSearchMethod.values.map((method) {
                return Semantics(
                  button: true,
                  selected: state.method == method,
                  label: 'Tìm bằng ${_methodLabel(method)}',
                  child: ChoiceChip(
                    key: Key('friend-method-${method.wireValue}'),
                    label: Text(_methodLabel(method)),
                    selected: state.method == method,
                    onSelected:
                        state.isSending ? null : (_) => _selectMethod(method),
                    selectedColor: AppColors.yellow,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.ink, width: 1.8),
                    labelStyle: const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('friend-search-field'),
              controller: _queryController,
              focusNode: _queryFocus,
              enabled: state.ready && !state.isSending,
              keyboardType: _keyboardType(state.method),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: state.method == FriendSearchMethod.username ? 20 : 320,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              inputFormatters: state.method == FriendSearchMethod.phone
                  ? [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[+0-9\s().-]'),
                      ),
                    ]
                  : null,
              onChanged: notifier.queryChanged,
              onSubmitted: (_) => notifier.searchNow(),
              decoration: InputDecoration(
                labelText: _fieldLabel(state.method),
                hintText: _fieldHint(state.method),
                prefixIcon: Icon(_methodIcon(state.method)),
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
                errorText: state.validationMessage,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.ink, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.ink, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: AppColors.blue, width: 2.5),
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
            else if (state.result case final result?) ...[
              const SizedBox(height: 4),
              _FriendResultCard(
                connection: result,
                isSending: state.isSending,
                message: state.message,
                onSend: notifier.sendRequest,
                onViewIncoming: () => Navigator.of(context).pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FriendResultCard extends StatelessWidget {
  const _FriendResultCard({
    required this.connection,
    required this.isSending,
    required this.message,
    required this.onSend,
    required this.onViewIncoming,
  });

  final FriendConnection connection;
  final bool isSending;
  final String? message;
  final VoidCallback onSend;
  final VoidCallback onViewIncoming;

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
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.mint,
                  foregroundImage: avatar == null || avatar.isEmpty
                      ? null
                      : NetworkImage(avatar),
                  child: const Icon(Icons.person_rounded, color: AppColors.ink),
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
            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                key: const Key('friend-result-action'),
                onPressed: isSending
                    ? null
                    : switch (connection.state) {
                        FriendRelationshipState.none => onSend,
                        FriendRelationshipState.incomingPending =>
                          onViewIncoming,
                        _ => null,
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: AppColors.ink,
                  disabledBackgroundColor:
                      AppColors.mutedInk.withValues(alpha: 0.12),
                  disabledForegroundColor: AppColors.mutedInk,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.ink, width: 2),
                  ),
                ),
                icon: isSending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_actionIcon(connection.state)),
                label: Text(
                  isSending ? 'Đang gửi…' : _actionLabel(connection.state),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
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

String _methodLabel(FriendSearchMethod method) => switch (method) {
      FriendSearchMethod.username => 'Username',
      FriendSearchMethod.email => 'Email',
      FriendSearchMethod.phone => 'Số điện thoại',
    };

String _fieldLabel(FriendSearchMethod method) => switch (method) {
      FriendSearchMethod.username => 'Username',
      FriendSearchMethod.email => 'Email chính xác',
      FriendSearchMethod.phone => 'Số điện thoại Việt Nam',
    };

String _fieldHint(FriendSearchMethod method) => switch (method) {
      FriendSearchMethod.username => 'ví dụ: deer_friend',
      FriendSearchMethod.email => 'ví dụ: ban@example.com',
      FriendSearchMethod.phone => 'ví dụ: 0912345678',
    };

IconData _methodIcon(FriendSearchMethod method) => switch (method) {
      FriendSearchMethod.username => Icons.alternate_email_rounded,
      FriendSearchMethod.email => Icons.mail_outline_rounded,
      FriendSearchMethod.phone => Icons.phone_outlined,
    };

TextInputType _keyboardType(FriendSearchMethod method) => switch (method) {
      FriendSearchMethod.username => TextInputType.text,
      FriendSearchMethod.email => TextInputType.emailAddress,
      FriendSearchMethod.phone => TextInputType.phone,
    };

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
