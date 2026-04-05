import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ Firebase 服務管理類別 - 負責帳號認證與用戶管理
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 用戶狀態監聽器
final StreamController<fb_auth.User?> _userStateController =
    StreamController<fb_auth.User?>.broadcast();
Stream<fb_auth.User?> get userStateChanges => _userStateController.stream;

  // 當前用戶
fb_auth.User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;

  /// 初始化 Firebase 服務
  Future<void> initialize() async {
    // 監聽認證狀態變化
    _auth.authStateChanges().listen((fb_auth.User? user) {
      _userStateController.add(user);
      _saveUserState(user);
    });

    // 載入上次登入狀態
    await _loadUserState();
  }

  /// Google 登入
Future<fb_auth.UserCredential?> signInWithGoogle() async {
    try {
      // 觸發 Google 登入流程
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 用戶取消登入
        return null;
      }

      // 取得認證詳細資訊
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 建立 Firebase 認證憑據
      final credential = fb_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 登入 Firebase
      final fb_auth.UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      print('✅ Google 登入成功: ${userCredential.user?.displayName}');
      return userCredential;
    } catch (e) {
      print('❌ Google 登入失敗: $e');
      rethrow;
    }
  }

  /// 登出
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);

      // 清除本地儲存的登入狀態
      await _clearUserState();

      print('✅ 登出成功');
    } catch (e) {
      print('❌ 登出失敗: $e');
      rethrow;
    }
  }

  /// 刪除帳號
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

  /// 重新認證（用於敏感操作）
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

  /// 取得用戶資訊
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

  /// 取得用戶 ID（用於資料庫關聯）
  String? getUserId() {
    return currentUser?.uid;
  }

  /// 儲存用戶登入狀態到本地
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

  /// 載入本地儲存的用戶狀態
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

  /// 清除本地儲存的用戶狀態
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

  /// 釋放資源
  void dispose() {
    _userStateController.close();
  }
}
