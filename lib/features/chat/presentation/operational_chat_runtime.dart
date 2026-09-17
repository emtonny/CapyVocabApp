import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'operational_chat_provider.dart';

/// Opt-in Staging lifecycle host. Never blocks rendering on sync/network.
class OperationalChatRuntime extends ConsumerStatefulWidget {
  const OperationalChatRuntime({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<OperationalChatRuntime> createState() =>
      _OperationalChatRuntimeState();
}

class _OperationalChatRuntimeState extends ConsumerState<OperationalChatRuntime>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(operationalChatForegroundProvider.notifier).state =
        operationalChatRuntimeActiveForLifecycle(state);
    if (kIsWeb && state == AppLifecycleState.resumed) {
      final coordinator =
          ref.read(operationalChatCoordinatorProvider).asData?.value;
      coordinator?.requestRefresh();
      if (coordinator != null) unawaited(coordinator.synchronize());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(operationalChatCoordinatorProvider);
    return widget.child;
  }
}
