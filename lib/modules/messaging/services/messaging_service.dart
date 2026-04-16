import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/services/auth_service.dart';

class MessagingService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 取得目前用戶的排程集合路徑（發件箱）
  static CollectionReference _userMessages() {
    final uid = AuthService.userId ?? '';
    return _db.collection('users').doc(uid).collection('scheduled_messages');
  }

  // ✅ 全域訊息集合（用於跨用戶發送訊息）
  static CollectionReference get _globalMessages =>
      _db.collection('scheduled_messages');

  // 新增排程到雲端
  static Future<String?> addMessage(Map<String, dynamic> data) async {
    try {
      final uid = AuthService.userId ?? '';
      final docRef = await _userMessages().add({
        ...data,
        'senderId': uid,
        'created_at': FieldValue.serverTimestamp(),
      });
      print('✅ 雲端新增排程成功：${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ 雲端新增排程失敗：$e');
      return null;
    }
  }

  // ✅ 新增：發送訊息給指定收件人（會同時存到全域集合）
  static Future<String?> sendMessageToUser({
    required String receiverId,
    required String message,
    required DateTime scheduledTime,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final senderId = AuthService.userId ?? '';
      final senderName = AuthService.currentUser?.displayName ?? '未知用戶';
      
      final docRef = await _globalMessages.add({
        'senderId': senderId,
        'senderName': senderName,
        'receiverId': receiverId,
        'message': message,
        'time': Timestamp.fromDate(scheduledTime),
        'status': 'scheduled', // scheduled → sent → read
        'created_at': FieldValue.serverTimestamp(),
        ...?extraData,
      });
      print('✅ 發送訊息給 $receiverId 成功：${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ 發送訊息失敗：$e');
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

  // ✅ 新增：取得收件匣訊息（收件人是當前用戶的訊息）
  static Future<List<Map<String, dynamic>>> getInboxMessages() async {
    try {
      final uid = AuthService.userId ?? '';
      final snapshot = await _globalMessages
          .where('receiverId', isEqualTo: uid)
          .orderBy('time', descending: true)
          .get();
      return snapshot.docs
          .map((doc) =>
              {'firestore_id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('❌ 取得收件匣失敗：$e');
      return [];
    }
  }

  // ✅ 新增：取得未讀訊息數量
  static Future<int> getUnreadCount() async {
    try {
      final uid = AuthService.userId ?? '';
      final snapshot = await _globalMessages
          .where('receiverId', isEqualTo: uid)
          .where('status', isEqualTo: 'scheduled')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ 取得未讀數量失敗：$e');
      return 0;
    }
  }

  // ✅ 新增：監聽未讀訊息數量（即時更新）
  static Stream<int> watchUnreadCount() {
    final uid = AuthService.userId ?? '';
    return _globalMessages
        .where('receiverId', isEqualTo: uid)
        .where('status', isEqualTo: 'scheduled')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ✅ 新增：標記訊息為已讀
  static Future<void> markMessageAsRead(String firestoreId) async {
    try {
      await _globalMessages.doc(firestoreId).update({
        'status': 'read',
        'read_at': FieldValue.serverTimestamp(),
      });
      print('✅ 訊息已標記為已讀：$firestoreId');
    } catch (e) {
      print('❌ 標記已讀失敗：$e');
    }
  }

  // ✅ 新增：取得自己發出訊息的狀態（用於已讀回執）
  static Future<String?> getMessageStatus(String firestoreId) async {
    try {
      final doc = await _globalMessages.doc(firestoreId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['status'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ 取得訊息狀態失敗：$e');
      return null;
    }
  }

  // ✅ 新增：監聽訊息狀態變化（用於即時顯示已讀回執）
  static Stream<String?> watchMessageStatus(String firestoreId) {
    return _globalMessages.doc(firestoreId).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['status'] as String?;
      }
      return null;
    });
  }

  // ✅ 新增：取得發件箱（自己發出的訊息，含已讀狀態）
  static Future<List<Map<String, dynamic>>> getSentMessages() async {
    try {
      final uid = AuthService.userId ?? '';
      final snapshot = await _globalMessages
          .where('senderId', isEqualTo: uid)
          .orderBy('time', descending: true)
          .get();
      return snapshot.docs
          .map((doc) =>
              {'firestore_id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print('❌ 取得發件箱失敗：$e');
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
