enum AccountState { active, locked, pendingPurge }

enum ConsentType {
  cloudBackup,
  localPersonalization,
  federatedContribution,
}

enum ConsentEnforcementState { pending, applied, failed }

enum SyncStatus {
  localOnly,
  pending,
  syncing,
  synced,
  failedRetryable,
  blockedAuth,
  blockedContract,
  quarantined,
}

enum PhotoNoteVisibility { active, trash, all }

enum CaptureSource { camera, gallery, imported, migration }

enum ScanRunStatus { pending, succeeded, failed, quarantined }

enum AnnotationSource { userConfirmed, userCorrected, imported }

enum AnnotationQualityStatus { accepted, corrected, rejected }

enum LearningEventType { shown, answered, hinted, skipped, corrected }

enum SyncEntityType {
  mediaAsset,
  photoNote,
  scanRun,
  vocabDetection,
  vocabAnnotation,
  album,
  albumPhotoNote,
  learningEvent,
  srsProgress,
}

enum SyncOperationType { create, update, softDelete, purge, upload, relation }

enum SyncOperationState { pending, running, retry, blocked, done }

enum TrainingTaskType { srsRecall, visionClassification, embeddingRerank }

enum TrainingEligibilityStatus { eligible, excluded, quarantined }

enum DatasetSplit { train, validation, test, excluded }

enum ModelActivationStatus { candidate, active, superseded, invalidated }

enum TrainingRunStatus { pending, running, succeeded, failed, cancelled }
