import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class CapyVideoHeader extends StatefulWidget {
  final String videoPath;
  const CapyVideoHeader({
    super.key,
    this.videoPath = 'assets/CapyLogin.mp4',
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 9:16 Video Animation Box
          Container(
            height: 180,
            width: 180 * (9 / 16), // 101.25px width for 9:16 vertical ratio
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
          const SizedBox(height: 12),
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'Capy Vocab',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3C2A21),
                  fontFamily: 'Fredoka',
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
      ),
    );
  }
}
