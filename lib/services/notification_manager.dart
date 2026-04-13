// lib/services/notification_manager.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  bool _isInitialized = false;
  final List<Map<String, dynamic>> _notifications = [];
  final Map<int, Timer> _scheduledTimers = {};
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool get isInitialized => _isInitialized;

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  IOSFlutterLocalNotificationsPlugin? get _iosPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

  Future<bool> checkExactAlarmPermission() async {
    if (Platform.isAndroid) {
      try {
        final canSchedule =
            await _androidPlugin?.canScheduleExactNotifications();
        if (canSchedule == false) {
          await _androidPlugin?.requestExactAlarmsPermission();
          return false;
        }
        return true;
      } catch (e) {
        print('⚠️ 無法檢查精確鬧鐘權限: $e');
      }
    }
    return true;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔄 初始化通知管理器...');

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: (details) {
          print('📱 用戶點擊通知: ${details.payload}');
        },
      );

      if (Platform.isAndroid) {
        // ✅ 三個排程頻道（分別對應三種音效選項，用戶可在手機設定各自設定鈴聲）
        await _androidPlugin
            ?.createNotificationChannel(AndroidNotificationChannel(
          'sched_notification_v5',
          '排程提醒 - 通知音',
          description: '排程訊息提醒（通知音）- 可在此設定鈴聲',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
        ));
        await _androidPlugin
            ?.createNotificationChannel(AndroidNotificationChannel(
          'sched_alert_v5',
          '排程提醒 - 提示音',
          description: '排程訊息提醒（系統提示音）- 可在此設定鈴聲',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
        ));
        await _androidPlugin
            ?.createNotificationChannel(AndroidNotificationChannel(
          'sched_click_v5',
          '排程提醒 - 點擊音',
          description: '排程訊息提醒（點擊音）- 可在此設定鈴聲',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 400, 200, 400]),
        ));

        // ✅ 試聽頻道（無震動）
        await _androidPlugin
            ?.createNotificationChannel(const AndroidNotificationChannel(
          'preview_notification_v5',
          '試聽 - 通知音',
          description: '試聽通知音（無震動）',
          importance: Importance.max,
          playSound: true,
          enableVibration: false,
        ));
        await _androidPlugin
            ?.createNotificationChannel(const AndroidNotificationChannel(
          'preview_alert_v5',
          '試聽 - 提示音',
          description: '試聽提示音（無震動）',
          importance: Importance.max,
          playSound: true,
          enableVibration: false,
        ));
        await _androidPlugin
            ?.createNotificationChannel(const AndroidNotificationChannel(
          'preview_click_v5',
          '試聽 - 點擊音',
          description: '試聽點擊音（無震動）',
          importance: Importance.max,
          playSound: true,
          enableVibration: false,
        ));

        print('✅ 通知頻道建立完成（v5：三個排程頻道＋一個試聽頻道）');
        await checkExactAlarmPermission();
      }

      if (Platform.isIOS) {
        await _iosPlugin?.requestPermissions(
            alert: true, badge: true, sound: true);
      }

      _isInitialized = true;
      print('✅ 通知管理器初始化完成');
    } catch (e) {
      print('❌ 初始化失敗: $e');
      _isInitialized = true;
    }
  }

  /// 根據音效類型選擇頻道
  String _getChannelId(String? soundType) {
    switch (soundType) {
      case 'alert':
        return 'sched_alert_v5';
      case 'click':
        return 'sched_click_v5';
      default:
        return 'sched_notification_v5';
    }
  }

  String _getChannelName(String? soundType) {
    switch (soundType) {
      case 'alert':
        return '排程提醒 - 提示音';
      case 'click':
        return '排程提醒 - 點擊音';
      default:
        return '排程提醒 - 通知音';
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? soundType,
    bool vibrationEnabled = true,
    List<int>? vibrationPattern,
    int vibrationRepeat = 1,
    int soundRepeat = 1,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      try {
        tz.local;
      } catch (e) {
        tz.initializeTimeZones();
        tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
      }

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
      final now = tz.TZDateTime.now(tz.local);

      if (tzScheduledTime.isBefore(now)) {
        print('⚠️ 時間已過，立即觸發');
        await showNotification(
          title: title,
          body: body,
          soundType: soundType,
          vibrationEnabled: vibrationEnabled,
        );
        return;
      }

      final channelId = _getChannelId(soundType);
      final channelName = _getChannelName(soundType);

      // ✅ 震動只用 enableVibration，不傳 vibrationPattern（避免 Realme 衝突）
      final androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: '排程訊息提醒',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: vibrationEnabled,
        vibrationPattern: vibrationEnabled
            ? Int64List.fromList([0, 400, 200, 400, 200, 400])
            : null,
      );

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        NotificationDetails(
          android: androidDetails,
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: body,
      );

      // ✅ soundRepeat > 1：每隔 5 秒排程額外通知
      if (soundRepeat > 1) {
        for (int i = 1; i < soundRepeat; i++) {
          final extraTime = tzScheduledTime.add(Duration(seconds: i * 15));
          await _plugin.zonedSchedule(
            id + i * 10000,
            title,
            body,
            extraTime,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channelId,
                channelName,
                channelDescription: '排程訊息提醒（重複$i）',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
                enableVibration: vibrationEnabled,
              ),
              iOS: const DarwinNotificationDetails(
                  presentSound: true, sound: 'default'),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
        print('✅ 已排程 $soundRepeat 次通知（每隔5秒）');
      }

      _notifications.add({
        'id': id,
        'title': title,
        'body': body,
        'scheduledTime': scheduledTime.toIso8601String()
      });
      print(
          '✅ 排程通知成功: $title @ $scheduledTime (重複$soundRepeat次, 震動:$vibrationEnabled)');
    } catch (e) {
      print('❌ 排程通知失敗: $e');
      rethrow;
    }
  }

  Future<void> _triggerNotification(
    String title,
    String body, {
    String? soundType,
    bool vibrationEnabled = true,
  }) async {
    try {
      final channelId = _getChannelId(soundType);
      final channelName = _getChannelName(soundType);

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: '排程訊息提醒',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: vibrationEnabled,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: body,
      );
    } catch (e) {
      print('❌ 通知觸發失敗: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
      _scheduledTimers[id]?.cancel();
      _scheduledTimers.remove(id);
      _notifications.removeWhere((n) => n['id'] == id);
    } catch (e) {
      print('❌ 取消通知失敗: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
      for (final t in _scheduledTimers.values) {
        t.cancel();
      }
      _scheduledTimers.clear();
      _notifications.clear();
    } catch (e) {
      print('❌ 取消所有通知失敗: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingNotifications() async {
    return _scheduledTimers.keys
        .map((id) => {'id': id, 'status': 'pending'})
        .toList();
  }

  Map<String, dynamic> getDetailedStatus() {
    return {
      'isInitialized': _isInitialized,
      'pendingCount': _scheduledTimers.length
    };
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? soundType,
    bool vibrationEnabled = true,
    List<int>? vibrationPattern,
    int vibrationRepeat = 1,
  }) async {
    if (!_isInitialized) await initialize();
    await _triggerNotification(
      title,
      body,
      soundType: soundType,
      vibrationEnabled: vibrationEnabled,
    );
  }

  Future<bool> testNotification() async {
    try {
      if (!_isInitialized) await initialize();
      await _triggerNotification('🧪 測試通知', '愛傳時通知系統正常！');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 🔊 試聽音效（無震動，對應各自頻道）
  Future<void> previewSound(String soundType) async {
    if (!_isInitialized) await initialize();

    String previewChannelId;
    String previewChannelName;
    String soundName;
    switch (soundType) {
      case 'alert':
        previewChannelId = 'preview_alert_v5';
        previewChannelName = '試聽 - 提示音';
        soundName = '提示音';
        break;
      case 'click':
        previewChannelId = 'preview_click_v5';
        previewChannelName = '試聽 - 點擊音';
        soundName = '點擊音';
        break;
      default:
        previewChannelId = 'preview_notification_v5';
        previewChannelName = '試聽 - 通知音';
        soundName = '通知音';
    }

    try {
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        '🔊 試聽音效',
        '正在播放：$soundName',
        NotificationDetails(
          android: AndroidNotificationDetails(
            previewChannelId,
            previewChannelName,
            channelDescription: '試聽 - $soundName（無震動）',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: false,
          ),
          iOS: const DarwinNotificationDetails(
              presentAlert: true, presentSound: true),
        ),
      );
      print('🔊 試聽已發送（無震動）: $soundName');
    } catch (e) {
      print('❌ 試聽失敗: $e');
    }
  }

  /// 📳 試聽震動
  Future<void> previewVibration(List<int> vibrationPattern,
      {String patternName = '震動'}) async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(pattern: vibrationPattern);
        print('📳 震動預覽: $patternName');
      }
    } catch (e) {
      print('❌ 震動預覽失敗: $e');
    }
  }
}

final notificationManager = NotificationManager();
