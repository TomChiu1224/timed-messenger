// ========== 音效管理服務 ==========
// 這個檔案負責處理所有音效相關功能
// 使用 Flutter 內建 SystemSound，無需外部依賴

import 'package:flutter/services.dart';
import 'notification_manager.dart';

/// ✅ 音效選項資料模型
class SoundOption {
  final String id;           // 音效識別碼
  final String name;         // 顯示名稱
  final String type;         // 類型：'system' 或 'custom'
  final String path;         // 音效路徑或系統音效名稱
  final String description;  // 音效描述

  const SoundOption({
    required this.id,
    required this.name,
    required this.type,
    required this.path,
    required this.description,
  });
}

/// ✅ 音效管理器類別 - 負責所有音效相關功能
class AudioManager {
  // 可用的系統音效選項（使用 Flutter 內建音效）
  static const List<SoundOption> _systemSounds = [
    SoundOption(
      id: 'notification',
      name: '通知音',
      type: 'system',
      path: 'SystemSoundType.alert',
      description: '預設的通知聲音',
    ),
    SoundOption(
      id: 'alert',
      name: '系統提示音',
      type: 'system',
      path: 'SystemSoundType.alert',
      description: '系統內建的提示聲音',
    ),
    SoundOption(
      id: 'click',
      name: '點擊音',
      type: 'system',
      path: 'SystemSoundType.click',
      description: '系統內建的點擊聲音',
    ),
  ];

  /// 取得所有可用的音效選項
  static List<SoundOption> getAllSounds() {
    List<SoundOption> allSounds = [];
    allSounds.addAll(_systemSounds);
    return allSounds;
  }

  /// 根據ID找到音效選項
  static SoundOption? getSoundById(String id) {
    try {
      return getAllSounds().firstWhere((sound) => sound.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 播放指定的音效 - 使用 Flutter 內建 SystemSound
  static Future<void> playSound({
    required String soundId,
    double volume = 0.8,  // SystemSound 不支援音量調整，保留參數以維持 API 兼容性
    int repeat = 1,
  }) async {
    try {
      // 根據 soundId 選擇對應的系統音效
      final SystemSoundType soundType;
      if (soundId == 'click') {
        soundType = SystemSoundType.click;
      } else {
        // 預設使用 alert（適合 notification、alert 等場景）
        soundType = SystemSoundType.alert;
      }

      // 播放指定次數
      for (int i = 0; i < repeat; i++) {
        await SystemSound.play(soundType);

        if (i < repeat - 1) {
          // 兩次播放之間稍微等待
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      print('✅ 音效播放成功: $soundId');
    } catch (e) {
      print('❌ 音效播放失敗: $e');
    }
  }

  /// 預覽音效（用於設定時試聽）
  /// 使用 NotificationManager 發送通知來預覽音效，讓每種音效使用不同的頻道
  static Future<void> previewSound(String soundId) async {
    try {
      // 使用 NotificationManager 來預覽音效，這樣可以使用不同的通知頻道
      await notificationManager.previewSound(soundId);
      print('✅ 音效預覽成功: $soundId');
    } catch (e) {
      print('❌ 音效預覽失敗，使用備援方案: $e');
      // 備援：使用 SystemSound
      await playSound(soundId: soundId, repeat: 1);
    }
  }

  /// 停止當前播放的音效（SystemSound 不支援停止，保留空方法以維持 API 兼容性）
  static Future<void> stopSound() async {
    // SystemSound 播放時間極短，無需停止功能
    print('ℹ️ SystemSound 無需停止（播放時間極短）');
  }

  /// 釋放音效播放器資源（SystemSound 不需要釋放，保留空方法以維持 API 兼容性）
  static Future<void> dispose() async {
    // SystemSound 無需手動釋放資源
    print('ℹ️ SystemSound 無需釋放資源');
  }
}