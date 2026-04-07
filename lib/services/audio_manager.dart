// ========== 音效管理服務 ==========
// 這個檔案負責處理所有音效相關功能
// 從原本的 main.dart 抽取出來，保持功能完全相同

import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

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
  // 音效播放器實例（靜態共用）
  static final AudioPlayer _player = AudioPlayer();
  static bool _isPlaying = false;

  // 可用的系統音效選項（對應 assets/sounds/ 中的檔案）
  static const List<SoundOption> _systemSounds = [
    SoundOption(
      id: 'notification',
      name: '預設通知音',
      type: 'system',
      path: 'assets/sounds/notification.mp3',
      description: '系統預設的通知聲音',
    ),
    SoundOption(
      id: 'alarm',
      name: '鬧鐘聲',
      type: 'system',
      path: 'assets/sounds/alarm.mp3',
      description: '響亮的鬧鐘聲音',
    ),
    SoundOption(
      id: 'ringtone',
      name: '來電鈴聲',
      type: 'system',
      path: 'assets/sounds/ringtone.mp3',
      description: '手機來電鈴聲',
    ),
    SoundOption(
      id: 'message',
      name: '訊息提示音',
      type: 'system',
      path: 'assets/sounds/message.mp3',
      description: '簡短的訊息提示音',
    ),
    SoundOption(
      id: 'beep',
      name: '嗶嗶聲',
      type: 'system',
      path: 'assets/sounds/beep.mp3',
      description: '簡單的嗶嗶提示音',
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

  /// 播放指定的音效 - 使用 audioplayers 播放真實音效
  static Future<void> playSound({
    required String soundId,
    double volume = 0.8,
    int repeat = 1,
  }) async {
    try {
      // 根據 soundId 找到對應的音效檔案
      final soundOption = getSoundById(soundId);
      if (soundOption == null) {
        print('❌ 找不到音效: $soundId，使用預設音效');
        await SystemSound.play(SystemSoundType.alert);
        return;
      }

      // 設定音量（0.0 到 1.0）
      await _player.setVolume(volume);

      // 播放指定次數
      for (int i = 0; i < repeat; i++) {
        _isPlaying = true;

        // 播放音效檔案
        await _player.play(AssetSource(soundOption.path.replaceFirst('assets/', '')));

        // 等待播放完成
        await _player.onPlayerComplete.first;

        if (i < repeat - 1) {
          // 兩次播放之間稍微等待
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      _isPlaying = false;
      print('✅ 音效播放成功: ${soundOption.name} (${soundOption.path})');
    } catch (e) {
      _isPlaying = false;
      print('❌ 音效播放失敗: $e');
      // 備援：使用系統預設提示音
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (fallbackError) {
        print('❌ 備援音效也失敗: $fallbackError');
      }
    }
  }

  /// 預覽音效（用於設定時試聽）
  static Future<void> previewSound(String soundId) async {
    await playSound(soundId: soundId, volume: 0.6, repeat: 1);
  }

  /// 停止當前播放的音效
  static Future<void> stopSound() async {
    try {
      if (_isPlaying) {
        await _player.stop();
        _isPlaying = false;
        print('✅ 音效已停止');
      }
    } catch (e) {
      print('❌ 停止音效失敗: $e');
    }
  }

  /// 釋放音效播放器資源
  static Future<void> dispose() async {
    try {
      await _player.dispose();
      _isPlaying = false;
      print('✅ 音效播放器資源已釋放');
    } catch (e) {
      print('❌ 釋放資源失敗: $e');
    }
  }
}