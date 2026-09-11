import 'dart:collection';

import 'media_asset.dart';
import 'photo_note.dart';
import 'scan_models.dart';

/// A storage-independent read model containing everything needed to review a
/// saved Photo Note without a network connection.
final class PhotoNoteSnapshot {
  PhotoNoteSnapshot({
    required this.photoNote,
    required this.mediaAsset,
    this.primaryScanRun,
    required Iterable<VocabDetection> detections,
    required Iterable<VocabAnnotation> annotations,
  })  : detections = List<VocabDetection>.unmodifiable(detections),
        annotations = List<VocabAnnotation>.unmodifiable(annotations) {
    if (photoNote.mediaAssetId != mediaAsset.id) {
      throw ArgumentError('photoNote and mediaAsset must refer to each other');
    }
    if (photoNote.userId != mediaAsset.userId) {
      throw ArgumentError('photoNote and mediaAsset must have the same owner');
    }
    final scanRun = primaryScanRun;
    if (photoNote.primaryScanRunId != scanRun?.id) {
      throw ArgumentError(
        'primaryScanRun must match photoNote.primaryScanRunId',
      );
    }
    if (scanRun != null &&
        (scanRun.userId != photoNote.userId ||
            scanRun.mediaAssetId != mediaAsset.id)) {
      throw ArgumentError('primaryScanRun must belong to this snapshot');
    }

    final detectionIds = <String>{};
    for (final detection in this.detections) {
      if (scanRun == null || detection.scanRunId != scanRun.id) {
        throw ArgumentError('every detection must belong to primaryScanRun');
      }
      if (!detectionIds.add(detection.id)) {
        throw ArgumentError.value(
          detection.id,
          'detections',
          'contains a duplicate id',
        );
      }
    }

    final annotationIds = <String>{};
    for (final annotation in this.annotations) {
      if (annotation.userId != photoNote.userId ||
          !detectionIds.contains(annotation.detectionId)) {
        throw ArgumentError('every annotation must belong to this snapshot');
      }
      if (!annotationIds.add(annotation.id)) {
        throw ArgumentError.value(
          annotation.id,
          'annotations',
          'contains a duplicate id',
        );
      }
    }
  }

  final PhotoNote photoNote;
  final MediaAsset mediaAsset;
  final ScanRun? primaryScanRun;
  final List<VocabDetection> detections;
  final List<VocabAnnotation> annotations;

  int get vocabCount => detections.length;

  Map<String, List<VocabAnnotation>> get annotationsByDetectionId {
    final grouped = <String, List<VocabAnnotation>>{};
    for (final annotation in annotations) {
      grouped.putIfAbsent(annotation.detectionId, () => []).add(annotation);
    }
    return UnmodifiableMapView<String, List<VocabAnnotation>>(
      grouped.map(
        (key, value) =>
            MapEntry(key, List<VocabAnnotation>.unmodifiable(value)),
      ),
    );
  }
}
