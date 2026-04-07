import 'scheduled_message.dart';

class VibrationSettings {
  bool enabled;
  String patternId;
  double intensity;
  int repeat;

  VibrationSettings({
    this.enabled = true,
    this.patternId = 'short',
    this.intensity = 0.8,
    this.repeat = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'vibration_enabled': enabled ? 1 : 0,
      'vibration_pattern': patternId,
      'vibration_intensity': intensity,
      'vibration_repeat': repeat,
    };
  }

  static VibrationSettings fromScheduledMessage(ScheduledMessage msg) {
    return VibrationSettings(
      enabled: msg.vibrationEnabled,
      patternId: msg.vibrationPattern,
      intensity: msg.vibrationIntensity,
      repeat: msg.vibrationRepeat,
    );
  }
}
