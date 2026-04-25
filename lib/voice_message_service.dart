import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';

class VoiceMessageService {
  static final AudioRecorder _recorder = AudioRecorder();
  static final AudioPlayer _player = AudioPlayer();
  static bool isRecording = false;
  static bool isPlaying = false;
  static String? currentRecordingPath;

  /// 開始錄音
  static Future<bool> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) return false;

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      isRecording = true;
      currentRecordingPath = path;
      return true;
    } catch (e) {
      debugPrint('錄音開始失敗: $e');
      return false;
    }
  }

  /// 停止錄音，回傳檔案路徑
  static Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      isRecording = false;
      return path;
    } catch (e) {
      debugPrint('錄音停止失敗: $e');
      isRecording = false;
      return null;
    }
  }

  /// 播放本地語音檔
  static Future<void> playLocalAudio(String path) async {
    try {
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      isPlaying = true;
      _player.onPlayerComplete.listen((_) => isPlaying = false);
    } catch (e) {
      debugPrint('播放失敗: $e');
    }
  }

  /// 播放網路語音（從 Firebase Storage URL）
  static Future<void> playRemoteAudio(String url) async {
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
      isPlaying = true;
      _player.onPlayerComplete.listen((_) => isPlaying = false);
    } catch (e) {
      debugPrint('網路播放失敗: $e');
    }
  }

  /// 停止播放
  static Future<void> stopPlaying() async {
    await _player.stop();
    isPlaying = false;
  }

  /// 上傳語音到 Firebase Storage，回傳下載網址
  static Future<String?> uploadVoice(String localPath) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final file = File(localPath);
      final fileName =
          'voice_${user.uid}_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final ref =
          FirebaseStorage.instance.ref().child('voice_messages/$fileName');

      final uploadTask = await ref.putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('上傳語音失敗: $e');
      return null;
    }
  }

  /// 釋放資源
  static void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
