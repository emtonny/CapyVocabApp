import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/capy_onboarding_header.dart';
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

  static const _stepTitles = [
    'Thông tin cá nhân',
    'Độ tuổi & Liên hệ',
    'Vai trò sử dụng',
    'Thời gian học tập',
    'Mục tiêu hàng ngày',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    if (state.isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAF6EE),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.duoGreen),
        ),
      );
    }

    if (state.initializationError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAF6EE),
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
      backgroundColor: const Color(0xFFFAF3E7),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= ResponsiveBreakpoints.mobileMax;

          return SafeArea(
            minimum: EdgeInsets.only(top: isWide ? 0 : 16),
            child: isWide
                ? _buildWideScreenLayout(context, state, notifier)
                : _buildMobileScreenLayout(context, state, notifier),
          );
        },
      ),
    );
  }

  Widget _buildMobileScreenLayout(
    BuildContext context,
    OnboardingState state,
    OnboardingNotifier notifier,
  ) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CapyOnboardingHeader(
                key: const Key('onboarding-header'),
                currentStep: state.currentStep,
              ),
              const SizedBox(height: 16),
              _buildStepContentCard(state.currentStep),
              if (state.saveError != null) ...[
                const SizedBox(height: 12),
                _SaveErrorMessage(message: state.saveError!),
              ],
              const SizedBox(height: 18),
              _buildNavigationBar(context, state, notifier),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideScreenLayout(
    BuildContext context,
    OnboardingState state,
    OnboardingNotifier notifier,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Pane: Banner Header & Progress Guidance
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF3C2A21),
                      width: 2.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFF3C2A21),
                        offset: Offset(0, 4),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CapyOnboardingHeader(currentStep: state.currentStep),
                      const SizedBox(height: 16),
                      const Text(
                        'Thiết lập lộ trình học',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF3C2A21),
                          fontFamily: 'Fredoka',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Bước ${state.currentStep + 1}/5: ${_stepTitles[state.currentStep]}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF786C65),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2D6C5)),
                      const SizedBox(height: 12),
                      ...List.generate(_stepTitles.length, (index) {
                        final isActive = index == state.currentStep;
                        final isCompleted = index < state.currentStep;

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isCompleted
                                      ? AppColors.duoGreen
                                      : (isActive
                                          ? const Color(0xFFFFC72C)
                                          : const Color(0xFFE2D6C5)),
                                  border: Border.all(
                                    color: const Color(0xFF3C2A21),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.white,
                                        )
                                      : Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: isActive
                                                ? const Color(0xFF3C2A21)
                                                : const Color(0xFF786C65),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _stepTitles[index],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isActive
                                      ? const Color(0xFF3C2A21)
                                      : (isCompleted
                                          ? AppColors.duoGreen
                                          : const Color(0xFF9E8F85)),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Right Pane: Active Step Content & Navigation Controls
              Expanded(
                flex: 6,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepContentCard(state.currentStep),
                    if (state.saveError != null) ...[
                      const SizedBox(height: 12),
                      _SaveErrorMessage(message: state.saveError!),
                    ],
                    const SizedBox(height: 18),
                    _buildNavigationBar(context, state, notifier),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContentCard(int currentStep) {
    return Container(
      key: const Key('onboarding-step-content-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF3C2A21),
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF3C2A21),
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: KeyedSubtree(
        key: ValueKey('onboarding-step-$currentStep'),
        child: _steps[currentStep],
      ),
    );
  }

  Widget _buildNavigationBar(
    BuildContext context,
    OnboardingState state,
    OnboardingNotifier notifier,
  ) {
    return _NavigationBar(
      currentStep: state.currentStep,
      isCheckingAvailability: state.isCheckingUsername || state.isCheckingPhone,
      isSaving: state.isSaving,
      hasSaveError: state.saveError != null,
      onBack: notifier.previousStep,
      onNext: () => _handlePrimaryAction(
        context,
        state.currentStep,
        notifier,
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

class _SaveErrorMessage extends StatelessWidget {
  const _SaveErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        border: Border.all(color: errorColor, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: errorColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.currentStep,
    required this.isCheckingAvailability,
    required this.isSaving,
    required this.hasSaveError,
    required this.onBack,
    required this.onNext,
  });

  final int currentStep;
  final bool isCheckingAvailability;
  final bool isSaving;
  final bool hasSaveError;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isBusy = isCheckingAvailability || isSaving;
    final isLastStep = currentStep == 4;

    final nextButtonText = isBusy
        ? (isSaving ? 'Đang lưu...' : 'Đang kiểm tra...')
        : isLastStep
            ? (hasSaveError ? 'Thử lại' : 'HOÀN TẤT & BẮT ĐẦU 🚀')
            : 'Tiếp Tục →';

    return Row(
      children: [
        // Back Button (hidden on step 0)
        if (currentStep > 0) ...[
          Expanded(
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF3C2A21),
                  width: 2.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF3C2A21),
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('onboarding-back-button'),
                  onTap: isBusy ? null : onBack,
                  borderRadius: BorderRadius.circular(20),
                  child: const Center(
                    child: Text(
                      '← Quay lại',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C2A21),
                        fontFamily: 'Fredoka',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],

        // Primary Action Button (Next / Finish)
        Expanded(
          flex: currentStep > 0 ? 2 : 1,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF58CC02),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF3C2A21),
                width: 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF3C2A21),
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('onboarding-next-button'),
                onTap: isBusy ? null : onNext,
                borderRadius: BorderRadius.circular(20),
                child: Center(
                  child: isBusy
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              nextButtonText,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Fredoka',
                              ),
                            ),
                          ],
                        )
                      : Text(
                          nextButtonText,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Fredoka',
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
}
