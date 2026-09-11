import 'domain_validation.dart';

final class NormalizedBoundingBox {
  NormalizedBoundingBox({
    required double x,
    required double y,
    required double width,
    required double height,
  })  : x = requireUnitInterval(x, 'x'),
        y = requireUnitInterval(y, 'y'),
        width = requireUnitInterval(width, 'width'),
        height = requireUnitInterval(height, 'height') {
    if (this.width == 0 || this.height == 0) {
      throw ArgumentError('width and height must be greater than zero');
    }
    if (this.x + this.width > 1 || this.y + this.height > 1) {
      throw ArgumentError('bounding box must stay inside normalized bounds');
    }
  }

  final double x;
  final double y;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) {
    return other is NormalizedBoundingBox &&
        x == other.x &&
        y == other.y &&
        width == other.width &&
        height == other.height;
  }

  @override
  int get hashCode => Object.hash(x, y, width, height);
}
