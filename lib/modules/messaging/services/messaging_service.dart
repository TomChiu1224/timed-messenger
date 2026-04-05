import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/services/auth_service.dart';

class MessagingService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 取得目前用戶的排程集合路徑
  static CollectionReference _userMessages() {
    final uid = AuthService.userId ?? '';
    return _db.collection('users').doc(uid).collection('scheduled_messages');
  }

  // 新增排程到雲端
  static Future<String?> addMessage(Map<String, dynamic> data) async {
    try {
      final docRef = await _userMessages().add({
        ...data,
        'created_at': FieldValue.serverTimestamp(),
      });
      print('✅ 雲端新增排程成功：${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ 雲端新增排程失敗：$e');
      return null;
    }
  }

  // 取得所有雲端排程
  static Future<List<Map<String, dynamic>>> getAllMessages() async {
    try {
      final snapshot =
          await _userMessages().orderBy('time', descending: false).get();
      return snapshot.docs
          .map((doc) =>
              {'firestore_id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('❌ 取得雲端排程失敗：$e');
      return [];
    }
  }

  // 刪除雲端排程
  static Future<void> deleteMessage(String firestoreId) async {
    try {
      await _userMessages().doc(firestoreId).delete();
      print('✅ 雲端刪除排程成功：$firestoreId');
    } catch (e) {
      print('❌ 雲端刪除排程失敗：$e');
    }
  }

  // 更新雲端排程
  static Future<void> updateMessage(
      String firestoreId, Map<String, dynamic> data) async {
    try {
      await _userMessages().doc(firestoreId).update(data);
      print('✅ 雲端更新排程成功：$firestoreId');
    } catch (e) {
      print('❌ 雲端更新排程失敗：$e');
    }
  }
}
