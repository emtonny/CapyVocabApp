import '../entities/library_enums.dart';
import '../entities/training_models.dart';

abstract interface class TrainingRepository {
  Future<void> saveExample(TrainingExample example);

  Future<List<TrainingExample>> getEligibleExamples({
    required String userId,
    required TrainingTaskType taskType,
    int limit = 5000,
  });

  /// Persists a manifest and all example links as one transaction.
  Future<void> saveDatasetManifest({
    required DatasetManifest manifest,
    required Iterable<String> trainingExampleIds,
  });

  Future<void> saveModelVersion(ModelVersion modelVersion);

  Future<ModelVersion?> getActiveModel({
    required String userId,
    required TrainingTaskType taskType,
  });

  Future<void> saveTrainingRun({
    required TrainingRun run,
    required Iterable<TrainingRunExample> examples,
  });

  /// Returns models whose lineage includes any of the supplied source IDs.
  Future<List<ModelVersion>> findModelsUsingSources({
    required String userId,
    required Iterable<String> sourceIds,
  });

  Future<void> markModelsInvalidated({
    required String userId,
    required Iterable<String> modelVersionIds,
    required DateTime invalidatedAt,
  });
}
