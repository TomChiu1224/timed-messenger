import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_firestore_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// ✅ Firebase 服務管理類別 - 負責帳號認證與用戶管理
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final StreamController<fb_auth.User?> _userStateController =
      StreamController<fb_auth.User?>.broadcast();
  Stream<fb_auth.User?> get userStateChanges => _userStateController.stream;

  fb_auth.User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Future<void> initialize() async {
    _auth.authStateChanges().listen((fb_auth.User? user) {
      _userStateController.add(user);
      _saveUserState(user);
      if (user != null) {
        _ensureUserInFirestore(user);
      }
    });
    await _loadUserState();
  }

  Future<void> _ensureUserInFirestore(fb_auth.User user) async {
    try {
      final db = FirebaseFirestoreService();
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        print('⚠️ 取得 FCM Token 失敗: $e');
      }
      await db.setDocument('users', user.uid, {
        'uid': user.uid,
        'email': user.email ?? '',
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
        if (fcmToken != null) 'fcmToken': fcmToken,
      });
      print('✅ 用戶資料已同步到 Firestore');
    } catch (e) {
      print('❌ 用戶資料同步失敗: $e');
    }
  }

  Future<fb_auth.UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final fb_auth.UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user != null) {
        final db = FirebaseFirestoreService();
        await db.setDocument('users', user.uid, {
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'username': '',
          'phone_number': '',
          'lastLoginAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      print('✅ Google 登入成功: ${userCredential.user?.displayName}');
      return userCredential;
    } catch (e) {
      print('❌ Google 登入失敗: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
      await _clearUserState();
      print('✅ 登出成功');
    } catch (e) {
      print('❌ 登出失敗: $e');
      rethrow;
    }
  }

  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user != null) {
        await user.delete();
        await _googleSignIn.signOut();
        await _clearUserState();
        print('✅ 帳號刪除成功');
      }
    } catch (e) {
      print('❌ 帳號刪除失敗: $e');
      rethrow;
    }
  }

  Future<void> reauthenticate() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        final credential = fb_auth.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        await currentUser?.reauthenticateWithCredential(credential);
      }
    } catch (e) {
      print('❌ 重新認證失敗: $e');
      rethrow;
    }
  }

  Map<String, dynamic>? getUserInfo() {
    final fb_auth.User? user = currentUser;
    if (user == null) return null;
    return {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'emailVerified': user.emailVerified,
      'isAnonymous': user.isAnonymous,
      'creationTime': user.metadata.creationTime?.toIso8601String(),
      'lastSignInTime': user.metadata.lastSignInTime?.toIso8601String(),
    };
  }

  String? getUserId() => currentUser?.uid;

  Future<void> _saveUserState(fb_auth.User? user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (user != null) {
        await prefs.setString('user_uid', user.uid);
        await prefs.setString('user_email', user.email ?? '');
        await prefs.setString('user_name', user.displayName ?? '');
        await prefs.setString('user_photo', user.photoURL ?? '');
        await prefs.setBool('is_signed_in', true);
      } else {
        await _clearUserState();
      }
    } catch (e) {
      print('❌ 儲存用戶狀態失敗: $e');
    }
  }

  Future<void> _loadUserState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSignedIn = prefs.getBool('is_signed_in') ?? false;
      if (isSignedIn && currentUser != null) {
        print('✅ 載入上次登入狀態: ${currentUser?.displayName}');
      }
    } catch (e) {
      print('❌ 載入用戶狀態失敗: $e');
    }
  }

  Future<void> _clearUserState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_uid');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_photo');
      await prefs.setBool('is_signed_in', false);
    } catch (e) {
      print('❌ 清除用戶狀態失敗: $e');
    }
  }

  void dispose() {
    _userStateController.close();
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      final db = FirebaseFirestoreService();
      await db.setDocument('users', uid, data);
      print('✅ Firestore 用戶資料更新成功');
    } catch (e) {
      print('❌ Firestore 用戶資料更新失敗: $e');
      rethrow;
    }
  }

  Future<bool> checkUsernameExists(String username, String currentUid) async {
    try {
      final db = FirebaseFirestoreService();
      final results = await db.queryDocuments(
        'users',
        field: 'username',
        value: username,
      );
      return results.any((doc) => doc['uid'] != currentUid);
    } catch (e) {
      print('❌ 檢查 username 失敗: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> searchByUsername(String username) async {
    try {
      if (username.trim().isEmpty) return [];
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: username.trim())
          .where('username', isLessThan: '${username.trim()}\uf8ff')
          .limit(20)
          .get();
      final currentUid = getUserId();
      return querySnapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ 以用戶名稱搜尋失敗: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchByPhone(String phone) async {
    try {
      if (phone.trim().isEmpty) return [];
      final cleanPhone = phone.trim().replaceAll(RegExp(r'[\s\-]'), '');
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('phone_number', isEqualTo: cleanPhone)
          .limit(10)
          .get();
      final currentUid = getUserId();
      return querySnapshot.docs
          .where((doc) => doc.id != currentUid)
          .map((doc) => {'uid': doc.id, ...doc.data()})
          .toList();
    } catch (e) {
      print('❌ 以手機號碼搜尋失敗: $e');
      return [];
    }
  }

  Future<bool> sendFriendRequest(String toUid) async {
    try {
      final fromUid = getUserId();
      if (fromUid == null) return false;
      final requestId = '${fromUid}_$toUid';
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .set({
        'from': fromUid,
        'to': toUid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ 好友申請已發送');
      return true;
    } catch (e) {
      print('❌ 發送好友申請失敗: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getPendingFriendRequests() async {
    try {
      final uid = getUserId();
      if (uid == null) return [];
      final querySnapshot = await FirebaseFirestore.instance
          .collection('friend_requests')
          .where('to', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();
      final List<Map<String, dynamic>> results = [];
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(data['from'])
            .get();
        if (senderDoc.exists) {
          results.add({
            'requestId': doc.id,
            'fromUid': data['from'],
            ...senderDoc.data()!,
          });
        }
      }
      return results;
    } catch (e) {
      print('❌ 取得好友申請失敗: $e');
      return [];
    }
  }

  Future<bool> acceptFriendRequest(String requestId, String fromUid) async {
    try {
      final uid = getUserId();
      if (uid == null) return false;
      final batch = FirebaseFirestore.instance.batch();
      final now = FieldValue.serverTimestamp();
      batch.update(
        FirebaseFirestore.instance.collection('friend_requests').doc(requestId),
        {'status': 'accepted'},
      );
      batch.set(
        FirebaseFirestore.instance
            .collection('friendships')
            .doc(uid)
            .collection('friends')
            .doc(fromUid),
        {'status': 'accepted', 'since': now},
      );
      batch.set(
        FirebaseFirestore.instance
            .collection('friendships')
            .doc(fromUid)
            .collection('friends')
            .doc(uid),
        {'status': 'accepted', 'since': now},
      );
      await batch.commit();
      print('✅ 好友申請已接受');
      return true;
    } catch (e) {
      print('❌ 接受好友申請失敗: $e');
      return false;
    }
  }

  Future<bool> rejectFriendRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'rejected'});
      print('✅ 好友申請已拒絕');
      return true;
    } catch (e) {
      print('❌ 拒絕好友申請失敗: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFriendList() async {
    try {
      final uid = getUserId();
      if (uid == null) return [];
      final querySnapshot = await FirebaseFirestore.instance
          .collection('friendships')
          .doc(uid)
          .collection('friends')
          .where('status', isEqualTo: 'accepted')
          .get();
      final List<Map<String, dynamic>> results = [];
      for (final doc in querySnapshot.docs) {
        final friendDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .get();
        if (friendDoc.exists) {
          results.add({'uid': doc.id, ...friendDoc.data()!});
        }
      }
      return results;
    } catch (e) {
      print('❌ 取得好友列表失敗: $e');
      return [];
    }
  }

  Future<bool> saveScheduledMessage(Map<String, dynamic> messageData) async {
    try {
      final uid = getUserId();
      if (uid == null) return false;
      final user = _auth.currentUser;
      await FirebaseFirestore.instance.collection('scheduled_messages').add({
        ...messageData,
        'senderId': uid,
        'senderName': user?.displayName ?? user?.email ?? '未知用戶',
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ 訊息已儲存到 Firestore');
      return true;
    } catch (e) {
      print('❌ 儲存訊息失敗: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getReceivedMessages() async {
    final user = _auth.currentUser;
    if (user == null) return [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('scheduled_messages')
          .where('receiverId', isEqualTo: user.uid)
          .get();
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
      list.sort((a, b) {
        final aTime = a['scheduledTime'] ?? 0;
        final bTime = b['scheduledTime'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });
      return list;
    } catch (e) {
      print('❌ 取得收件匣失敗：$e');
      return [];
    }
  }

  Future<void> markMessageAsRead(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('scheduled_messages')
          .doc(docId)
          .update({'status': 'read'});
      print('✅ 訊息已標記為已讀：$docId');
    } catch (e) {
      print('❌ 標記已讀失敗：$e');
    }
  }

  Future<void> deleteReceivedMessage(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('scheduled_messages')
          .doc(docId)
          .delete();
      print('✅ 訊息已刪除：$docId');
    } catch (e) {
      print('❌ 刪除訊息失敗：$e');
    }
  }

  /// ✅ 群發訊息給多個收件人
  Future<bool> saveScheduledMessageToMultiple({
    required Map<String, dynamic> messageData,
    required List<Map<String, dynamic>> receivers,
  }) async {
    try {
      final user = _auth.currentUser;
      final uid = user?.uid;
      if (uid == null) return false;
      final batch = FirebaseFirestore.instance.batch();
      for (final receiver in receivers) {
        final docRef =
            FirebaseFirestore.instance.collection('scheduled_messages').doc();
        batch.set(docRef, {
          ...messageData,
          'senderId': uid,
          'senderName': user?.displayName ?? user?.email ?? '未知用戶',
          'receiverId': receiver['uid'],
          'receiverName':
              receiver['displayName'] ?? receiver['username'] ?? '未知',
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      print('✅ 群發訊息已儲存，共 ${receivers.length} 位收件人');
      return true;
    } catch (e) {
      print('❌ 群發失敗：$e');
      return false;
    }
  }
}
