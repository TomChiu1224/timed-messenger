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
  static final AudioPlayer _audioPlayer = AudioPlayer();

  // 可用的系統音效選項
  static const List<SoundOption> _systemSounds = [
    SoundOption(
      id: 'notification',
      name: '預設通知音',
      type: 'system',
      path: 'notification',
      description: '系統預設的通知聲音',
    ),
    SoundOption(
      id: 'alarm',
      name: '鬧鐘聲',
      type: 'system',
      path: 'alarm',
      description: '響亮的鬧鐘聲音',
    ),
    SoundOption(
      id: 'ringtone',
      name: '來電鈴聲',
      type: 'system',
      path: 'ringtone',
      description: '手機來電鈴聲',
    ),
    SoundOption(
      id: 'message',
      name: '訊息提示音',
      type: 'system',
      path: 'message',
      description: '簡短的訊息提示音',
    ),
    SoundOption(
      id: 'beep',
      name: '嗶嗶聲',
      type: 'system',
      path: 'beep',
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

  /// 播放指定的音效
  static Future<void> playSound({
    required String soundId,
    double volume = 0.8,
    int repeat = 1,
  }) async {
    try {
      final soundOption = getSoundById(soundId);
      if (soundOption == null) {
        print('❌ 找不到音效: $soundId');
        return;
      }

      await _audioPlayer.setVolume(volume);

      if (soundOption.type == 'system') {
        await _playSystemSound(soundOption.path, repeat);
      } else {
        await _playCustomSound(soundOption.path, repeat);
      }

      print('✅ 音效播放成功: ${soundOption.name}');
    } catch (e) {
      print('❌ 音效播放失敗: $e');
      await _playSystemBeep();
    }
  }

  /// 播放系統音效
  static Future<void> _playSystemSound(String soundName, int repeat) async {
    for (int i = 0; i < repeat; i++) {
      await SystemSound.play(SystemSoundType.alert);
      if (i < repeat - 1) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  /// 播放自訂音效檔案
  static Future<void> _playCustomSound(String soundPath, int repeat) async {
    for (int i = 0; i < repeat; i++) {
      await _audioPlayer.play(AssetSource(soundPath));
      if (i < repeat - 1) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// 備援：播放系統嗶聲
  static Future<void> _playSystemBeep() async {
    await SystemSound.play(SystemSoundType.alert);
  }

  /// 預覽音效（用於設定時試聽）
  static Future<void> previewSound(String soundId) async {
    await playSound(soundId: soundId, volume: 0.6, repeat: 1);
  }

  /// 停止當前播放的音效
  static Future<void> stopSound() async {
    await _audioPlayer.stop();
  }

  /// 釋放音效播放器資源
  static Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}