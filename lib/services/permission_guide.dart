// lib/services/permission_guide.dart
// ========== 🔐 背景通知權限引導系統 ==========
// 針對小米、華為、OPPO 等品牌的激進省電機制提供用戶引導

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

class PermissionGuide {
  static const String _keyShownGuide = 'shown_permission_guide';

  /// 檢查是否需要顯示權限引導（僅第一次啟動）
  static Future<bool> shouldShowGuide() async {
    if (!Platform.isAndroid) return false;

    final prefs = await SharedPreferences.getInstance();
    final hasShown = prefs.getBool(_keyShownGuide) ?? false;
    return !hasShown;
  }

  /// 標記已顯示過引導
  static Future<void> markGuideAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShownGuide, true);
  }

  /// 顯示權限引導對話框
  static Future<void> showPermissionGuideDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false, // 必須按按鈕才能關閉
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.alarm, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text(
                '⚠️ 重要提醒',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '為了讓「愛傳時」在背景正常運作（App 關閉時也能觸發提醒），請務必開啟以下權限：',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildPermissionItem(
                  icon: Icons.alarm_add,
                  title: '1. 鬧鐘與提醒權限',
                  description: '允許 App 設定精確的排程通知',
                ),
                const SizedBox(height: 12),
                _buildPermissionItem(
                  icon: Icons.battery_charging_full,
                  title: '2. 電池優化豁免',
                  description: '設為「無限制」，避免系統強制關閉 App',
                ),
                const SizedBox(height: 12),
                _buildPermissionItem(
                  icon: Icons.autorenew,
                  title: '3. 自動啟動權限',
                  description: '允許 App 在背景自動啟動（小米/華為/OPPO 必須）',
                ),
                const SizedBox(height: 12),
                _buildPermissionItem(
                  icon: Icons.notifications_active,
                  title: '4. 背景執行不受限制',
                  description: '確保排程提醒能準時觸發',
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Text(
                    '📱 小米/華為/OPPO 用戶必須手動設定！\n系統的省電機制會阻止背景通知運作。',
                    style: TextStyle(fontSize: 14, color: Colors.deepOrange),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await markGuideAsShown();
                Navigator.of(context).pop();
              },
              child: const Text('稍後提醒', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                await markGuideAsShown();
                Navigator.of(context).pop();
                await openSystemSettings(context);
              },
              icon: const Icon(Icons.settings),
              label: const Text('前往設定'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 構建權限項目
  static Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.orange, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 打開系統設定頁面（提供多個入口）
  static Future<void> openSystemSettings(BuildContext context) async {
    if (!Platform.isAndroid) return;

    // 顯示設定引導選單
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '請選擇要前往的設定頁面：',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.alarm, color: Colors.orange),
                title: const Text('鬧鐘與提醒'),
                subtitle: const Text('設定精確排程權限'),
                onTap: () {
                  Navigator.pop(context);
                  _openExactAlarmSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.battery_charging_full, color: Colors.green),
                title: const Text('電池優化設定'),
                subtitle: const Text('設為「無限制」'),
                onTap: () {
                  Navigator.pop(context);
                  _openBatteryOptimizationSettings();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Colors.blue),
                title: const Text('應用程式詳細資訊'),
                subtitle: const Text('查看所有權限設定'),
                onTap: () {
                  Navigator.pop(context);
                  _openAppSettings();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 打開精確鬧鐘設定頁面（Android 12+）
  static Future<void> _openExactAlarmSettings() async {
    try {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        package: 'com.example.timed_messenger', // 請替換為您的 package name
      );
      await intent.launch();
      print('✅ 已打開精確鬧鐘設定頁面');
    } catch (e) {
      print('⚠️ 無法打開精確鬧鐘設定，嘗試打開應用設定: $e');
      await _openAppSettings();
    }
  }

  /// 打開電池優化設定頁面
  static Future<void> _openBatteryOptimizationSettings() async {
    try {
      final intent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await intent.launch();
      print('✅ 已打開電池優化設定頁面');
    } catch (e) {
      print('⚠️ 無法打開電池優化設定: $e');
      await _openAppSettings();
    }
  }

  /// 打開應用程式設定頁面
  static Future<void> _openAppSettings() async {
    try {
      await openAppSettings();
      print('✅ 已打開應用程式設定');
    } catch (e) {
      print('❌ 無法打開應用程式設定: $e');
    }
  }

  /// 檢查並請求通知權限
  static Future<bool> checkAndRequestNotificationPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) {
      print('✅ 通知權限已授權');
      return true;
    }

    final result = await Permission.notification.request();
    if (result.isGranted) {
      print('✅ 通知權限已授權');
      return true;
    } else {
      print('⚠️ 通知權限被拒絕');
      return false;
    }
  }

  /// 檢查精確鬧鐘權限（Android 12+）
  static Future<bool> checkScheduleExactAlarmPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isGranted) {
        print('✅ 精確鬧鐘權限已授權');
        return true;
      } else {
        print('⚠️ 精確鬧鐘權限未授權，請手動開啟');
        return false;
      }
    } catch (e) {
      print('⚠️ 無法檢查精確鬧鐘權限（可能是舊版 Android）: $e');
      return true;
    }
  }

  /// 完整權限檢查與引導流程
  static Future<void> performPermissionCheck(BuildContext context) async {
    if (!Platform.isAndroid) return;

    // 1. 檢查是否需要顯示引導
    final shouldShow = await shouldShowGuide();
    if (!shouldShow) {
      print('ℹ️ 權限引導已顯示過，跳過');
      return;
    }

    // 2. 延遲一點再顯示（避免與其他初始化衝突）
    await Future.delayed(const Duration(seconds: 1));

    // 3. 顯示引導對話框
    if (context.mounted) {
      await showPermissionGuideDialog(context);
    }

    // 4. 檢查並請求基本權限
    await checkAndRequestNotificationPermission();
    await checkScheduleExactAlarmPermission();
  }
}
