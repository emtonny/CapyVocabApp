import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../library/application/library_media_loader.dart';
import '../../domain/lesson_game.dart';

final class LessonPhotoMarker {
  const LessonPhotoMarker({
    required this.box,
    required this.semanticLabel,
    this.number,
    this.highlighted = false,
  });

  final LessonNormalizedBoundingBox box;
  final String semanticLabel;
  final int? number;
  final bool highlighted;
}

class LessonPhotoView extends StatefulWidget {
  const LessonPhotoView({
    required this.mediaLoader,
    required this.relativePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.markers,
    super.key,
  });

  final LibraryMediaLoader mediaLoader;
  final String relativePath;
  final int imageWidth;
  final int imageHeight;
  final List<LessonPhotoMarker> markers;

  @override
  State<LessonPhotoView> createState() => _LessonPhotoViewState();
}

class _LessonPhotoViewState extends State<LessonPhotoView> {
  static const double _markerBadgeSize = 36;

  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.mediaLoader.readBytes(widget.relativePath);
  }

  @override
  void didUpdateWidget(covariant LessonPhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativePath != widget.relativePath ||
        oldWidget.mediaLoader != widget.mediaLoader) {
      _bytes = widget.mediaLoader.readBytes(widget.relativePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AspectRatio(
            aspectRatio: 4 / 3,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return const _MissingLessonPhoto();
        }
        return RepaintBoundary(
          child: Semantics(
            image: true,
            label: 'Ảnh Photo Note có đánh dấu đồ vật cần học',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: widget.imageWidth / widget.imageHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
                    final cacheWidth = (constraints.maxWidth * pixelRatio)
                        .ceil()
                        .clamp(1, widget.imageWidth)
                        .toInt();
                    final cacheHeight = (constraints.maxHeight * pixelRatio)
                        .ceil()
                        .clamp(1, widget.imageHeight)
                        .toInt();
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          snapshot.data!,
                          fit: BoxFit.fill,
                          cacheWidth: cacheWidth,
                          cacheHeight: cacheHeight,
                          filterQuality: FilterQuality.medium,
                          gaplessPlayback: true,
                          errorBuilder: (_, __, ___) =>
                              const _MissingLessonPhoto(),
                        ),
                        for (final marker in widget.markers)
                          ..._markerWidgets(marker, constraints),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Iterable<Widget> _markerWidgets(
    LessonPhotoMarker marker,
    BoxConstraints constraints,
  ) sync* {
    final left = marker.box.x * constraints.maxWidth;
    final top = marker.box.y * constraints.maxHeight;
    final width = marker.box.width * constraints.maxWidth;
    final height = marker.box.height * constraints.maxHeight;

    yield Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        child: Semantics(
          label: marker.semanticLabel,
          child: Container(
            key: marker.number == null
                ? const Key('lesson-photo-highlight-frame')
                : Key('lesson-photo-marker-frame-${marker.number}'),
            decoration: BoxDecoration(
              color: marker.highlighted
                  ? AppColors.yellow.withValues(alpha: .28)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.yellow, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  blurRadius: 0,
                  spreadRadius: 1.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final number = marker.number;
    if (number == null) return;
    final maxBadgeLeft = constraints.maxWidth > _markerBadgeSize
        ? constraints.maxWidth - _markerBadgeSize
        : 0.0;
    final maxBadgeTop = constraints.maxHeight > _markerBadgeSize
        ? constraints.maxHeight - _markerBadgeSize
        : 0.0;
    final badgeLeft =
        (left - (_markerBadgeSize / 2)).clamp(0.0, maxBadgeLeft).toDouble();
    final badgeTop =
        (top - (_markerBadgeSize / 2)).clamp(0.0, maxBadgeTop).toDouble();

    yield Positioned(
      left: badgeLeft,
      top: badgeTop,
      width: _markerBadgeSize,
      height: _markerBadgeSize,
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Container(
            key: Key('lesson-photo-marker-badge-$number'),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.ink,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingLessonPhoto extends StatelessWidget {
  const _MissingLessonPhoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('lesson-photo-missing'),
      constraints: const BoxConstraints(minHeight: 180),
      alignment: Alignment.center,
      color: AppColors.softWhite,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 42),
          SizedBox(height: 8),
          Text(
            'Ảnh trên máy không còn khả dụng.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
