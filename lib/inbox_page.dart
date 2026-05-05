import 'services/theme_manager.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'voice_message_service.dart';
import 'services/theme_manager.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage>
    with SingleTickerProviderStateMixin {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _sentMessages = [];
  bool _isLoading = true;
  late TabController _tabController;
  StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _startListeningMessages();
    _loadSentMessages();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSentMessages() async {
    try {
      final user = FirebaseService().currentUser;
      if (user == null) return;
      final snapshot = await FirebaseFirestore.instance
          .collection('scheduled_messages')
          .where('senderId', isEqualTo: user.uid)
          .get();
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
      list.sort((a, b) {
        final aTime = a['scheduledTime'] ?? 0;
        final bTime = b['scheduledTime'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });
      if (mounted) {
        setState(() {
          _sentMessages = list;
        });
      }
    } catch (e) {
      print('❌ 載入已發送失敗：$e');
    }
  }

  void _startListeningMessages() {
    final user = FirebaseService().currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    _messagesSubscription = FirebaseFirestore.instance
        .collection('scheduled_messages')
        .where('receiverId', isEqualTo: user.uid)
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        data['docId'] = doc.id;
        return data;
      }).toList();
      list.sort((a, b) {
        final aTime = a['scheduledTime'] ?? 0;
        final bTime = b['scheduledTime'] ?? 0;
        return (bTime as int).compareTo(aTime as int);
      });
      if (mounted) {
        setState(() {
          _messages = list;
          _isLoading = false;
        });
      }
    });
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

  void _openSentMessage(Map<String, dynamic> msg) {
    final isImage = msg['messageType'] == 'image';
    final imageUrl = msg['imageUrl'] as String?;
    final isVoice = msg['messageType'] == 'voice';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('傳給 ${msg['receiverName'] ?? '未知用戶'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage && imageUrl != null) ...[
              const Text('🖼️ 圖片訊息', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.black,
                      child: InteractiveViewer(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stack) => const SizedBox(
                      height: 100,
                      child: Center(
                        child: Icon(Icons.broken_image,
                            size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text('點擊圖片可放大',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ] else if (isVoice) ...[
              const Text('🎙️ 語音訊息', style: TextStyle(fontSize: 16)),
            ] else ...[
              Text(msg['message'] ?? '（無內容）',
                  style: const TextStyle(fontSize: 16)),
            ],
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

  void _openMessage(Map<String, dynamic> msg) async {
    final docId = msg['docId'] as String?;
    if (docId != null && msg['status'] != 'read') {
      await _firebaseService.markMessageAsRead(docId);
      setState(() => msg['status'] = 'read');
    }

    if (!mounted) return;

    final isVoice = msg['messageType'] == 'voice';
    final voiceUrl = msg['voiceUrl'] as String?;
    final isImage = msg['messageType'] == 'image';
    final imageUrl = msg['imageUrl'] as String?;

    showDialog(
      context: context,
      builder: (context) {
        bool _isPlaying = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('來自 ${msg['senderName'] ?? '未知用戶'}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isVoice && voiceUrl != null) ...[
                  const Text('🎙️ 語音訊息', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  Center(
                    child: ElevatedButton.icon(
                      icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(_isPlaying ? '停止播放' : '播放語音'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(
                            ThemeManager().currentColors['primary'] as int),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        if (_isPlaying) {
                          await VoiceMessageService.stopPlaying();
                          setDialogState(() => _isPlaying = false);
                        } else {
                          setDialogState(() => _isPlaying = true);
                          await VoiceMessageService.playRemoteAudio(voiceUrl);
                          setDialogState(() => _isPlaying = false);
                        }
                      },
                    ),
                  ),
                ] else if (isImage && imageUrl != null) ...[
                  const Text('🖼️ 圖片訊息', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.black,
                          child: InteractiveViewer(
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 200,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stack) => const SizedBox(
                          height: 100,
                          child: Center(
                            child: Icon(Icons.broken_image,
                                size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('點擊圖片可放大',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ] else ...[
                  Text(msg['message'] ?? '（無內容）',
                      style: const TextStyle(fontSize: 16)),
                ],
                const SizedBox(height: 12),
                Text('排程時間：${_formatTime(msg['scheduledTime'])}',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  VoiceMessageService.stopPlaying();
                  Navigator.pop(context);
                },
                child: const Text('關閉'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收件匣'),
        backgroundColor: ThemeManager().currentColors['primary'],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadMessages();
              _loadSentMessages();
            },
            tooltip: '重新整理',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.inbox), text: '收到'),
            Tab(icon: Icon(Icons.send), text: '已發送'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ===== Tab 1：收到 =====
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('目前沒有收到任何訊息',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 16)),
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
                              title: Row(
                                children: [
                                  if (msg['messageType'] == 'image')
                                    const Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.image,
                                          size: 16, color: Colors.blue),
                                    ),
                                  if (msg['messageType'] == 'voice')
                                    Padding(
                                      padding: EdgeInsets.only(right: 4),
                                      child: Icon(Icons.mic,
                                          size: 16,
                                          color: Color(ThemeManager()
                                                  .currentColors['primary']
                                              as int)),
                                    ),
                                  Expanded(
                                    child: Text(
                                      msg['message'] ?? '（無內容）',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: isUnread
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                '來自：${msg['senderName'] ?? '未知'} · ${_formatTime(msg['scheduledTime'])}',
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
                                    color:
                                        _statusColor(msg['status'] as String?),
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

          // ===== Tab 2：已發送 =====
          _sentMessages.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('目前沒有已發送的訊息',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSentMessages,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _sentMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _sentMessages[index];
                      final status = msg['status'] as String? ?? '';
                      final isRead = status == 'read';
                      final isTriggered = status == 'triggered';
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isRead
                                ? Colors.green
                                : isTriggered
                                    ? Colors.orange
                                    : Colors.blue,
                            child: Icon(
                              isRead ? Icons.done_all : Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            msg['message'] ?? '（無內容）',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '收件人：${msg['receiverName'] ?? '未知'} · ${_formatTime(msg['scheduledTime'])}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.green.withOpacity(0.15)
                                  : isTriggered
                                      ? Colors.orange.withOpacity(0.15)
                                      : Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isRead
                                  ? '✅ 已讀'
                                  : isTriggered
                                      ? '👁 未讀'
                                      : '⏳ 等待',
                              style: TextStyle(
                                color: isRead
                                    ? Colors.green
                                    : isTriggered
                                        ? Colors.orange
                                        : Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () => _openSentMessage(msg),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
