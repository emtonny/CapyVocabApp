import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Places transient app messages at the top of the current viewport.
///
/// A [SnackBar] is accepted to preserve the existing message API while
/// avoiding the default bottom placement, which can overlap fixed bottom
/// actions and navigation. The host preserves its duration and action.
class TopNotificationHost extends StatefulWidget {
  const TopNotificationHost({required this.child, super.key});

  final Widget child;

  @override
  State<TopNotificationHost> createState() => _TopNotificationHostState();
}

class _TopNotificationHostState extends State<TopNotificationHost> {
  _TopNotificationData? _notification;
  Timer? _dismissTimer;

  void show(SnackBar snackBar) {
    _dismissTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _notification = _TopNotificationData(snackBar);
    });
    _dismissTimer = Timer(snackBar.duration, dismiss);
  }

  void dismiss() {
    _dismissTimer?.cancel();
    if (!mounted || _notification == null) return;
    setState(() => _notification = null);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notification = _notification;
    final topInset = MediaQuery.paddingOf(context).top;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (notification != null)
          Positioned(
            top: topInset + 12,
            left: 16,
            right: 16,
            child: _TopNotificationBanner(
              notification: notification,
              onDismiss: dismiss,
            ),
          ),
      ],
    );
  }
}

/// Shows a message through the nearest [TopNotificationHost].
///
/// The MaterialBanner fallback keeps the message at the top for isolated
/// widget screens that are not mounted through [CapyVocabApp].
void showTopNotification(BuildContext context, SnackBar snackBar) {
  final host = context.findAncestorStateOfType<_TopNotificationHostState>();
  if (host != null) {
    host.show(snackBar);
    return;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger.clearMaterialBanners();
  final action = snackBar.action;
  messenger.showMaterialBanner(
    MaterialBanner(
      key: const Key('top-notification-banner'),
      content: snackBar.content,
      leading: const Icon(Icons.info_outline_rounded),
      actions: [
        if (action != null)
          TextButton(
            onPressed: action.onPressed,
            child: Text(action.label),
          ),
        TextButton(
          onPressed: messenger.hideCurrentMaterialBanner,
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

class _TopNotificationData {
  const _TopNotificationData(this.snackBar);

  final SnackBar snackBar;
}

class _TopNotificationBanner extends StatelessWidget {
  const _TopNotificationBanner({
    required this.notification,
    required this.onDismiss,
  });

  final _TopNotificationData notification;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final snackBar = notification.snackBar;
    final action = snackBar.action;
    final backgroundColor = snackBar.backgroundColor ?? AppColors.cream;

    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Thông báo',
      child: Container(
        key: const Key('top-notification-banner'),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.ink, width: 2.2),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              offset: Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.ink,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                    ),
                    child: snackBar.content,
                  ),
                ),
                if (action != null)
                  TextButton(
                    onPressed: action.onPressed,
                    child: Text(action.label),
                  ),
                Semantics(
                  button: true,
                  label: 'Đóng thông báo',
                  child: IconButton(
                    key: const Key('top-notification-dismiss-button'),
                    onPressed: onDismiss,
                    tooltip: null,
                    constraints: const BoxConstraints.tightFor(
                      width: 48,
                      height: 48,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.ink,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
