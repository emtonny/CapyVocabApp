import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';

class CapyOnboardingHeader extends StatefulWidget {
  final int currentStep;
  const CapyOnboardingHeader({
    super.key,
    required this.currentStep,
  });

  static const _prompts = <Map<String, String>>[
    {
      'title': 'Chào bạn mới! 🍪',
      'subtitle': 'Nhập tên thật và biệt danh bạn muốn bạn bè nhìn thấy nhé!',
    },
    {
      'title': 'Thông tin độ tuổi & SĐT 📱',
      'subtitle': 'Giúp Bé Deer bảo mật và gửi thông báo nhắc nhớ chuẩn hơn!',
    },
    {
      'title': 'Chọn vai trò tài khoản 👥',
      'subtitle': 'Bạn dùng ứng dụng làm cá nhân hay phụ huynh theo dõi con?',
    },
    {
      'title': 'Lên lịch học tập ⏰',
      'subtitle': 'Bật thông báo nhắc học vào khung giờ vàng mỗi ngày nhé!',
    },
    {
      'title': 'Mục tiêu học từ vựng 📚',
      'subtitle': 'Tự nhập số lượng từ vựng bạn muốn chinh phục mỗi ngày!',
    },
  ];

  @override
  State<CapyOnboardingHeader> createState() => _CapyOnboardingHeaderState();
}

class _CapyOnboardingHeaderState extends State<CapyOnboardingHeader> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final controller =
          VideoPlayerController.asset('assets/DeerOnboarding.mp4');
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (error) {
      debugPrint('Deer onboarding video init error: $error');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stepIndex = widget.currentStep.clamp(0, 4);
    final prompt = CapyOnboardingHeader._prompts[stepIndex];
    final progress = (stepIndex + 1) / 5;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Progress Text & Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Bước ${stepIndex + 1} / 5',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF3C2A21),
                fontFamily: 'Fredoka',
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF786C65),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          key: const Key('onboarding-progress-bar'),
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFEFE8DB),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFF3C2A21),
              width: 2.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress,
                child: Container(
                  color: AppColors.duoGreen,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Mascot Chat Banner Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          child: Row(
            children: [
              Container(
                key: const Key('onboarding-video-box'),
                width: 112 * (9 / 16),
                height: 112,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _isInitialized && _controller != null
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      )
                    : const Center(
                        child: Text(
                          '🦌',
                          style: TextStyle(fontSize: 28),
                        ),
                      ),
              ),
              const SizedBox(width: 14),

              // Chat Text Prompt
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prompt['title']!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3C2A21),
                        fontFamily: 'Fredoka',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      prompt['subtitle']!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF786C65),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
