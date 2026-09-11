import '../domain/entities/library_cloud_delta.dart';

abstract interface class LibraryCloudPullGateway {
  String? get authenticatedUserId;

  Future<LibraryCloudDelta> pullLibraryDelta({
    required String userId,
    required int afterCursor,
    int limit = 100,
  });
}
