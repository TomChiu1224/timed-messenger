import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/group_model.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});
  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  List<Map<String, dynamic>> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final snapshot =
          await FirebaseFirestore.instance.collection('groups').get();
      final myGroups = snapshot.docs
          .where((doc) {
            final members = doc.data()['members'] as List<dynamic>? ?? [];
            return members
                .any((m) => (m as Map<String, dynamic>)['uid'] == user.uid);
          })
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();
      if (mounted)
        setState(() {
          _groups = myGroups;
          _isLoading = false;
        });
    } catch (e) {
      debugPrint('載入群組失敗: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ 顯示群組詳情（含新增成員、移除成員）
  void _showGroupDetail(Map<String, dynamic> group) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = group['creatorId'] == currentUser?.uid;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final members = (group['members'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
          return AlertDialog(
            title: Row(
              children: [
                CircleAvatar(
                  child: Text(
                    (group['name'] as String? ?? '?').isNotEmpty
                        ? (group['name'] as String)[0]
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(group['name'] ?? '未命名群組')),
                IconButton(
                  icon: const Icon(Icons.qr_code, color: Colors.teal),
                  tooltip: '邀請 QR Code',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('群組邀請 QR Code'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(group['name'] ?? ''),
                            const SizedBox(height: 16),
                            QrImageView(
                              data: 'aitchuanshi://joingroup?id=${group['id']}',
                              version: QrVersions.auto,
                              size: 220,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '讓朋友掃描此 QR Code 加入群組',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
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
                  },
                ), // QR Code IconButton
                if (isCreator)
                  IconButton(
                    icon: const Icon(Icons.person_add, color: Colors.teal),
                    tooltip: '新增成員',
                    onPressed: () async {
                      Navigator.pop(context);
                      await _addMemberToGroup(group);
                    },
                  ), // IconButton
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('成員（${members.length} 人）',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        final isAdmin = member['role'] == 'admin';
                        final isSelf = member['uid'] == currentUser?.uid;
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              (member['displayName'] as String? ?? '?')
                                      .isNotEmpty
                                  ? (member['displayName'] as String)[0]
                                  : '?',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          title: Text(member['displayName'] ?? '未知'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isAdmin)
                                const Chip(
                                  label: Text('管理員',
                                      style: TextStyle(fontSize: 11)),
                                  padding: EdgeInsets.zero,
                                ),
                              // ✅ 管理員可以移除非自己的成員
                              if (isCreator && !isSelf)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.red, size: 20),
                                  tooltip: '移除成員',
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _removeMember(group, member);
                                  },
                                ),
                            ],
                          ),
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (isCreator)
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _deleteGroup(group);
                  },
                  child:
                      const Text('刪除群組', style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('關閉'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ 新增成員到群組
  Future<void> _addMemberToGroup(Map<String, dynamic> group) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final currentMembers =
        (group['members'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final currentMemberUids =
        currentMembers.map((m) => m['uid'] as String).toSet();

    List<Map<String, dynamic>> friendList = [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('friendships')
          .doc(currentUser.uid)
          .collection('friends')
          .where('status', isEqualTo: 'accepted')
          .get();
      for (final doc in snapshot.docs) {
        if (currentMemberUids.contains(doc.id)) continue; // 已在群組裡跳過
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          friendList.add({
            'uid': doc.id,
            'displayName': data['displayName'] ?? data['username'] ?? '未知用戶',
          });
        }
      }
    } catch (e) {
      debugPrint('載入好友失敗: $e');
    }

    if (!mounted) return;
    final pageContext = context;

    if (friendList.isEmpty) {
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('⚠️ 沒有可新增的好友（全部已在群組中）')),
      );
      _showGroupDetail(group);
      return;
    }

    String? selectedUid;
    await showDialog(
      context: pageContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('新增成員'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: friendList.length,
              itemBuilder: (context, index) {
                final friend = friendList[index];
                return RadioListTile<String>(
                  title: Text(friend['displayName']),
                  value: friend['uid'] as String,
                  groupValue: selectedUid,
                  onChanged: (val) => setDialogState(() => selectedUid = val),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: selectedUid == null
                  ? null
                  : () async {
                      final friend =
                          friendList.firstWhere((f) => f['uid'] == selectedUid);
                      Navigator.pop(dialogContext);
                      try {
                        final newMember = {
                          'uid': friend['uid'],
                          'displayName': friend['displayName'],
                          'role': 'member',
                        };
                        final updatedMembers = [...currentMembers, newMember];
                        await FirebaseFirestore.instance
                            .collection('groups')
                            .doc(group['id'])
                            .update({'members': updatedMembers});
                        group['members'] = updatedMembers;
                        if (mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(
                                content:
                                    Text('✅ 已新增 ${friend['displayName']}')),
                          );
                          _loadGroups();
                          _showGroupDetail(group);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            SnackBar(content: Text('❌ 新增失敗: $e')),
                          );
                          _showGroupDetail(group);
                        }
                      }
                    },
              child: const Text('新增'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 移除群組成員
  Future<void> _removeMember(
      Map<String, dynamic> group, Map<String, dynamic> member) async {
    final pageContext = context;
    final confirm = await showDialog<bool>(
      context: pageContext,
      builder: (context) => AlertDialog(
        title: const Text('確認移除'),
        content: Text('確定要將「${member['displayName']}」從群組移除嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final currentMembers =
            (group['members'] as List<dynamic>).cast<Map<String, dynamic>>();
        final updatedMembers =
            currentMembers.where((m) => m['uid'] != member['uid']).toList();
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(group['id'])
            .update({'members': updatedMembers});
        group['members'] = updatedMembers;
        if (mounted) {
          ScaffoldMessenger.of(pageContext).showSnackBar(
            SnackBar(content: Text('✅ 已移除 ${member['displayName']}')),
          );
          _loadGroups();
          _showGroupDetail(group);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(pageContext).showSnackBar(
            SnackBar(content: Text('❌ 移除失敗: $e')),
          );
          _showGroupDetail(group);
        }
      }
    } else {
      _showGroupDetail(group);
    }
  }

  // ✅ 刪除整個群組
  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除群組「${group['name']}」嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('groups')
            .doc(group['id'])
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ 群組已刪除')),
          );
          _loadGroups();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ 刪除失敗: $e')),
          );
        }
      }
    }
  }

  // ✅ 建立群組
  Future<void> _showCreateGroupDialog() async {
    final nameController = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    List<Map<String, dynamic>> friendList = [];
    List<String> selectedUids = [];
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('friendships')
          .doc(currentUser.uid)
          .collection('friends')
          .where('status', isEqualTo: 'accepted')
          .get();
      for (final doc in snapshot.docs) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(doc.id)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data()!;
          friendList.add({
            'uid': doc.id,
            'displayName': data['displayName'] ?? data['username'] ?? '未知用戶',
          });
        }
      }
    } catch (e) {
      debugPrint('載入好友失敗: $e');
    }

    if (!mounted) return;
    final pageContext = context;

    await showDialog(
      context: pageContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('建立群組'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: '輸入群組名稱',
                    prefixIcon: Icon(Icons.group),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('選擇成員：',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: friendList.isEmpty
                      ? const Center(
                          child: Text('沒有好友可加入',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: friendList.length,
                          itemBuilder: (context, index) {
                            final friend = friendList[index];
                            final isSelected =
                                selectedUids.contains(friend['uid']);
                            return CheckboxListTile(
                              title: Text(friend['displayName']),
                              value: isSelected,
                              onChanged: (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    selectedUids.add(friend['uid'] as String);
                                  } else {
                                    selectedUids
                                        .remove(friend['uid'] as String);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('⚠️ 請輸入群組名稱')),
                  );
                  return;
                }
                if (selectedUids.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('⚠️ 請至少選擇一位成員')),
                  );
                  return;
                }
                final members = <Map<String, dynamic>>[
                  {
                    'uid': currentUser.uid,
                    'displayName':
                        currentUser.displayName ?? currentUser.email ?? '我',
                    'role': 'admin',
                  },
                  ...selectedUids.map((uid) {
                    final friend =
                        friendList.firstWhere((f) => f['uid'] == uid);
                    return <String, dynamic>{
                      'uid': uid,
                      'displayName': friend['displayName'],
                      'role': 'member',
                    };
                  }),
                ];
                Navigator.pop(dialogContext);
                try {
                  await FirebaseFirestore.instance.collection('groups').add({
                    'name': name,
                    'creatorId': currentUser.uid,
                    'members': members,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      SnackBar(content: Text('✅ 群組「$name」建立成功！')),
                    );
                    _loadGroups();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      SnackBar(content: Text('❌ 建立群組失敗: $e')),
                    );
                  }
                }
              },
              child: const Text('建立'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的群組'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateGroupDialog,
            tooltip: '建立群組',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('還沒有群組', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _showCreateGroupDialog,
                        icon: const Icon(Icons.add),
                        label: const Text('建立第一個群組'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadGroups,
                  child: ListView.builder(
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      final members =
                          (group['members'] as List<dynamic>? ?? []);
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              (group['name'] as String? ?? '?').isNotEmpty
                                  ? (group['name'] as String)[0]
                                  : '?',
                            ),
                          ),
                          title: Text(group['name'] ?? '未命名群組'),
                          subtitle: Text('${members.length} 位成員'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showGroupDetail(group),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
