import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'modules/messaging/services/messaging_service.dart';

/// ✅ 收件匣頁面 - 顯示收到的訊息
class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<Map<String, dynamic>> _inboxMessages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInboxMessages();
  }

  Future<void> _loadInboxMessages() async {
    setState(() => _isLoading = true);
    try {
      final messages = await MessagingService.getInboxMessages();
      setState(() {
        _inboxMessages = messages;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ 載入收件匣失敗: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String firestoreId, int index) async {
    await MessagingService.markMessageAsRead(firestoreId);
    setState(() {
      _inboxMessages[index]['status'] = 'read';
    });
  }

  void _showMessageDetail(Map<String, dynamic> message, int index) {
    final firestoreId = message['firestore_id'] as String;
    final status = message['status'] as String? ?? 'scheduled';
    
    // 如果是未讀，標記為已讀
    if (status != 'read') {
      _markAsRead(firestoreId, index);
    }

    // 顯示訊息詳情對話框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mail, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '來自 ${message['senderName'] ?? '未知寄件人'}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 訊息內容
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  message['message'] ?? '',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              // 時間資訊
              Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '排程時間：${_formatTimestamp(message['time'])}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '建立時間：${_formatTimestamp(message['created_at'])}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '未知';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy/MM/dd HH:mm').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('yyyy/MM/dd HH:mm').format(timestamp);
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收件匣'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInboxMessages,
            tooltip: '重新整理',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _inboxMessages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('收件匣是空的', style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInboxMessages,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _inboxMessages.length,
                    itemBuilder: (context, index) {
                      final message = _inboxMessages[index];
                      final status = message['status'] as String? ?? 'scheduled';
                      final isUnread = status != 'read';

                      return Card(
                        color: isUnread ? Colors.blue.shade50 : Colors.white,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isUnread ? Colors.blue : Colors.grey,
                            child: Icon(
                              isUnread ? Icons.mail : Icons.mail_outline,
                              color: Colors.white,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  message['senderName'] ?? '未知寄件人',
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '未讀',
                                    style: TextStyle(color: Colors.white, fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message['message'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTimestamp(message['time']),
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _showMessageDetail(message, index),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// ✅ 未讀 Badge Widget - 顯示未讀數量
class UnreadBadge extends StatelessWidget {
  final int count;
  final Widget child;

  const UnreadBadge({
    super.key,
    required this.count,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -6,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
