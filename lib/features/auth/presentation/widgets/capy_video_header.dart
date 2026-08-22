import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
          const Text(
            'Deery Vocab',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3C2A21),
              fontFamily: 'Fredoka',
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Học tiếng cùng Deery, đi khắp thế giới',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6E5D53),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          width: videoWidth,
          height: widget.videoHeight,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
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
      width: double.infinity,
      padding: widget.showText
          ? const EdgeInsets.symmetric(vertical: 24, horizontal: 22)
          : const EdgeInsets.all(10),
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
