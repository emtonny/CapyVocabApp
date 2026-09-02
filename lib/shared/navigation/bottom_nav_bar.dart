import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';

const _tabRoutes = ['/home', '/storage', '/pet-shop', '/friends'];

const _ink = AppColors.ink;
const _cream = AppColors.softWhite;
const _blue = AppColors.blue;
const _yellow = AppColors.neonYellow;
const _green = AppColors.mint;
const _purple = AppColors.lavender;
const _avatarYellow = Color(0xFFFFC928);

/// Floating neo-brutalist navigation card with a raised scan action.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final activeIndex = _tabRoutes.indexOf(location).clamp(0, 3);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 100,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Positioned(
              left: 12,
              right: 17,
              top: 22,
              bottom: 5,
              child: DecoratedBox(
                key: const Key('bottom-nav-shell'),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _ink, width: 3.2),
                  boxShadow: const [
                    BoxShadow(
                      color: _ink,
                      offset: Offset(5, 5),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              top: 22,
              bottom: 5,
              left: 15,
              right: 20,
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      iconWidget: _FramedNavIcon(
                        key: const Key('bottom-nav-home-icon'),
                        isActive: activeIndex == 0,
                        painter: const _HouseIconPainter(),
                      ),
                      label: 'Trang chủ',
                      isActive: activeIndex == 0,
                      onTap: () => context.go('/home'),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      iconWidget: _FramedNavIcon(
                        key: const Key('bottom-nav-library-icon'),
                        isActive: activeIndex == 1,
                        painter: const _BookIconPainter(),
                      ),
                      label: 'Thư viện',
                      isActive: activeIndex == 1,
                      onTap: () => context.go('/storage'),
                    ),
                  ),
                  const SizedBox(width: 76),
                  Expanded(
                    child: _NavItem(
                      iconWidget: _FramedNavIcon(
                        key: const Key('bottom-nav-shop-icon'),
                        isActive: activeIndex == 2,
                        painter: const _ShopIconPainter(),
                      ),
                      label: 'Cửa hàng',
                      isActive: activeIndex == 2,
                      onTap: () => context.go('/pet-shop'),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      iconWidget: _FramedNavIcon(
                        key: const Key('bottom-nav-friends-icon'),
                        isActive: activeIndex == 3,
                        painter: const _FriendsIconPainter(),
                      ),
                      label: 'Bạn bè',
                      isActive: activeIndex == 3,
                      onTap: () => context.go('/friends'),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              child: Tooltip(
                message: 'Quét ảnh từ vựng',
                child: Container(
                  key: const Key('bottom-nav-camera-frame'),
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: _yellow,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: _ink, width: 3.5),
                    boxShadow: const [
                      BoxShadow(
                        color: _ink,
                        offset: Offset(6, 7),
                        blurRadius: 0,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(9.5),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('bottom-nav-camera-button'),
                      onTap: () => context.push('/scan'),
                      splashColor: Colors.white.withValues(alpha: 0.38),
                      highlightColor: Colors.white.withValues(alpha: 0.18),
                      child: Semantics(
                        button: true,
                        label: 'Quét ảnh từ vựng',
                        child: const Center(
                          child: CustomPaint(
                            size: Size(45, 38),
                            painter: _CameraIconPainter(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.iconWidget,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final Widget iconWidget;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            splashColor: _blue.withValues(alpha: 0.18),
            highlightColor: Colors.transparent,
            child: Center(child: iconWidget),
          ),
        ),
      ),
    );
  }
}

class _FramedNavIcon extends StatelessWidget {
  const _FramedNavIcon({
    super.key,
    required this.isActive,
    required this.painter,
  });

  final bool isActive;
  final CustomPainter painter;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: 47,
      height: 47,
      decoration: BoxDecoration(
        color: isActive ? _blue : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _ink, width: 3),
        boxShadow: [
          BoxShadow(
            color: _ink,
            offset: Offset(isActive ? 3.5 : 2, isActive ? 4 : 2.5),
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: CustomPaint(size: const Size(29, 29), painter: painter),
      ),
    );
  }
}

Paint _stroke(double width) => Paint()
  ..color = _ink
  ..style = PaintingStyle.stroke
  ..strokeWidth = width
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _HouseIconPainter extends CustomPainter {
  const _HouseIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = _stroke(2.8);
    final fill = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(size.width * .13, size.height * .45)
      ..lineTo(size.width * .50, size.height * .10)
      ..lineTo(size.width * .87, size.height * .45)
      ..lineTo(size.width * .87, size.height * .88)
      ..quadraticBezierTo(
        size.width * .87,
        size.height * .93,
        size.width * .81,
        size.height * .93,
      )
      ..lineTo(size.width * .62, size.height * .93)
      ..lineTo(size.width * .62, size.height * .68)
      ..quadraticBezierTo(
        size.width * .62,
        size.height * .61,
        size.width * .55,
        size.height * .61,
      )
      ..lineTo(size.width * .45, size.height * .61)
      ..quadraticBezierTo(
        size.width * .38,
        size.height * .61,
        size.width * .38,
        size.height * .68,
      )
      ..lineTo(size.width * .38, size.height * .93)
      ..lineTo(size.width * .19, size.height * .93)
      ..quadraticBezierTo(
        size.width * .13,
        size.height * .93,
        size.width * .13,
        size.height * .87,
      )
      ..close();

    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BookIconPainter extends CustomPainter {
  const _BookIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = _stroke(2.8);
    final book = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .14, size.height * .09, size.width * .72,
          size.height * .82),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(book, Paint()..color = Colors.white);

    final ribbon = Path()
      ..moveTo(size.width * .51, size.height * .09)
      ..lineTo(size.width * .74, size.height * .09)
      ..lineTo(size.width * .74, size.height * .50)
      ..lineTo(size.width * .625, size.height * .40)
      ..lineTo(size.width * .51, size.height * .50)
      ..close();
    canvas.drawPath(ribbon, Paint()..color = _green);
    canvas.drawPath(ribbon, stroke);
    canvas.drawRRect(book, stroke);
    canvas.drawLine(
      Offset(size.width * .14, size.height * .72),
      Offset(size.width * .86, size.height * .72),
      stroke,
    );
    canvas.drawLine(
      Offset(size.width * .24, size.height * .83),
      Offset(size.width * .83, size.height * .83),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CameraIconPainter extends CustomPainter {
  const _CameraIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = _stroke(3.2);
    final fill = Paint()..color = Colors.white;
    final silhouette = Path()
      ..moveTo(size.width * .08, size.height * .35)
      ..quadraticBezierTo(size.width * .08, size.height * .22, size.width * .20,
          size.height * .22)
      ..lineTo(size.width * .31, size.height * .22)
      ..lineTo(size.width * .35, size.height * .10)
      ..quadraticBezierTo(size.width * .37, size.height * .05, size.width * .44,
          size.height * .05)
      ..lineTo(size.width * .60, size.height * .05)
      ..quadraticBezierTo(size.width * .67, size.height * .05, size.width * .69,
          size.height * .10)
      ..lineTo(size.width * .73, size.height * .22)
      ..lineTo(size.width * .80, size.height * .22)
      ..quadraticBezierTo(size.width * .92, size.height * .22, size.width * .92,
          size.height * .35)
      ..lineTo(size.width * .92, size.height * .84)
      ..quadraticBezierTo(size.width * .92, size.height * .94, size.width * .81,
          size.height * .94)
      ..lineTo(size.width * .19, size.height * .94)
      ..quadraticBezierTo(size.width * .08, size.height * .94, size.width * .08,
          size.height * .84)
      ..close();
    canvas.drawPath(silhouette, fill);
    canvas.drawPath(silhouette, stroke);
    canvas.drawCircle(
      Offset(size.width * .50, size.height * .58),
      size.width * .18,
      fill,
    );
    canvas.drawCircle(
      Offset(size.width * .50, size.height * .58),
      size.width * .18,
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShopIconPainter extends CustomPainter {
  const _ShopIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = _stroke(2.8);
    final shopBody = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .18, size.height * .40, size.width * .64,
          size.height * .51),
      const Radius.circular(2),
    );
    canvas.drawRRect(shopBody, Paint()..color = Colors.white);
    canvas.drawRRect(shopBody, stroke);

    final door = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * .42, size.height * .65, size.width * .19,
          size.height * .26),
      const Radius.circular(2),
    );
    canvas.drawRRect(door, Paint()..color = _ink);

    final awning = Path()
      ..moveTo(size.width * .18, size.height * .18)
      ..quadraticBezierTo(size.width * .19, size.height * .13, size.width * .25,
          size.height * .13)
      ..lineTo(size.width * .75, size.height * .13)
      ..quadraticBezierTo(size.width * .81, size.height * .13, size.width * .82,
          size.height * .18)
      ..lineTo(size.width * .90, size.height * .43)
      ..quadraticBezierTo(size.width * .90, size.height * .54, size.width * .80,
          size.height * .54)
      ..quadraticBezierTo(size.width * .72, size.height * .54, size.width * .69,
          size.height * .47)
      ..quadraticBezierTo(size.width * .65, size.height * .56, size.width * .56,
          size.height * .54)
      ..quadraticBezierTo(size.width * .50, size.height * .54, size.width * .47,
          size.height * .47)
      ..quadraticBezierTo(size.width * .43, size.height * .56, size.width * .34,
          size.height * .54)
      ..quadraticBezierTo(size.width * .27, size.height * .54, size.width * .24,
          size.height * .47)
      ..quadraticBezierTo(size.width * .19, size.height * .56, size.width * .10,
          size.height * .51)
      ..quadraticBezierTo(size.width * .07, size.height * .48, size.width * .10,
          size.height * .40)
      ..close();
    canvas.drawPath(awning, Paint()..color = _purple);
    canvas.drawPath(awning, stroke);

    for (final x in [.30, .43, .56, .69]) {
      canvas.drawLine(
        Offset(size.width * x, size.height * .14),
        Offset(size.width * (x - .03), size.height * .45),
        _stroke(1.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FriendsIconPainter extends CustomPainter {
  const _FriendsIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = _stroke(2.8);
    final white = Paint()..color = Colors.white;
    final rearCenter = Offset(size.width * .70, size.height * .30);

    canvas.drawArc(
      Rect.fromCircle(center: rearCenter, radius: size.width * .16),
      -1.35,
      2.7,
      false,
      stroke,
    );
    final rearBody = Path()
      ..moveTo(size.width * .68, size.height * .57)
      ..quadraticBezierTo(size.width * .88, size.height * .57, size.width * .91,
          size.height * .83)
      ..quadraticBezierTo(size.width * .91, size.height * .88, size.width * .86,
          size.height * .88)
      ..lineTo(size.width * .75, size.height * .88);
    canvas.drawPath(rearBody, stroke);

    final frontCenter = Offset(size.width * .40, size.height * .37);
    canvas.drawCircle(
        frontCenter, size.width * .18, Paint()..color = _avatarYellow);
    canvas.drawCircle(frontCenter, size.width * .18, stroke);

    final frontBody = Path()
      ..moveTo(size.width * .12, size.height * .88)
      ..quadraticBezierTo(size.width * .15, size.height * .62, size.width * .40,
          size.height * .62)
      ..quadraticBezierTo(size.width * .65, size.height * .62, size.width * .68,
          size.height * .88)
      ..quadraticBezierTo(size.width * .68, size.height * .92, size.width * .63,
          size.height * .92)
      ..lineTo(size.width * .17, size.height * .92)
      ..quadraticBezierTo(size.width * .12, size.height * .92, size.width * .12,
          size.height * .88)
      ..close();
    canvas.drawPath(frontBody, white);
    canvas.drawPath(frontBody, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
