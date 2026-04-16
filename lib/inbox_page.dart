import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'firebase_service.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    final msgs = await _firebaseService.getReceivedMessages();
    setState(() {
      _messages = msgs;
      _isLoading = false;
    });
  }

  String _formatTime(dynamic scheduledTime) {
    if (scheduledTime == null) return '未知時間';
    try {
      DateTime dt;
      if (scheduledTime is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(scheduledTime);
      } else {
        dt = (scheduledTime as dynamic).toDate();
      }
      return DateFormat('yyyy/MM/dd HH:mm').format(dt.toLocal());
    } catch (e) {
      return '時間格式錯誤';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'read':
        return Colors.grey;
      case 'triggered':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _statusText(String? status) {
    switch (status) {
      case 'read':
        return '已讀';
      case 'triggered':
        return '已觸發';
      default:
        return '已設定';
    }
  }

  void _confirmDelete(Map<String, dynamic> msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除訊息'),
        content: Text('確定要刪除「${msg['message'] ?? '此訊息'}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final docId = msg['docId'] as String?;
              if (docId != null) {
                await _firebaseService.deleteReceivedMessage(docId);
                setState(() => _messages.remove(msg));
              }
            },
            child: const Text('刪除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openMessage(Map<String, dynamic> msg) async {
    final docId = msg['docId'] as String?;
    if (docId != null && msg['status'] != 'read') {
      await _firebaseService.markMessageAsRead(docId);
      setState(() => msg['status'] = 'read');
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('來自 ${msg['senderName'] ?? '未知用戶'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg['message'] ?? '（無內容）',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            Text('排程時間：${_formatTime(msg['scheduledTime'])}',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收件匣'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: '重新整理',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('目前沒有收到任何訊息',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMessages,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUnread = msg['status'] != 'read';
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                _statusColor(msg['status'] as String?),
                            child: Icon(
                              isUnread ? Icons.mail : Icons.mail_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            msg['message'] ?? '（無內容）',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isUnread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '來自：${msg['senderName'] ?? '未知'}  ·  ${_formatTime(msg['scheduledTime'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(msg['status'] as String?)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _statusText(msg['status'] as String?),
                              style: TextStyle(
                                color: _statusColor(msg['status'] as String?),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () => _openMessage(msg),
                          onLongPress: () => _confirmDelete(msg),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
