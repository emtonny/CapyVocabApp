import 'package:flutter/material.dart';

enum SocialProvider { google, facebook }

class SocialAuthButton extends StatelessWidget {
  final SocialProvider provider;
  final VoidCallback? onPressed;

  const SocialAuthButton({
    super.key,
    required this.provider,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == SocialProvider.google;

    final bgColor = isGoogle ? Colors.white : const Color(0xFF1877F2);
    final textColor = isGoogle ? const Color(0xFF3C2A21) : Colors.white;
    final text = isGoogle ? 'Đăng nhập bằng Google' : 'Đăng nhập bằng Facebook';

    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF3C2A21),
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFF3C2A21),
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Icon fixed on the left (20px padding) so both buttons align vertically
              Positioned(
                left: 20,
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: Center(
                    child: isGoogle
                        ? const _GoogleIcon()
                        : const Icon(
                            Icons.facebook,
                            color: Colors.white,
                            size: 26,
                          ),
                  ),
                ),
              ),

              // Button Text
              Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Fredoka',
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CustomPaint(
        size: Size(24, 24),
        painter: _GoogleGLogoPainter(),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  const _GoogleGLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outerR = size.width / 2;
    final strokeWidth = size.width * 0.20;
    final innerR = outerR - strokeWidth;
    final center = Offset(cx, cy);

    final outerRect = Rect.fromCircle(center: center, radius: outerR);
    final innerRect = Rect.fromCircle(center: center, radius: innerR);

    // Helper to create ring arc segment in degrees
    Path createSegment(double startDeg, double sweepDeg) {
      final startRad = startDeg * (3.141592653589793 / 180.0);
      final sweepRad = sweepDeg * (3.141592653589793 / 180.0);

      final p = Path();
      p.arcTo(outerRect, startRad, sweepRad, false);
      p.arcTo(innerRect, startRad + sweepRad, -sweepRad, false);
      p.close();
      return p;
    }

    // 1. Red Arc (Top): 220° to 315° (sweep = 95°)
    canvas.drawPath(
      createSegment(220, 95),
      Paint()..color = const Color(0xFFEA4335)..style = PaintingStyle.fill,
    );

    // 2. Yellow Arc (Left): 140° to 220° (sweep = 80°)
    canvas.drawPath(
      createSegment(140, 80),
      Paint()..color = const Color(0xFFFBBC05)..style = PaintingStyle.fill,
    );

    // 3. Green Arc (Bottom): 45° to 140° (sweep = 95°)
    canvas.drawPath(
      createSegment(45, 95),
      Paint()..color = const Color(0xFF34A853)..style = PaintingStyle.fill,
    );

    // 4. Blue Arc (Bottom Right): 0° to 45° (sweep = 45°)
    canvas.drawPath(
      createSegment(0, 45),
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill,
    );

    // 5. Blue Horizontal Bar: from (cx, cy - strokeWidth/2) to (cx + outerR, cy + strokeWidth/2)
    final barPath = Path()
      ..addRect(Rect.fromLTRB(
        cx - 0.5,
        cy - strokeWidth / 2,
        cx + outerR,
        cy + strokeWidth / 2,
      ));
    canvas.drawPath(
      barPath,
      Paint()..color = const Color(0xFF4285F4)..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


