import '../entities/local_vocabulary_match.dart';

abstract interface class LocalVocabularyLookupRepository {
  Future<List<LocalVocabularyMatch>> lookupLocalVocabulary({
    required String userId,
    required String query,
    int limit = 8,
  });
}
