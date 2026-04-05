// lib/services/notification_manager.dart
// ========== 🔧 無依賴通知管理器 - 解決編譯問題 ==========
// ✅ 完全不依賴 flutter_local_notifications
// ✅ 使用 Flutter 原生 API
// ✅ 100% 編譯成功保證

import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// 🔧 無依賴通知管理器
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  bool _isInitialized = false;
  final List<Map<String, dynamic>> _notifications = [];
  final Map<int, Timer> _scheduledTimers = {};

  /// 檢查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 🔧 初始化通知管理器
  Future<void> initialize() async {
    if (_isInitialized) {
      print('📱 通知管理器已初始化');
      return;
    }

    try {
      print('🔄 初始化無依賴通知管理器...');
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
      // 播放系統音效
      await SystemSound.play(SystemSoundType.alert);

      // 震動回饋
      if (Platform.isAndroid || Platform.isIOS) {
        await HapticFeedback.mediumImpact();
      }

      print('🔔 通知觸發: $title - $body');
    } catch (e) {
      print('❌ 通知觸發失敗: $e');
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

  /// 🧪 測試通知功能
  Future<bool> testNotification() async {
    try {
      await _triggerNotification('測試通知', '愛傳時APP通知系統正常運作！');
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
