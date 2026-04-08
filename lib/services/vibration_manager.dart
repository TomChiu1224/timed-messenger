// ✅ 震動功能管理器（從 main.dart 抽取的獨立模組）
import 'package:vibration/vibration.dart';
import 'notification_manager.dart';

// ✅ 震動選項資料模型
class VibrationOption {
  final String id;           // 震動模式識別碼
  final String name;         // 顯示名稱
  final String description;  // 震動描述
  final List<int> pattern;   // 震動模式（毫秒陣列）

  const VibrationOption({
    required this.id,
    required this.name,
    required this.description,
    required this.pattern,
  });
}

// ✅ 震動管理器類別
class VibrationManager {
  // 可用的震動模式選項
  static const List<VibrationOption> _vibrationPatterns = [
    VibrationOption(
      id: 'short',
      name: '短震動',
      description: '簡短的單次震動',
      pattern: [100], // 100ms震動
    ),
    VibrationOption(
      id: 'long',
      name: '長震動',
      description: '較長的單次震動',
      pattern: [500], // 500ms震動
    ),
    VibrationOption(
      id: 'double',
      name: '雙震動',
      description: '兩次短震動',
      pattern: [100, 200, 100], // 震動-停-震動
    ),
    VibrationOption(
      id: 'pulse',
      name: '脈衝震動',
      description: '三次連續短震動',
      pattern: [100, 100, 100, 100, 100], // 震動-停-震動-停-震動
    ),
    VibrationOption(
      id: 'heartbeat',
      name: '心跳震動',
      description: '模擬心跳的震動模式',
      pattern: [200, 100, 100, 300], // 長震-短停-短震-長停
    ),
  ];

  /// 取得所有可用的震動模式
  static List<VibrationOption> getAllVibrationPatterns() {
    return List.from(_vibrationPatterns);
  }

  /// 根據ID找到震動模式
  static VibrationOption? getVibrationPatternById(String id) {
    try {
      return _vibrationPatterns.firstWhere((pattern) => pattern.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 播放指定的震動模式
  static Future<void> playVibration({
    required String patternId,
    double intensity = 0.8,
    int repeat = 1,
  }) async {
    try {
      // 檢查設備是否支援震動
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator != true) {
        print('❌ 設備不支援震動功能');
        return;
      }

      final vibrationOption = getVibrationPatternById(patternId);
      if (vibrationOption == null) {
        print('❌ 找不到震動模式: $patternId');
        return;
      }

      // 檢查是否支援自訂震動模式
      final hasCustomVibrationsSupport = await Vibration.hasCustomVibrationsSupport();

      for (int i = 0; i < repeat; i++) {
        if (hasCustomVibrationsSupport == true) {
          // 使用自訂震動模式
          await _playCustomVibration(vibrationOption.pattern, intensity);
        } else {
          // 使用基礎震動
          await _playBasicVibration(vibrationOption);
        }

        // 如果需要重複，添加間隔
        if (i < repeat - 1) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      print('✅ 震動播放成功: ${vibrationOption.name}');
    } catch (e) {
      print('❌ 震動播放失敗: $e');
      // 備援：使用基礎震動
      await _playFallbackVibration();
    }
  }

  /// 播放自訂震動模式
  static Future<void> _playCustomVibration(List<int> pattern, double intensity) async {
    // 根據強度調整震動模式
    final adjustedPattern = pattern.map((duration) =>
        (duration * intensity).round()).toList();

    await Vibration.vibrate(pattern: adjustedPattern);
  }

  /// 播放基礎震動（不支援自訂模式的設備）
  static Future<void> _playBasicVibration(VibrationOption option) async {
    switch (option.id) {
      case 'short':
        await Vibration.vibrate(duration: 100);
        break;
      case 'long':
        await Vibration.vibrate(duration: 500);
        break;
      case 'double':
        await Vibration.vibrate(duration: 100);
        await Future.delayed(const Duration(milliseconds: 200));
        await Vibration.vibrate(duration: 100);
        break;
      case 'pulse':
      case 'heartbeat':
      // 複雜模式簡化為三次短震動
        for (int i = 0; i < 3; i++) {
          await Vibration.vibrate(duration: 100);
          if (i < 2) await Future.delayed(const Duration(milliseconds: 100));
        }
        break;
      default:
        await Vibration.vibrate(duration: 100);
    }
  }

  /// 備援震動
  static Future<void> _playFallbackVibration() async {
    try {
      await Vibration.vibrate(duration: 200);
    } catch (e) {
      print('❌ 備援震動也失敗: $e');
    }
  }

  /// 預覽震動（用於設定時試用）
  /// 使用 NotificationManager 發送通知並震動，提供更好的預覽體驗
  static Future<void> previewVibration(String patternId) async {
    try {
      final vibrationOption = getVibrationPatternById(patternId);
      if (vibrationOption == null) {
        print('❌ 找不到震動模式: $patternId');
        return;
      }

      // 使用 NotificationManager 來預覽震動，這樣可以發送通知並震動
      // 將震動模式轉換為可用的格式（添加前置延遲 0）
      final pattern = [0, ...vibrationOption.pattern];
      await notificationManager.previewVibration(
        pattern,
        patternName: vibrationOption.name,
      );
      print('✅ 震動預覽成功: ${vibrationOption.name}');
    } catch (e) {
      print('❌ 震動預覽失敗，使用備援方案: $e');
      // 備援：使用原本的方法
      await playVibration(
        patternId: patternId,
        intensity: 0.6,
        repeat: 1,
      );
    }
  }

  /// 停止當前震動
  static Future<void> stopVibration() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      print('❌ 停止震動失敗: $e');
    }
  }

  /// 檢查設備震動支援狀態
  static Future<Map<String, bool>> getVibrationSupport() async {
    return {
      'hasVibrator': await Vibration.hasVibrator() ?? false,
      'hasAmplitudeControl': await Vibration.hasAmplitudeControl() ?? false,
      'hasCustomVibrationsSupport': await Vibration.hasCustomVibrationsSupport() ?? false,
    };
  }
}