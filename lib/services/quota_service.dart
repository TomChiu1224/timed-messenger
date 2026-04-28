import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuotaService {
  static const Map<String, int> _dailyLimits = {
    'free': 6,
    'lite': 20,
    'plus': 50,
    'pro': 80,
  };

  static String _getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static Future<String> getUserTier() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 'free';
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data()?['subscriptionTier'] ?? 'free';
    } catch (e) {
      return 'free';
    }
  }

  static Future<int> getDailyLimit() async {
    final tier = await getUserTier();
    return _dailyLimits[tier] ?? 6;
  }

  static Future<int> getTodayUsage() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 0;
      final todayKey = _getTodayKey();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quota')
          .doc(todayKey)
          .get();
      return doc.data()?['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> canSendMessage() async {
    final usage = await getTodayUsage();
    final limit = await getDailyLimit();
    return usage < limit;
  }

  static Future<void> incrementUsage() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final todayKey = _getTodayKey();
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quota')
          .doc(todayKey);
      await ref.set({
        'count': FieldValue.increment(1),
        'date': todayKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ 額度更新失敗: $e');
    }
  }

  static Future<Map<String, dynamic>> getQuotaInfo() async {
    final usage = await getTodayUsage();
    final limit = await getDailyLimit();
    final tier = await getUserTier();
    return {
      'usage': usage,
      'limit': limit,
      'tier': tier,
      'remaining': limit - usage,
      'canSend': usage < limit,
    };
  }
}
