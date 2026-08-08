import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CapyVideoHeader extends StatefulWidget {
  final String videoPath;
  final bool showText;
  final bool showContainerBorder;
  final double videoHeight;

  const CapyVideoHeader({
    super.key,
    this.videoPath = 'assets/CapyLogin.mp4',
    this.showText = true,
    this.showContainerBorder = true,
    this.videoHeight = 180.0,
  });

  @override
  State<CapyVideoHeader> createState() => _CapyVideoHeaderState();
}

class _CapyVideoHeaderState extends State<CapyVideoHeader> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.asset(widget.videoPath);
      await _controller.initialize();
      _controller.setLooping(true);
      _controller.setVolume(0.0);
      await _controller.play();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('CapyVideoHeader video init error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vHeight = widget.videoHeight;
    final vWidth = vHeight * (9 / 16);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 9:16 Video Animation Box
        Container(
          height: vHeight,
          width: vWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
          ),
          clipBehavior: Clip.antiAlias,
          child: _isInitialized
              ? FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                )
              : const Center(
                  child: Text(
                    '🦫',
                    style: TextStyle(fontSize: 48),
                  ),
                ),
        ),
        if (widget.showText) ...[
          const SizedBox(height: 12),
          // Title
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Capy Vocab',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3C2A21),
                    fontFamily: 'Fredoka',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6),
              Text(
                '🍊',
                style: TextStyle(fontSize: 26),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Subtitle
          const Text(
            'Học từ vựng chill & kết bạn mỗi ngày!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E5D53),
            ),
          ),
        ],
      ],
    );

    if (!widget.showContainerBorder) {
      return content;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
      child: content,
    );
  }
}
