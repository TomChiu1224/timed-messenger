// lib/services/fcm_service.dart
// ========== 🔔 Firebase Cloud Messaging 推播通知服務 ==========
// ✅ 支援背景和前景推播通知
// ✅ 自動處理 FCM Token 管理
// ✅ 整合本地通知系統

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_manager.dart';
import 'audio_manager.dart';
import 'vibration_manager.dart';

/// 🔔 FCM 推播通知服務管理類別
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _fcmToken;
  bool _isInitialized = false;

  /// 取得 FCM Token
  String? get fcmToken => _fcmToken;

  /// 檢查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 🔧 初始化 FCM 服務
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔔 FCM 服務已初始化');
      return;
    }

    try {
      print('🔄 初始化 FCM 服務...');

      // 1. 請求通知權限
      final settings = await _requestPermission();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('⚠️ 用戶未授權推播通知');
        return;
      }

      // 2. 取得 FCM Token
      _fcmToken = await _messaging.getToken();
      print('✅ FCM Token: $_fcmToken');

      // 儲存 Token 到本地
      await _saveFCMToken(_fcmToken);

      // 3. 監聽 Token 更新
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        print('🔄 FCM Token 已更新: $newToken');
        _saveFCMToken(newToken);
      });

      // 4. 設定前景訊息處理
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. 設定背景訊息處理（App 在背景但未關閉）
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

      // 6. 檢查從通知啟動的訊息（App 完全關閉時）
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleBackgroundMessage(initialMessage);
      }

      // 7. 配置 iOS 前景通知顯示
      if (Platform.isIOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _isInitialized = true;
      print('✅ FCM 服務初始化成功');
    } catch (e) {
      print('❌ FCM 服務初始化失敗: $e');
      rethrow;
    }
  }

  /// 📱 請求推播通知權限
  Future<NotificationSettings> _requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('📱 通知權限狀態: ${settings.authorizationStatus}');
      return settings;
    } catch (e) {
      print('❌ 請求通知權限失敗: $e');
      rethrow;
    }
  }

  /// 💾 儲存 FCM Token
  Future<void> _saveFCMToken(String? token) async {
    if (token == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
      await prefs.setString('fcm_token_updated_at', DateTime.now().toIso8601String());
      print('✅ FCM Token 已儲存');
    } catch (e) {
      print('❌ 儲存 FCM Token 失敗: $e');
    }
  }

  /// 📥 載入已儲存的 FCM Token
  Future<String?> loadSavedToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('fcm_token');
      final updatedAt = prefs.getString('fcm_token_updated_at');

      if (token != null && updatedAt != null) {
        print('✅ 載入已儲存的 FCM Token (更新於: $updatedAt)');
        return token;
      }
    } catch (e) {
      print('❌ 載入 FCM Token 失敗: $e');
    }
    return null;
  }

  /// 🔔 處理前景訊息（App 在前台運行時）
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 收到前景推播: ${message.messageId}');
    print('   標題: ${message.notification?.title}');
    print('   內容: ${message.notification?.body}');
    print('   資料: ${message.data}');

    // 播放音效（使用預設通知音）
    try {
      await AudioManager.playSound(
        soundId: 'notification',
        volume: 0.8,
        repeat: 1,
      );
    } catch (e) {
      print('⚠️ 播放音效失敗: $e');
    }

    // 震動（使用短震動）
    try {
      await VibrationManager.playVibration(
        patternId: 'short',
        intensity: 0.8,
        repeat: 1,
      );
    } catch (e) {
      print('⚠️ 震動失敗: $e');
    }

    // 顯示本地通知（確保用戶能看到）
    await _showLocalNotification(message);
  }

  /// 🔔 處理背景訊息（App 在背景或從通知點擊開啟）
  Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('🔔 處理背景推播: ${message.messageId}');
    print('   標題: ${message.notification?.title}');
    print('   內容: ${message.notification?.body}');
    print('   資料: ${message.data}');

    // 這裡可以處理用戶點擊通知後的導航邏輯
    // 例如：導航到特定頁面、更新 UI 等
  }

  /// 📲 顯示本地通知
  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) return;

      final notificationManager = NotificationManager();
      await notificationManager.scheduleNotification(
        id: message.hashCode,
        title: notification.title ?? '愛傳時提醒',
        body: notification.body ?? '',
        scheduledTime: DateTime.now(), // 立即顯示
      );
    } catch (e) {
      print('❌ 顯示本地通知失敗: $e');
    }
  }

  /// 📤 訂閱主題（用於群組推播）
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('✅ 已訂閱主題: $topic');
    } catch (e) {
      print('❌ 訂閱主題失敗: $e');
    }
  }

  /// 📤 取消訂閱主題
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('✅ 已取消訂閱主題: $topic');
    } catch (e) {
      print('❌ 取消訂閱主題失敗: $e');
    }
  }

  /// 🗑️ 刪除 FCM Token（登出時使用）
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      _fcmToken = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      await prefs.remove('fcm_token_updated_at');

      print('✅ FCM Token 已刪除');
    } catch (e) {
      print('❌ 刪除 FCM Token 失敗: $e');
    }
  }

  /// 📊 取得通知權限狀態
  Future<NotificationSettings> getNotificationSettings() async {
    return await _messaging.getNotificationSettings();
  }

  /// 🧪 測試推播通知（需要後端配合）
  Future<Map<String, dynamic>> getTestInfo() async {
    final settings = await getNotificationSettings();
    return {
      'isInitialized': _isInitialized,
      'fcmToken': _fcmToken,
      'authorizationStatus': settings.authorizationStatus.toString(),
      'alert': settings.alert.toString(),
      'badge': settings.badge.toString(),
      'sound': settings.sound.toString(),
    };
  }
}

/// 🌍 全域背景訊息處理器
/// 必須是頂層函數，用於處理 App 完全關閉時的背景訊息
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('🔔 背景訊息處理: ${message.messageId}');
  print('   標題: ${message.notification?.title}');
  print('   內容: ${message.notification?.body}');

  // 注意：這裡不能使用 UI 相關的操作
  // 只能進行數據處理、本地儲存等操作
}

/// 全域 FCM 服務實例
final fcmService = FCMService();
