import 'scheduled_message.dart';

// ✅ 音效設定資料模型
class SoundSettings {
  bool enabled;
  String soundId;
  double volume;
  int repeat;

  SoundSettings({
    this.enabled = true,
    this.soundId = 'notification',
    this.volume = 0.8,
    this.repeat = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'sound_enabled': enabled ? 1 : 0,
      'sound_type': 'system',
      'sound_path': soundId,
      'sound_volume': volume,
      'sound_repeat': repeat,
    };
  }

  static SoundSettings fromScheduledMessage(ScheduledMessage msg) {
    return SoundSettings(
      enabled: msg.soundEnabled,
      soundId: msg.soundPath,
      volume: msg.soundVolume,
      repeat: msg.soundRepeat,
    );
  }
}
