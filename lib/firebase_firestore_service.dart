import 'package:cloud_firestore/cloud_firestore.dart';

/// ✅ Firestore 資料庫服務
class FirebaseFirestoreService {
  static final FirebaseFirestoreService _instance =
      FirebaseFirestoreService._internal();
  factory FirebaseFirestoreService() => _instance;
  FirebaseFirestoreService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> setDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    await _db
        .collection(collection)
        .doc(docId)
        .set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getDocument(
      String collection, String docId) async {
    final doc = await _db.collection(collection).doc(docId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }

  Future<List<Map<String, dynamic>>> queryDocuments(
    String collection, {
    required String field,
    required dynamic value,
  }) async {
    final snapshot = await _db
        .collection(collection)
        .where(field, isEqualTo: value)
        .limit(10)
        .get();
    return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<String> addDocument(
      String collection, Map<String, dynamic> data) async {
    final doc = await _db.collection(collection).add(data);
    return doc.id;
  }

  Future<void> updateDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    await _db.collection(collection).doc(docId).update(data);
  }

  Future<void> deleteDocument(String collection, String docId) async {
    await _db.collection(collection).doc(docId).delete();
  }

  Stream<Map<String, dynamic>?> watchDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return {'id': doc.id, ...doc.data()!};
    });
  }

  Stream<List<Map<String, dynamic>>> watchCollection(
    String collection, {
    String? field,
    dynamic value,
    String? orderBy,
    bool descending = false,
  }) {
    Query query = _db.collection(collection);
    if (field != null && value != null) {
      query = query.where(field, isEqualTo: value);
    }
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList());
  }

  Future<void> batchWrite(List<Map<String, dynamic>> operations) async {
    final batch = _db.batch();
    for (final op in operations) {
      final ref = _db.collection(op['collection']).doc(op['docId']);
      batch.set(ref, op['data'], SetOptions(merge: true));
    }
    await batch.commit();
  }
}
