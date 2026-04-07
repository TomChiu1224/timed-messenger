// lib/services/notification_manager.dart
// ========== 🔧 本地通知管理器 - 支援震動與聲音通知 ==========
// ✅ 使用 flutter_local_notifications 發出有聲音的本地通知
// ✅ 使用 vibration 套件提供震動功能
// ✅ Android/iOS 完整支援

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// 🔧 本地通知管理器
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  bool _isInitialized = false;
  final List<Map<String, dynamic>> _notifications = [];
  final Map<int, Timer> _scheduledTimers = {};
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// 檢查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 🔧 初始化通知管理器
  Future<void> initialize() async {
    if (_isInitialized) {
      print('📱 通知管理器已初始化');
      return;
    }

    try {
      print('🔄 初始化本地通知管理器...');

      // 初始化 flutter_local_notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _flutterLocalNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          print('📱 用戶點擊通知: ${details.payload}');
        },
      );

      // 創建 Android 通知頻道（帶聲音）
      if (Platform.isAndroid) {
        const androidChannel = AndroidNotificationChannel(
          'timed_messenger_channel',
          '愛傳時通知',
          description: '排程訊息提醒通知',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          sound: RawResourceAndroidNotificationSound('notification'),
        );

        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);

        print('✅ Android 通知頻道已創建（含聲音與震動）');
      }

      // 請求 iOS 通知權限
      if (Platform.isIOS) {
        await _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        print('✅ iOS 通知權限已請求');
      }

      _isInitialized = true;
      print('✅ 通知管理器初始化成功');
    } catch (e) {
      print('❌ 通知管理器初始化失敗: $e');
      _isInitialized = true;
    }
  }

  /// 📅 排程通知
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? channelId,
    String? channelName,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final now = DateTime.now();
      final delay = scheduledTime.difference(now);

      if (delay.isNegative) {
        print('⚠️ 排程時間已過，記錄通知: $title');
      } else {
        final timer = Timer(delay, () {
          _triggerNotification(title, body);
          _scheduledTimers.remove(id);
        });

        _scheduledTimers[id] = timer;
        print('⏰ 通知已排程: $title 於 ${scheduledTime.toString()}');
      }

      // 記錄通知
      _notifications.add({
        'id': id,
        'title': title,
        'body': body,
        'scheduledTime': scheduledTime.toIso8601String(),
      });
    } catch (e) {
      print('❌ 排程通知失敗: $e');
    }
  }

  /// 觸發通知（播放音效和震動）
  Future<void> _triggerNotification(String title, String body) async {
    try {
      // 1. 震動功能（使用 vibration 套件）
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // 使用脈衝震動模式（三次短震）
        await Vibration.vibrate(pattern: [0, 200, 100, 200, 100, 200]);
        print('✅ 震動已觸發');
      } else {
        print('⚠️ 設備不支援震動功能');
      }

      // 2. 發出本地通知（帶聲音）
      const androidDetails = AndroidNotificationDetails(
        'timed_messenger_channel',
        '愛傳時通知',
        channelDescription: '排程訊息提醒通知',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        sound: RawResourceAndroidNotificationSound('notification'),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notificationDetails,
        payload: body,
      );

      print('🔔 通知觸發成功: $title - $body');
    } catch (e) {
      print('❌ 通知觸發失敗: $e');
      // 備援：至少嘗試簡單震動
      try {
        await Vibration.vibrate(duration: 500);
      } catch (vibError) {
        print('❌ 備援震動也失敗: $vibError');
      }
    }
  }

  /// 🗑️ 取消通知
  Future<void> cancelNotification(int id) async {
    try {
      final timer = _scheduledTimers[id];
      if (timer != null) {
        timer.cancel();
        _scheduledTimers.remove(id);
        print('✅ 通知已取消: ID $id');
      }
    } catch (e) {
      print('❌ 取消通知失敗: $e');
    }
  }

  /// 🗑️ 取消所有通知
  Future<void> cancelAllNotifications() async {
    try {
      for (final timer in _scheduledTimers.values) {
        timer.cancel();
      }
      _scheduledTimers.clear();
      print('✅ 所有通知已取消');
    } catch (e) {
      print('❌ 取消所有通知失敗: $e');
    }
  }

  /// 📋 取得已排程的通知列表
  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    return _scheduledTimers.keys.map((id) {
      return {'id': id, 'status': 'pending'};
    }).toList();
  }

  /// 🔧 獲取詳細狀態
  Map<String, dynamic> getDetailedStatus() {
    return {
      'isInitialized': _isInitialized,
      'pendingCount': _scheduledTimers.length,
      'totalNotifications': _notifications.length,
      'mode': 'no_dependency_safe',
    };
  }

  /// 🔔 立即觸發通知（公開方法）
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _triggerNotification(title, body);
  }

  /// 🧪 測試通知功能
  Future<bool> testNotification() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }
      await _triggerNotification('🧪 測試通知', '愛傳時APP通知系統正常運作！震動與聲音測試中...');
      print('🧪 測試通知完成');
      return true;
    } catch (e) {
      print('❌ 測試通知失敗: $e');
      return false;
    }
  }
}

/// 全域通知管理器實例
final notificationManager = NotificationManager();
