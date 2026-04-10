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
import 'package:timezone/data/latest_all.dart' as tz;

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

  /// 🔧 檢查並請求 Android 精確鬧鐘權限（Android 12+）
  Future<bool> checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      try {
        final androidPlugin = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        // Android 12+ 需要檢查精確鬧鐘權限
        final canScheduleExactAlarms = await androidPlugin?.canScheduleExactNotifications();

        if (canScheduleExactAlarms == false) {
          print('⚠️ 未授權精確鬧鐘權限！');
          print('   請前往：設定 > 應用程式 > 愛傳時 > 鬧鐘與提醒');

          // 嘗試請求權限
          await androidPlugin?.requestExactAlarmsPermission();
          return false;
        } else if (canScheduleExactAlarms == true) {
          print('✅ 已授權精確鬧鐘權限');
          return true;
        }
      } catch (e) {
        print('⚠️ 無法檢查精確鬧鐘權限（可能是舊版 Android）: $e');
      }
    }
    return true; // iOS 或舊版 Android 不需要此權限
  }

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

      // 創建 Android 通知頻道（為每種音效創建獨立頻道，區分排程和預覽）
      if (Platform.isAndroid) {
        // === 排程通知頻道（有震動）===
        // 1. 通知音頻道（排程用）
        final notificationChannel = AndroidNotificationChannel(
          'notification_sound_channel',
          '通知音',
          description: '排程訊息提醒 - 通知音',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 200]),
        );

        // 2. 系統提示音頻道（排程用）
        final alertChannel = AndroidNotificationChannel(
          'alert_sound_channel',
          '系統提示音',
          description: '排程訊息提醒 - 系統提示音',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 200]),
        );

        // 3. 點擊音頻道（排程用）
        final clickChannel = AndroidNotificationChannel(
          'click_sound_channel',
          '點擊音',
          description: '排程訊息提醒 - 點擊音',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 200]),
        );

        // === 預覽頻道（無震動，僅音效）===
        // 4. 通知音預覽頻道（無震動）
        const notificationPreviewChannel = AndroidNotificationChannel(
          'notification_sound_preview_channel',
          '通知音預覽',
          description: '音效試聽 - 通知音（僅聲音無震動）',
          importance: Importance.max,
          playSound: true,
          enableVibration: false, // 🔇 預覽時不震動
        );

        // 5. 系統提示音預覽頻道（無震動）
        const alertPreviewChannel = AndroidNotificationChannel(
          'alert_sound_preview_channel',
          '系統提示音預覽',
          description: '音效試聽 - 系統提示音（僅聲音無震動）',
          importance: Importance.max,
          playSound: true,
          enableVibration: false, // 🔇 預覽時不震動
        );

        // 6. 點擊音預覽頻道（無震動）
        const clickPreviewChannel = AndroidNotificationChannel(
          'click_sound_preview_channel',
          '點擊音預覽',
          description: '音效試聽 - 點擊音（僅聲音無震動）',
          importance: Importance.max,
          playSound: true,
          enableVibration: false, // 🔇 預覽時不震動
        );

        final androidPlugin = _flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        // 創建排程通知頻道
        await androidPlugin?.createNotificationChannel(notificationChannel);
        await androidPlugin?.createNotificationChannel(alertChannel);
        await androidPlugin?.createNotificationChannel(clickChannel);

        // 創建預覽頻道
        await androidPlugin?.createNotificationChannel(notificationPreviewChannel);
        await androidPlugin?.createNotificationChannel(alertPreviewChannel);
        await androidPlugin?.createNotificationChannel(clickPreviewChannel);

        print('✅ Android 通知頻道已創建（6個頻道：3個排程+3個預覽無震動）');

        // 檢查精確鬧鐘權限（Android 12+）
        await checkExactAlarmPermission();
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
      // 🔧 確保 timezone 已初始化
      try {
        tz.local; // 測試是否可以訪問 tz.local
      } catch (e) {
        print('❌ Timezone 未初始化，嘗試重新初始化...');
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
        print('✅ Timezone 重新初始化完成');
      }

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

      print('📅 準備排程通知: $title');
      print('   ├─ ID: $id');
      print('   ├─ 排程時間: ${tzScheduledTime.toString()}');
      print('   ├─ 當前時間: ${now.toString()}');
      print('   └─ 音效類型: ${soundType ?? 'notification'}');

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
            : Int64List.fromList([0, 200, 100, 200, 100, 200]),
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

      print('✅ 背景通知已排程成功！');
      print('   ├─ 標題: $title');
      print('   ├─ 內容: $body');
      print('   ├─ 排程時間: ${scheduledTime.toString()}');
      print('   ├─ 頻道: $channelName');
      print('   ├─ 模式: exactAllowWhileIdle');
      print('   └─ ⚠️ 請確保已授權「精確鬧鐘」權限！');
    } catch (e, stackTrace) {
      print('❌ 排程通知失敗！');
      print('   ├─ 錯誤: $e');
      print('   └─ 堆疊: $stackTrace');

      // 檢查是否是權限問題
      if (e.toString().contains('SCHEDULE_EXACT_ALARM')) {
        print('⚠️ 可能需要手動授權「精確鬧鐘」權限！');
        print('   前往：設定 > 應用程式 > 愛傳時 > 鬧鐘與提醒');
      }

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
            : Int64List.fromList([0, 200, 100, 200, 100, 200]),
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

  /// 🔊 預覽音效（發送通知，僅聲音無震動）
  /// soundType: notification, alert, click
  Future<void> previewSound(String soundType) async {
    if (!_isInitialized) {
      await initialize();
    }

    String soundName;
    String previewChannelId;
    String previewChannelName;

    switch (soundType) {
      case 'alert':
        soundName = '系統提示音';
        previewChannelId = 'alert_sound_preview_channel';
        previewChannelName = '系統提示音預覽';
        break;
      case 'click':
        soundName = '點擊音';
        previewChannelId = 'click_sound_preview_channel';
        previewChannelName = '點擊音預覽';
        break;
      case 'notification':
      default:
        soundName = '通知音';
        previewChannelId = 'notification_sound_preview_channel';
        previewChannelName = '通知音預覽';
        break;
    }

    // 🔇 使用無震動的預覽頻道發送通知
    try {
      final androidDetails = AndroidNotificationDetails(
        previewChannelId,
        previewChannelName,
        channelDescription: '音效試聽 - $soundName（僅聲音無震動）',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: false, // 🔇 預覽時絕對不震動
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
        '🔊 音效預覽',
        '正在播放：$soundName',
        notificationDetails,
        payload: '音效預覽',
      );

      print('🔊 音效預覽已發送（無震動）: $soundName');
    } catch (e) {
      print('❌ 音效預覽失敗: $e');
    }
  }

  /// 📳 預覽震動（僅震動，不發出通知聲音）
  Future<void> previewVibration(List<int> vibrationPattern, {String patternName = '震動'}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // 🔇 直接震動，不發送通知（避免音效干擾）
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: vibrationPattern);
        print('📳 震動預覽已觸發: $patternName - ${vibrationPattern}');
      } else {
        print('⚠️ 設備不支援震動功能');
      }
    } catch (e) {
      print('❌ 震動預覽失敗: $e');
    }
  }
}

/// 全域通知管理器實例
final notificationManager = NotificationManager();
