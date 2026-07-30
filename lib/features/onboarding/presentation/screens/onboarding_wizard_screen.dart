import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/step1_name_username.dart';
import '../widgets/step2_age_phone.dart';
import '../widgets/step3_role_selector.dart';
import '../widgets/step4_study_time.dart';
import '../widgets/step5_daily_target.dart';

class OnboardingWizardScreen extends ConsumerWidget {
  const OnboardingWizardScreen({super.key});

  static const _steps = <Widget>[
    Step1NameUsername(),
    Step2AgePhone(),
    Step3RoleSelector(),
    Step4StudyTime(),
    Step5DailyTarget(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    if (state.isInitializing) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.initializationError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      state.initializationError!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      key: const Key('retry-load-onboarding-button'),
                      onPressed: notifier.loadInitialData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _ProgressHeader(currentStep: state.currentStep),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Card(
                      elevation: 2,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: IndexedStack(
                          index: state.currentStep,
                          children: _steps,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    if (state.saveError != null)
                      _SaveErrorMessage(message: state.saveError!),
                    _NavigationBar(
                      currentStep: state.currentStep,
                      isCheckingUsername: state.isCheckingUsername,
                      isSaving: state.isSaving,
                      hasSaveError: state.saveError != null,
                      onBack: notifier.previousStep,
                      onNext: () => _handlePrimaryAction(
                        context,
                        state.currentStep,
                        notifier,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrimaryAction(
    BuildContext context,
    int currentStep,
    OnboardingNotifier notifier,
  ) async {
    if (currentStep < 4) {
      await notifier.nextStep();
      return;
    }

    final completed = await notifier.completeOnboarding();
    if (completed && context.mounted) {
      context.go('/home');
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / 5;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Bước ${currentStep + 1} / 5',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text('${(progress * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 10,
                  value: progress,
                  color: AppColors.duoGreen,
                  backgroundColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SaveErrorMessage extends StatelessWidget {
  const _SaveErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: errorColor.withValues(alpha: 0.08),
          border: Border.all(color: errorColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: errorColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: errorColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.currentStep,
    required this.isCheckingUsername,
    required this.isSaving,
    required this.hasSaveError,
    required this.onBack,
    required this.onNext,
  });

  final int currentStep;
  final bool isCheckingUsername;
  final bool isSaving;
  final bool hasSaveError;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isBusy = isCheckingUsername || isSaving;
    final isLastStep = currentStep == 4;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('onboarding-back-button'),
              onPressed: currentStep == 0 || isBusy ? null : onBack,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Quay lại'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              key: const Key('onboarding-next-button'),
              onPressed: isBusy ? null : onNext,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppColors.duoGreen,
              ),
              child: isBusy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isSaving ? 'Đang lưu...' : 'Đang kiểm tra...',
                        ),
                      ],
                    )
                  : Text(
                      isLastStep
                          ? hasSaveError
                              ? 'Thử lại'
                              : 'Hoàn tất'
                          : 'Tiếp tục',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
