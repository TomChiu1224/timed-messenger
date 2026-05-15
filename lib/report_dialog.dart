import 'package:flutter/material.dart';
import 'services/report_service.dart';

/// 檢舉使用者對話框
///
/// 使用方式：
/// ```dart
/// final result = await showReportDialog(
///   context: context,
///   reportedUid: 'xxx',
///   reportedEmail: 'xxx@example.com',
///   source: 'friends_list', // 或 'message_detail'
///   messageId: null, // 從訊息詳情頁檢舉時填入訊息 ID
/// );
/// ```
Future<bool?> showReportDialog({
  required BuildContext context,
  required String reportedUid,
  required String reportedEmail,
  required String source,
  String? messageId,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _ReportDialogContent(
      reportedUid: reportedUid,
      reportedEmail: reportedEmail,
      source: source,
      messageId: messageId,
    ),
  );
}

class _ReportDialogContent extends StatefulWidget {
  final String reportedUid;
  final String reportedEmail;
  final String source;
  final String? messageId;

  const _ReportDialogContent({
    required this.reportedUid,
    required this.reportedEmail,
    required this.source,
    this.messageId,
  });

  @override
  State<_ReportDialogContent> createState() => _ReportDialogContentState();
}

class _ReportDialogContentState extends State<_ReportDialogContent> {
  String? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請選擇檢舉理由')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ReportService().submitReport(
      reportedUid: widget.reportedUid,
      reportedEmail: widget.reportedEmail,
      reason: _selectedReason!,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      source: widget.source,
      messageId: widget.messageId,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('檢舉已送出'),
          content: const Text('感謝您的檢舉，我們會儘速審查。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('確定'),
            ),
          ],
        ),
      );
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('檢舉失敗，可能您 24 小時內已檢舉過此使用者，或網路連線異常。'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('檢舉使用者'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '請選擇檢舉理由：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...ReportService.reasonLabels.entries.map(
              (entry) => RadioListTile<String>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: _selectedReason,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() => _selectedReason = value);
                      },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '額外備註（選填）：',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 500,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                hintText: '可補充說明檢舉原因（最多 500 字）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('送出檢舉'),
        ),
      ],
    );
  }
}
