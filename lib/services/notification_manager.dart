// lib/services/notification_manager.dart
// ========== 🔧 本地通知管理器 - 支援震動與聲音通知 ==========
// ✅ 使用 flutter_local_notifications 發出有聲音的本地通知
// ✅ 使用 vibration 套件提供震動功能
// ✅ Android/iOS 完整支援

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:timezone/timezone.dart' as tz;

/// 🔧 本地通知管理器
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  bool _isInitialized = false;
  final List<Map<String, dynamic>> _notifications = [];
  final Map<int, Timer> _scheduledTimers = {}; // 保留用於測試，但主要使用 zonedSchedule
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

      // 創建 Android 通知頻道（為每種音效創建獨立頻道）
      if (Platform.isAndroid) {
        // 1. 通知音頻道
        const notificationChannel = AndroidNotificationChannel(
          'notification_sound_channel',
          '通知音',
          description: '排程訊息提醒 - 通知音',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 200]),
        );

        // 2. 系統提示音頻道
        const alertChannel = AndroidNotificationChannel(
          'alert_sound_channel',
          '系統提示音',
          description: '排程訊息提醒 - 系統提示音',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 200]),
        );

        // 3. 點擊音頻道
        const clickChannel = AndroidNotificationChannel(
          'click_sound_channel',
          '點擊音',
          description: '排程訊息提醒 - 點擊音',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 200]),
        );

        final androidPlugin = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        await androidPlugin?.createNotificationChannel(notificationChannel);
        await androidPlugin?.createNotificationChannel(alertChannel);
        await androidPlugin?.createNotificationChannel(clickChannel);

        print('✅ Android 通知頻道已創建（三種音效頻道：通知音、系統提示音、點擊音）');
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

  /// 📅 排程通知（使用真正的背景排程，App關閉也能觸發）
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? soundType,
    List<int>? vibrationPattern,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 轉換為 TZDateTime 用於排程
      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      final now = tz.TZDateTime.now(tz.local);
      if (tzScheduledTime.isBefore(now)) {
        print('⚠️ 排程時間已過，將立即觸發通知: $title');
        await showNotification(
          title: title,
          body: body,
          soundType: soundType ?? 'notification',
          vibrationPattern: vibrationPattern,
        );
        return;
      }

      // 根據音效類型選擇通知頻道
      String channelId;
      String channelName;
      switch (soundType) {
        case 'alert':
          channelId = 'alert_sound_channel';
          channelName = '系統提示音';
          break;
        case 'click':
          channelId = 'click_sound_channel';
          channelName = '點擊音';
          break;
        case 'notification':
        default:
          channelId = 'notification_sound_channel';
          channelName = '通知音';
          break;
      }

      // 設定 Android 通知細節
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '排程訊息提醒通知 - $channelName',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern != null
            ? Int64List.fromList(vibrationPattern)
            : const Int64List.fromList([0, 200, 100, 200, 100, 200]),
      );

      // 設定 iOS 通知細節
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 使用 zonedSchedule 排程通知（這會在背景執行，即使 App 關閉）
      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: body,
      );

      // 記錄通知
      _notifications.add({
        'id': id,
        'title': title,
        'body': body,
        'scheduledTime': scheduledTime.toIso8601String(),
      });

      print('⏰ 背景通知已排程（App關閉也能觸發）: $title 於 ${scheduledTime.toString()}');
    } catch (e) {
      print('❌ 排程通知失敗: $e');
      rethrow;
    }
  }

  /// 觸發通知（播放音效和震動）
  /// soundType: notification, alert, click
  Future<void> _triggerNotification(
    String title,
    String body, {
    String soundType = 'notification',
    List<int>? vibrationPattern,
  }) async {
    try {
      // 1. 震動功能（使用 vibration 套件）
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // 使用自訂震動模式或預設脈衝震動模式（三次短震）
        final pattern = vibrationPattern ?? [0, 200, 100, 200, 100, 200];
        await Vibration.vibrate(pattern: pattern);
        print('✅ 震動已觸發');
      } else {
        print('⚠️ 設備不支援震動功能');
      }

      // 2. 根據音效類型選擇對應的通知頻道
      String channelId;
      String channelName;
      switch (soundType) {
        case 'alert':
          channelId = 'alert_sound_channel';
          channelName = '系統提示音';
          break;
        case 'click':
          channelId = 'click_sound_channel';
          channelName = '點擊音';
          break;
        case 'notification':
        default:
          channelId = 'notification_sound_channel';
          channelName = '通知音';
          break;
      }

      // 3. 發出本地通知（使用對應頻道的系統音效）
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '排程訊息提醒通知 - $channelName',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern != null
            ? Int64List.fromList(vibrationPattern)
            : const Int64List.fromList([0, 200, 100, 200, 100, 200]),
        // 使用對應頻道的系統音效
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      final notificationDetails = NotificationDetails(
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

      print('🔔 通知觸發成功 [$channelName]: $title - $body');
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

  /// 🗑️ 取消通知（取消背景排程通知）
  Future<void> cancelNotification(int id) async {
    try {
      // 取消 flutter_local_notifications 的排程通知
      await _flutterLocalNotificationsPlugin.cancel(id);

      // 清理舊的 Timer（如果有）
      final timer = _scheduledTimers[id];
      if (timer != null) {
        timer.cancel();
        _scheduledTimers.remove(id);
      }

      // 移除記錄
      _notifications.removeWhere((n) => n['id'] == id);

      print('✅ 背景通知已取消: ID $id');
    } catch (e) {
      print('❌ 取消通知失敗: $e');
    }
  }

  /// 🗑️ 取消所有通知
  Future<void> cancelAllNotifications() async {
    try {
      // 取消所有 flutter_local_notifications 的排程通知
      await _flutterLocalNotificationsPlugin.cancelAll();

      // 清理所有 Timer
      for (final timer in _scheduledTimers.values) {
        timer.cancel();
      }
      _scheduledTimers.clear();

      // 清空記錄
      _notifications.clear();

      print('✅ 所有背景通知已取消');
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
  /// soundType: notification, alert, click
  Future<void> showNotification({
    required String title,
    required String body,
    String soundType = 'notification',
    List<int>? vibrationPattern,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    await _triggerNotification(
      title,
      body,
      soundType: soundType,
      vibrationPattern: vibrationPattern,
    );
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

  /// 🔊 預覽音效（發送通知）
  /// soundType: notification, alert, click
  Future<void> previewSound(String soundType) async {
    if (!_isInitialized) {
      await initialize();
    }

    String soundName;
    switch (soundType) {
      case 'alert':
        soundName = '系統提示音';
        break;
      case 'click':
        soundName = '點擊音';
        break;
      case 'notification':
      default:
        soundName = '通知音';
        break;
    }

    await _triggerNotification(
      '🔊 音效預覽',
      '正在播放：$soundName',
      soundType: soundType,
      vibrationPattern: [0, 100], // 簡短震動
    );
  }

  /// 📳 預覽震動（發送通知並使用指定震動模式）
  Future<void> previewVibration(List<int> vibrationPattern, {String patternName = '震動'}) async {
    if (!_isInitialized) {
      await initialize();
    }

    await _triggerNotification(
      '📳 震動預覽',
      '正在測試：$patternName',
      soundType: 'notification',
      vibrationPattern: vibrationPattern,
    );
  }
}

/// 全域通知管理器實例
final notificationManager = NotificationManager();
