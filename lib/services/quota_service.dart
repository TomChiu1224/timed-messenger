import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuotaService {
  static const Map<String, int> _monthlyLimits = {
    'free': 10,
    'lite': 50,
    'plus': 200,
    'pro': 500,
  };

  static String _getMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
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

  static Future<int> getMonthlyLimit() async {
    final tier = await getUserTier();
    return _monthlyLimits[tier] ?? 10;
  }

  static Future<int> getMonthUsage() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 0;
      final monthKey = _getMonthKey();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quota')
          .doc(monthKey)
          .get();
      return doc.data()?['count'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  static Future<bool> canSendMessage() async {
    final usage = await getMonthUsage();
    final limit = await getMonthlyLimit();
    return usage < limit;
  }

  static Future<void> incrementUsage() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final monthKey = _getMonthKey();
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('quota')
          .doc(monthKey);
      await ref.set({
        'count': FieldValue.increment(1),
        'date': monthKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ 額度更新失敗: $e');
    }
  }

  static Future<Map<String, dynamic>> getQuotaInfo() async {
    final usage = await getMonthUsage();
    final limit = await getMonthlyLimit();
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
