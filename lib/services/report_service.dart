import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

/// 檢舉服務：處理使用者檢舉相關邏輯
class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;

  /// 檢舉理由的內部值與顯示文字對照
  static const Map<String, String> reasonLabels = {
    'harassment': '騷擾或霸凌',
    'spam': '垃圾訊息或廣告',
    'inappropriate': '不當內容（暴力、色情等）',
    'scam': '詐騙或假冒身份',
    'other': '其他',
  };

  /// 提交檢舉
  ///
  /// 參數：
  /// - [reportedUid]: 被檢舉者的 UID
  /// - [reportedEmail]: 被檢舉者的 email
  /// - [reason]: 檢舉理由的內部值（reasonLabels 的 key）
  /// - [note]: 額外備註（可空）
  /// - [source]: 入口來源："friends_list" 或 "message_detail"
  /// - [messageId]: 被檢舉的訊息 ID（從訊息詳情頁檢舉時才有，可空）
  ///
  /// 回傳：成功 true，失敗 false
  Future<bool> submitReport({
    required String reportedUid,
    required String reportedEmail,
    required String reason,
    String? note,
    required String source,
    String? messageId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('[ReportService] 未登入，無法檢舉');
        return false;
      }

      // 檢查是否在 24 小時內已檢舉過同一個人
      final hasRecentReport = await _hasRecentReport(
        reporterUid: currentUser.uid,
        reportedUid: reportedUid,
      );
      if (hasRecentReport) {
        print('[ReportService] 24 小時內已檢舉過此使用者');
        return false;
      }

      // 寫入 Firestore
      await _firestore.collection('reports').add({
        'reporterUid': currentUser.uid,
        'reporterEmail': currentUser.email ?? '',
        'reportedUid': reportedUid,
        'reportedEmail': reportedEmail,
        'reason': reason,
        'note': note ?? '',
        'source': source,
        'messageId': messageId ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('[ReportService] 檢舉提交成功');
      return true;
    } catch (e) {
      print('[ReportService] 檢舉提交失敗: $e');
      return false;
    }
  }

  /// 檢查 24 小時內是否已檢舉過同一人（防止濫用）
  Future<bool> _hasRecentReport({
    required String reporterUid,
    required String reportedUid,
  }) async {
    try {
      final oneDayAgo = DateTime.now().subtract(const Duration(hours: 24));
      final snapshot = await _firestore
          .collection('reports')
          .where('reporterUid', isEqualTo: reporterUid)
          .where('reportedUid', isEqualTo: reportedUid)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneDayAgo))
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('[ReportService] 檢查重複檢舉失敗: $e');
      // 失敗時保守處理：允許檢舉（避免因為網路問題擋住合法檢舉）
      return false;
    }
  }
}
