import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import 'database_helper.dart';

/// ???冽?犖鞈?璅∪? - 蝘餃憭摰儔
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
      preferences: {}, // 蝪∪??嚗敺??游?
    );
  }
}

/// ???冽鞈?蝞∠?憿 - ?游?Firebase?冽??啗???
class UserManager {
  static final UserManager _instance = UserManager._internal();
  factory UserManager() => _instance;
  UserManager._internal();

  final FirebaseService _firebaseService = FirebaseService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// ????嗥恣?
  Future<void> initialize() async {
    // ???冽?????
    _firebaseService.userStateChanges.listen((user) {
      if (user != null) {
        // 靽格迤?嚗ser 靘 firebase_auth.User
        _onUserSignedIn(user.uid);
      } else {
        _onUserSignedOut();
      }
    });
  }

  /// ???嗅??冽鞈?
  Future<UserProfile?> getCurrentUserProfile() async {
    final userInfo = _firebaseService.getUserInfo();
    if (userInfo == null) return null;

    try {
      // 敺?啣翰???亦?嗉???
      final prefs = await SharedPreferences.getInstance();
      final cachedProfile = prefs.getString('user_profile_${userInfo['uid']}');

      if (cachedProfile != null) {
        // ?ㄐ?臭誑閫??敹怠???嗉???蝪∪???湔撱箇?
      }

      // 撱箇???啁?嗉???
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

      // ?脣??唳?啣翰??
      await _saveUserProfileToCache(profile);

      return profile;
    } catch (e) {
      print('?????冽鞈?憭望?: $e');
      return null;
    }
  }

  /// ?冽?餃??
  Future<void> _onUserSignedIn(String uid) async {
    try {
      print('???冽?餃??: $uid');

      // ?湔?敺?交???
      await _updateLastLoginTime(uid);

      // 頛?冽??蝔???
      await _loadUserScheduledMessages(uid);

      // ????嗅?憟質身摰?
      await _initializeUserPreferences(uid);

    } catch (e) {
      print('???冽?餃??憭望?: $e');
    }
  }

  /// ?冽?餃??
  Future<void> _onUserSignedOut() async {
    try {
      print('???冽?餃??');

      // 皜??鞈?嚗???祈身摰?
      await _clearSensitiveData();

    } catch (e) {
      print('???冽?餃??憭望?: $e');
    }
  }

  /// ?脣??冽鞈??唳?啣翰??
  Future<void> _saveUserProfileToCache(UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 蝪∪??嚗摮?祈?閮?
      await prefs.setString('current_user_uid', profile.uid);
      await prefs.setString('current_user_email', profile.email);
      await prefs.setString('current_user_name', profile.displayName);
      await prefs.setString('current_user_photo', profile.photoURL);
    } catch (e) {
      print('???脣??冽鞈?憭望?: $e');
    }
  }

  /// ?湔?敺?交???
  Future<void> _updateLastLoginTime(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_login_$uid', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('???湔?敺?交??仃?? $e');
    }
  }

  /// 頛?冽??蝔??荔??箸靘蝡臬?甇亙?皞?嚗?
  Future<void> _loadUserScheduledMessages(String uid) async {
    try {
      // ?桀?敺?啗??澈頛嚗靘?游??粹蝡臬?甇?
      final messages = await _databaseHelper.getAllMessages();
      print('載入完成');

      // ?芯??臬甇方?撖虫??脩垢?郊?摩

    } catch (e) {
      print('載入完成');
    }
  }

  /// ????嗅?憟質身摰?
  Future<void> _initializeUserPreferences(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 閮剖??身?末嚗???摮嚗?
      if (!prefs.containsKey('notification_enabled_$uid')) {
        await prefs.setBool('notification_enabled_$uid', true);
      }

      if (!prefs.containsKey('theme_mode_$uid')) {
        await prefs.setString('theme_mode_$uid', 'system');
      }

      if (!prefs.containsKey('language_$uid')) {
        await prefs.setString('language_$uid', 'zh_TW');
      }

      print('載入完成');
    } catch (e) {
      print('處理完成');
    }
  }

  /// 皜??鞈?
  Future<void> _clearSensitiveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 蝘駁?嗅??冽鞈?
      await prefs.remove('current_user_uid');
      await prefs.remove('current_user_email');
      await prefs.remove('current_user_name');
      await prefs.remove('current_user_photo');

      // 靽??蝔??箸閮剖?嚗宏?斤?嗥摰身摰?
      print('處理完成');
    } catch (e) {
      print('??皜??鞈?憭望?: $e');
    }
  }

  /// ?冽?末閮剖??賊??寞?

  /// ???閮剖?
  Future<bool> getNotificationEnabled() async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return true; // ?身?

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notification_enabled_$uid') ?? true;
  }

  /// 閮剖????
  Future<void> setNotificationEnabled(bool enabled) async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled_$uid', enabled);
  }

  /// ??銝駁?璅∪?
  Future<String> getThemeMode() async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return 'system';

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('theme_mode_$uid') ?? 'system';
  }

  /// 閮剖?銝駁?璅∪?
  Future<void> setThemeMode(String mode) async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode_$uid', mode);
  }

  /// 取得用戶名稱
  Future<String> getUsername() async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return '';
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_username_$uid') ?? '';
  }

  /// 取得手機號碼
  Future<String> getPhoneNumber() async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return '';
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_phone_$uid') ?? '';
  }

  /// 更新用戶個人資料
  Future<bool> updateUserProfile({
    required String username,
    required String phoneNumber,
    String? displayName,
  }) async {
    final uid = _firebaseService.getUserId();
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_username_$uid', username);
      await prefs.setString('user_phone_$uid', phoneNumber);
      return true;
    } catch (e) {
      print('更新失敗');
      return false;
    }
  }
}
