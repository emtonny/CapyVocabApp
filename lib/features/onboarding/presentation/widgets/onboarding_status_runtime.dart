import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/onboarding_status_store.dart';

class OnboardingStatusRuntime extends StatefulWidget {
  const OnboardingStatusRuntime({
    required this.currentUserId,
    required this.authUserIds,
    required this.refresher,
    required this.child,
    super.key,
  });

  final String? Function() currentUserId;
  final Stream<String?> authUserIds;
  final OnboardingStatusRefresher refresher;
  final Widget child;

  @override
  State<OnboardingStatusRuntime> createState() =>
      _OnboardingStatusRuntimeState();
}

class _OnboardingStatusRuntimeState extends State<OnboardingStatusRuntime>
    with WidgetsBindingObserver {
  StreamSubscription<String?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = widget.authUserIds.distinct().listen(_refresh);
    _refresh(widget.currentUserId());
  }

  void _refresh(String? userId) {
    if (userId == null) return;
    unawaited(widget.refresher.refresh(userId));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh(widget.currentUserId());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
