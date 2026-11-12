import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Displays a user photo with a neutral silhouette as the fallback.
class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.avatarUrl,
    required this.size,
    this.backgroundColor = AppColors.paleGold,
    this.borderColor = AppColors.ink,
    this.borderWidth = 2,
    this.borderRadius,
  });

  final String? avatarUrl;
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final url = _validAvatarUrl(avatarUrl);
    final radius = borderRadius ?? BorderRadius.circular(size / 2);
    const defaultAvatar = CustomPaint(
      key: Key('default-user-avatar'),
      painter: _DefaultAvatarPainter(),
    );

    return Semantics(
      image: true,
      label: url == null ? 'Chưa có ảnh đại diện' : 'Ảnh đại diện người dùng',
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: borderWidth == 0
              ? null
              : Border.all(color: borderColor, width: borderWidth),
        ),
        child: url == null
            ? defaultAvatar
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => defaultAvatar,
              ),
      ),
    );
  }
}

class _DefaultAvatarPainter extends CustomPainter {
  const _DefaultAvatarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    final circle = Path()..addOval(const Rect.fromLTWH(0, 0, 1, 1));
    canvas.clipPath(circle);
    canvas.drawPath(circle, Paint()..color = const Color(0xFF9B9D9F));
    final silhouette = Paint()..color = const Color(0xFFF7F7F7);
    canvas.drawCircle(const Offset(.5, .39), .193, silhouette);
    canvas.drawPath(
      Path()
        ..moveTo(.14, .815)
        ..quadraticBezierTo(.5, .4, .86, .815)
        ..quadraticBezierTo(.5, 1.14, .14, .815)
        ..close(),
      silhouette,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DefaultAvatarPainter oldDelegate) => false;
}

String? _validAvatarUrl(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) return null;
  final uri = Uri.tryParse(normalized);
  if (uri == null ||
      !uri.hasAuthority ||
      !{'http', 'https'}.contains(uri.scheme)) {
    return null;
  }
  return uri.toString();
}
