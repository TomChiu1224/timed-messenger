import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageMessageService {
  static final ImagePicker _picker = ImagePicker();

  /// 從相簿選擇圖片
  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      debugPrint('❌ 選擇圖片失敗: $e');
      return null;
    }
  }

  /// 用相機拍照
  static Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image == null) return null;
      return File(image.path);
    } catch (e) {
      debugPrint('❌ 拍照失敗: $e');
      return null;
    }
  }

  /// 上傳圖片到 Firebase Storage
  static Future<String?> uploadImage(File imageFile) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${uid.substring(0, 8)}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('message_images')
          .child(uid)
          .child(fileName);
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('✅ 圖片上傳成功: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('❌ 圖片上傳失敗: $e');
      return null;
    }
  }

  /// 顯示選擇來源對話框
  static Future<File?> showImageSourceDialog(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.purple),
              title: const Text('從相簿選擇'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.purple),
              title: const Text('用相機拍照'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
          ],
        ),
      ),
    );
    if (result == 'gallery') return await pickImageFromGallery();
    if (result == 'camera') return await pickImageFromCamera();
    return null;
  }
}
