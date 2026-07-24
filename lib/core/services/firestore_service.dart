import 'package:cloud_firestore/cloud_firestore.dart';

/// Central Firestore Service wrapper cho ứng dụng Capy Vocab App
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  FirebaseFirestore get db => _firestore;

  /// Lấy Collection reference
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _firestore.collection(path);
  }

  /// Lấy Document reference
  DocumentReference<Map<String, dynamic>> doc(String path) {
    return _firestore.doc(path);
  }

  /// Đọc dữ liệu 1 Document
  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(String path) async {
    return await _firestore.doc(path).get();
  }

  /// Thêm hoặc cập nhật dữ liệu Document
  Future<void> setDocument({
    required String path,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    await _firestore.doc(path).set(data, SetOptions(merge: merge));
  }

  /// Xóa Document
  Future<void> deleteDocument(String path) async {
    await _firestore.doc(path).delete();
  }

  /// Lấy danh sách Document theo Query
  Future<QuerySnapshot<Map<String, dynamic>>> getCollection(
    String path, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)?
        queryBuilder,
  }) async {
    Query<Map<String, dynamic>> query = _firestore.collection(path);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return await query.get();
  }

  /// Lắng nghe dữ liệu Document thay đổi thời gian thực
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamDocument(String path) {
    return _firestore.doc(path).snapshots();
  }

  /// Lắng nghe Query thay đổi thời gian thực
  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String path, {
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)?
        queryBuilder,
  }) {
    Query<Map<String, dynamic>> query = _firestore.collection(path);
    if (queryBuilder != null) {
      query = queryBuilder(query);
    }
    return query.snapshots();
  }
}
