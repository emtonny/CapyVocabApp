import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/constants/app_colors.dart';

class CapyVideoHeader extends StatefulWidget {
  final String videoPath;
  final bool showText;
  final bool showContainerBorder;
  final double videoHeight;

  const CapyVideoHeader({
    super.key,
    this.videoPath = 'assets/DeerLogin.mp4',
    this.showText = true,
    this.showContainerBorder = true,
    this.videoHeight = 180.0,
  });

  @override
  State<CapyVideoHeader> createState() => _CapyVideoHeaderState();
}

class _CapyVideoHeaderState extends State<CapyVideoHeader> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(covariant CapyVideoHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _controller?.dispose();
      setState(() => _isInitialized = false);
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      final controller = VideoPlayerController.asset(widget.videoPath);
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (error) {
      debugPrint('Deer login video init error: $error');
      if (mounted) {
        setState(() => _isInitialized = false);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoWidth = widget.videoHeight * (9 / 16);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showText) ...[
          Text(
            'Deery Vocab',
            textAlign: TextAlign.center,
            style: GoogleFonts.robotoCondensed(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.6,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Học tiếng cùng Deery, đi khắp thế giới',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedInk,
              fontFamily: 'Nunito',
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          width: videoWidth,
          height: widget.videoHeight,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
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
              : Center(
                  child: Text(
                    '🦌',
                    style: TextStyle(fontSize: widget.videoHeight * 0.45),
                  ),
                ),
        ),
      ],
    );

    if (!widget.showContainerBorder) {
      return content;
    }

    return Container(
      key: const Key('auth-hero-box'),
      width: double.infinity,
      padding: widget.showText
          ? const EdgeInsets.symmetric(vertical: 22, horizontal: 20)
          : const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.ink,
          width: 2.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: content,
    );
  }
}
