import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'database_helper.dart';

/// ✅ 用戶個人資料模型 - 移到外部定義
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String photoURL;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic> preferences;

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoURL,
    this.createdAt,
    this.lastLoginAt,
    this.preferences = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'photo_url': photoURL,
      'created_at': createdAt?.millisecondsSinceEpoch,
      'last_login_at': lastLoginAt?.millisecondsSinceEpoch,
      'preferences': preferences.toString(),
    };
  }

  static UserProfile fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? '',
      photoURL: map['photo_url'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : null,
      lastLoginAt: map['last_login_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['last_login_at'])
          : null,
      preferences: {}, // 簡化版本，可後續擴展
    );
  }
}

/// ✅ 用戶資料管理類別 - 整合Firebase用戶與本地資料
class UserManager {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// 初始化用戶管理器
  Future<void> initialize() async {
    // 監聽用戶狀態變化
    _firebaseService.userStateChanges.listen((user) {
      if (user != null) {
        // 修正型別：user 來自 firebase_auth.User
        _onUserSignedIn(user.uid);
      } else {
        _onUserSignedOut();
      }
    });
  }

  /// 取得當前用戶資料
  Future<UserProfile?> getCurrentUserProfile() async {
    final userInfo = _firebaseService.getUserInfo();
    if (userInfo == null) return null;

    try {
      // 從本地快取載入用戶資料
      final prefs = await SharedPreferences.getInstance();
      final cachedProfile = prefs.getString('user_profile_${userInfo['uid']}');

      if (cachedProfile != null) {
        // 這裡可以解析快取的用戶資料，簡化版本直接建立
      }

      // 建立或更新用戶資料
      final profile = UserProfile(
        uid: userInfo['uid'],
        email: userInfo['email'] ?? '',
        displayName: userInfo['displayName'] ?? '',
        photoURL: userInfo['photoURL'] ?? '',
        createdAt: userInfo['creationTime'] != null
            ? DateTime.parse(userInfo['creationTime'])
            : DateTime.now(),
        lastLoginAt: userInfo['lastSignInTime'] != null
            ? DateTime.parse(userInfo['lastSignInTime'])
            : DateTime.now(),
      );

      // 儲存到本地快取
      await _saveUserProfileToCache(profile);

      return profile;
    } catch (e) {
      print('❌ 取得用戶資料失敗: $e');
      return null;
    }
  }

  /// 用戶登入處理
  Future<void> _onUserSignedIn(String uid) async {
    try {
      print('✅ 用戶登入處理: $uid');

      // 更新最後登入時間
      await _updateLastLoginTime(uid);

      // 載入用戶的排程資料
      await _loadUserScheduledMessages(uid);

      // 初始化用戶偏好設定
      await _initializeUserPreferences(uid);

    } catch (e) {
      print('❌ 用戶登入處理失敗: $e');
    }
  }

  /// 用戶登出處理
  Future<void> _onUserSignedOut() async {
    try {
      print('✅ 用戶登出處理');

      // 清除敏感資料（保留基本設定）
      await _clearSensitiveData();

    } catch (e) {
      print('❌ 用戶登出處理失敗: $e');
    }
  }

  /// 儲存用戶資料到本地快取
  Future<void> _saveUserProfileToCache(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 簡化版本：儲存基本資訊
      await prefs.setString('current_user_uid', profile.uid);
      await prefs.setString('current_user_email', profile.email);
      await prefs.setString('current_user_name', profile.displayName);
      await prefs.setString('current_user_photo', profile.photoURL);
    } catch (e) {
      print('❌ 儲存用戶資料失敗: $e');
    }
  }

  /// 更新最後登入時間
  Future<void> _updateLastLoginTime(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_login_$uid', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('❌ 更新最後登入時間失敗: $e');
    }
  }

  /// 載入用戶的排程訊息（為未來雲端同步做準備）
  Future<void> _loadUserScheduledMessages(String uid) async {
    try {
      // 目前從本地資料庫載入，未來可擴展為雲端同步
      final messages = await _databaseHelper.getAllMessages();
      print('✅ 載入用戶排程訊息: ${messages.length} 筆');

      // 未來可在此處實作雲端同步邏輯

    } catch (e) {
      print('❌ 載入用戶排程訊息失敗: $e');
    }
  }

  /// 初始化用戶偏好設定
  Future<void> _initializeUserPreferences(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 設定預設偏好（如果不存在）
      if (!prefs.containsKey('notification_enabled_$uid')) {
        await prefs.setBool('notification_enabled_$uid', true);
      }

      if (!prefs.containsKey('theme_mode_$uid')) {
        await prefs.setString('theme_mode_$uid', 'system');
      }

      if (!prefs.containsKey('language_$uid')) {
        await prefs.setString('language_$uid', 'zh_TW');
      }

      print('✅ 用戶偏好設定初始化完成');
    } catch (e) {
      print('❌ 初始化用戶偏好設定失敗: $e');
    }
  }

  /// 清除敏感資料
  Future<void> _clearSensitiveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 移除當前用戶資訊
      await prefs.remove('current_user_uid');
      await prefs.remove('current_user_email');
      await prefs.remove('current_user_name');
      await prefs.remove('current_user_photo');

      // 保留應用程式基本設定，移除用戶特定設定
      print('✅ 敏感資料清除完成');
    } catch (e) {
      print('❌ 清除敏感資料失敗: $e');
    }
  }

  /// 用戶偏好設定相關方法

  /// 取得通知設定
  Future<bool> getNotificationEnabled() async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return true; // 預設啟用

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_enabled_$uid') ?? true;
  }

  /// 設定通知開關
  Future<void> setNotificationEnabled(bool enabled) async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled_$uid', enabled);
  }

  /// 取得主題模式
  Future<String> getThemeMode() async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return 'system';

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('theme_mode_$uid') ?? 'system';
  }

  /// 設定主題模式
  Future<void> setThemeMode(String mode) async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode_$uid', mode);
  }
}