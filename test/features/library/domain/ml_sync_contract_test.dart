import 'package:capy_vocab/features/library/domain/library_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _userId = '10000000-0000-0000-0000-000000000001';
const _eventId = '10000000-0000-0000-0000-000000000002';
const _sessionId = '10000000-0000-0000-0000-000000000003';
const _detectionId = '10000000-0000-0000-0000-000000000004';
const _operationId = '10000000-0000-0000-0000-000000000005';
const _dependencyId = '10000000-0000-0000-0000-000000000006';
const _exampleId = '10000000-0000-0000-0000-000000000007';
const _sha256 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

final _now = DateTime.utc(2026, 9, 1, 12);

void main() {
  group('learning provenance', () {
    test('event requires an annotation or detection source', () {
      expect(() => _buildLearningEvent(detectionId: null), throwsArgumentError);
    });

    test('event rejects negative response metadata', () {
      expect(
        () => _buildLearningEvent(responseTimeMs: -1),
        throwsArgumentError,
      );
    });
  });

  group('consent audit', () {
    test('records an account-scoped change with enforcement state', () {
      final event = ConsentEvent(
        id: '10000000-0000-0000-0000-000000000099',
        userId: _userId,
        consentType: ConsentType.localPersonalization,
        oldValue: false,
        newValue: true,
        policyVersion: 'privacy-v1',
        sourceAction: 'settings_toggle',
        enforcementState: ConsentEnforcementState.pending,
        occurredAt: _now,
      );

      expect(event.newValue, isTrue);
      expect(event.enforcementState, ConsentEnforcementState.pending);
    });

    test('rejects audit records that do not change consent', () {
      expect(
        () => ConsentEvent(
          id: '10000000-0000-0000-0000-000000000099',
          userId: _userId,
          consentType: ConsentType.cloudBackup,
          oldValue: false,
          newValue: false,
          policyVersion: 'privacy-v1',
          sourceAction: 'settings_toggle',
          enforcementState: ConsentEnforcementState.applied,
          occurredAt: _now,
        ),
        throwsArgumentError,
      );
    });
  });

  group('transactional outbox contract', () {
    test('freezes payload and operation dependencies', () {
      final payload = <String, Object?>{
        'changes': <Object?>['title'],
      };
      final dependencies = <String>[_dependencyId];
      final operation = SyncOperation(
        operationId: _operationId,
        userId: _userId,
        entityType: SyncEntityType.photoNote,
        entityId: _exampleId,
        operationType: SyncOperationType.update,
        payloadJson: payload,
        dependencyIds: dependencies,
        state: SyncOperationState.pending,
        attemptCount: 0,
        createdAt: _now,
        updatedAt: _now,
      );

      payload['lateMutation'] = true;
      dependencies.add('10000000-0000-0000-0000-000000000099');

      expect(operation.payloadJson, isNot(contains('lateMutation')));
      expect(operation.dependencyIds, [_dependencyId]);
      expect(
        () => operation.dependencyIds.add(_operationId),
        throwsUnsupportedError,
      );
    });

    test('rejects non-UUID dependency IDs', () {
      expect(
        () => SyncOperation(
          operationId: _operationId,
          userId: _userId,
          entityType: SyncEntityType.photoNote,
          entityId: _exampleId,
          operationType: SyncOperationType.update,
          payloadJson: const {},
          dependencyIds: const ['legacy-operation-id'],
          state: SyncOperationState.pending,
          attemptCount: 0,
          createdAt: _now,
          updatedAt: _now,
        ),
        throwsArgumentError,
      );
    });

    test('rejects self-references and duplicate dependencies', () {
      expect(
        () => _buildSyncOperation([_operationId]),
        throwsArgumentError,
      );
      expect(
        () => _buildSyncOperation([_dependencyId, _dependencyId]),
        throwsArgumentError,
      );
    });
  });

  group('training projection', () {
    test('non-eligible examples stay out of dataset splits', () {
      expect(
        () => _buildTrainingExample(
          eligibilityStatus: TrainingEligibilityStatus.excluded,
          split: DatasetSplit.train,
        ),
        throwsArgumentError,
      );
    });

    test('features and labels are immutable versioned snapshots', () {
      final features = <String, Object?>{
        'embedding': <Object?>[0.1, 0.2],
      };
      final example = _buildTrainingExample(featuresJson: features);

      features['lateMutation'] = true;
      expect(example.featuresJson, isNot(contains('lateMutation')));
      expect(example.featureSchemaVersion, 'vision-features-v1');
      expect(example.labelSchemaVersion, 'vocab-label-v1');
      expect(
        () => example.featuresJson['lateMutation'] = true,
        throwsUnsupportedError,
      );
    });

    test('manifest rejects negative split counts', () {
      expect(
        () => DatasetManifest(
          id: '10000000-0000-0000-0000-000000000008',
          userId: _userId,
          taskType: TrainingTaskType.visionClassification,
          builderVersion: 'builder-v1',
          featureSchemaVersion: 'vision-features-v1',
          labelSchemaVersion: 'vocab-label-v1',
          splitSeedVersion: 'split-v1',
          sourceWatermark: 'event:42',
          splitCounts: const {'train': -1},
          consentSnapshot: const {'personalization': true},
          qualityReport: const {'accepted': 10},
          manifestHashSha256: _sha256,
          createdAt: _now,
        ),
        throwsArgumentError,
      );
    });
  });

  group('repository query boundaries', () {
    test('Photo Note query validates owner, UTC range, and limit', () {
      expect(
        () => PhotoNoteQuery(userId: 'legacy-user'),
        throwsArgumentError,
      );
      expect(
        () => PhotoNoteQuery(
          userId: _userId,
          capturedFromInclusive: _now,
          capturedToExclusive: _now,
        ),
        throwsArgumentError,
      );
      expect(
        () => PhotoNoteQuery(userId: _userId, limit: 501),
        throwsArgumentError,
      );
    });

    test('Learning event query validates chronological bounds', () {
      expect(
        () => LearningEventQuery(
          userId: _userId,
          occurredFromInclusive: _now.add(const Duration(days: 1)),
          occurredToExclusive: _now,
        ),
        throwsArgumentError,
      );
    });
  });
}

LearningEvent _buildLearningEvent({
  String? detectionId = _detectionId,
  int? responseTimeMs = 250,
}) {
  return LearningEvent(
    id: _eventId,
    userId: _userId,
    detectionId: detectionId,
    sessionId: _sessionId,
    eventType: LearningEventType.answered,
    answerNormalized: 'cup',
    isCorrect: true,
    responseTimeMs: responseTimeMs,
    hintCount: 0,
    attemptNumber: 1,
    masteryBefore: 0.2,
    masteryAfter: 0.3,
    schedulerVersion: 'srs-v1',
    occurredAt: _now,
    recordedAt: _now,
  );
}

TrainingExample _buildTrainingExample({
  Map<String, Object?> featuresJson = const {
    'embedding': <Object?>[0.1]
  },
  TrainingEligibilityStatus eligibilityStatus =
      TrainingEligibilityStatus.eligible,
  DatasetSplit split = DatasetSplit.train,
}) {
  return TrainingExample(
    id: _exampleId,
    userId: _userId,
    taskType: TrainingTaskType.visionClassification,
    sourceDetectionId: _detectionId,
    featureSchemaVersion: 'vision-features-v1',
    labelSchemaVersion: 'vocab-label-v1',
    builderVersion: 'builder-v1',
    featuresJson: featuresJson,
    targetJson: const {'class': 'cup'},
    eligibilityStatus: eligibilityStatus,
    qualityScore: 0.9,
    split: split,
    splitSeedVersion: 'split-v1',
    createdAt: _now,
  );
}

SyncOperation _buildSyncOperation(Iterable<String> dependencyIds) {
  return SyncOperation(
    operationId: _operationId,
    userId: _userId,
    entityType: SyncEntityType.photoNote,
    entityId: _exampleId,
    operationType: SyncOperationType.update,
    payloadJson: const {},
    dependencyIds: dependencyIds,
    state: SyncOperationState.pending,
    attemptCount: 0,
    createdAt: _now,
    updatedAt: _now,
  );
}
