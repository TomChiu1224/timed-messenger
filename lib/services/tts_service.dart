import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class TtsService {
  static final FlutterTts _tts = FlutterTts();
  static bool _isInitialized = false;

  /// 初始化 TTS
  static Future<void> initialize() async {
    if (_isInitialized) return;
    await _tts.setLanguage('zh-TW');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _isInitialized = true;
    print('✅ TTS 初始化完成');
  }

  /// 朗讀文字
  static Future<void> speak(String text) async {
    await initialize();
    await _tts.stop();
    await _tts.speak(text);
    print('🗣️ TTS 朗讀：$text');
  }

  /// 停止朗讀
  static Future<void> stop() async {
    await _tts.stop();
  }

  /// 取得用戶的文字訊息接收偏好
  /// 回傳值：'notify'（通知）、'tts'（朗讀）、'silent'（靜音）
  static Future<String> getTextMessageMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('text_message_mode') ?? 'notify';
  }

  /// 取得用戶的語音訊息接收偏好
  /// 回傳值：'notify'（通知）、'autoplay'（自動播放）、'silent'（靜音）
  static Future<String> getVoiceMessageMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('voice_message_mode') ?? 'notify';
  }

  /// 是否跟隨手機靜音設定
  static Future<bool> getFollowSilentMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('follow_silent_mode') ?? true;
  }
}
