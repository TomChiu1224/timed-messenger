import 'package:flutter/material.dart';
import 'firebase_service.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseService _firebaseService = FirebaseService();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isSearching = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFriendsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ✅ 從 Firebase 載入好友列表和待處理申請
  Future<void> _loadFriendsData() async {
    setState(() => _isLoading = true);
    try {
      final friends = await _firebaseService.getFriendList();
      final pending = await _firebaseService.getPendingFriendRequests();
      setState(() {
        _friends = friends;
        _pendingRequests = pending;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ✅ 真正連接 Firebase 的搜尋功能
  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);

    try {
      List<Map<String, dynamic>> results = [];

      // 判斷是手機號碼（全是數字）還是用戶名稱
      final isPhone = RegExp(r'^[\d\s\-\+]+$').hasMatch(query.trim());

      if (isPhone) {
        results = await _firebaseService.searchByPhone(query);
      } else {
        results = await _firebaseService.searchByUsername(query);
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  // ✅ 真正發送好友申請到 Firebase
  Future<void> _sendFriendRequest(String targetUid) async {
    final success = await _firebaseService.sendFriendRequest(targetUid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '好友申請已送出！' : '送出失敗，請稍後再試'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  // ✅ 真正接受好友申請，並更新 Firebase
  Future<void> _acceptRequest(String requestId, String fromUid) async {
    final success =
        await _firebaseService.acceptFriendRequest(requestId, fromUid);
    if (!mounted) return;
    if (success) {
      setState(() {
        _pendingRequests.removeWhere((r) => r['requestId'] == requestId);
      });
      await _loadFriendsData(); // 重新載入好友列表
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '已接受好友申請' : '操作失敗，請稍後再試'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  // ✅ 真正拒絕好友申請，並更新 Firebase
  Future<void> _rejectRequest(String requestId) async {
    final success = await _firebaseService.rejectFriendRequest(requestId);
    if (!mounted) return;
    if (success) {
      setState(() {
        _pendingRequests.removeWhere((r) => r['requestId'] == requestId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('好友'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFriendsData,
            tooltip: '重新整理',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            const Tab(icon: Icon(Icons.people), text: '好友'),
            Tab(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications),
                  if (_pendingRequests.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              text: '申請',
            ),
            const Tab(icon: Icon(Icons.search), text: '搜尋'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFriendsList(),
                _buildPendingRequests(),
                _buildSearchTab(),
              ],
            ),
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('還沒有好友',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            Text('去搜尋頁面找到朋友吧！', style: TextStyle(color: Colors.grey.shade400)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(2),
              icon: const Icon(Icons.search),
              label: const Text('搜尋好友'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _friends.length,
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.purple.shade100,
            child: Text(
              (friend['displayName'] ?? '?')[0].toUpperCase(),
              style: TextStyle(color: Colors.purple.shade700),
            ),
          ),
          title: Text(friend['displayName'] ?? '未知用戶'),
          subtitle: Text('@${friend['username'] ?? ''}'),
          trailing: IconButton(
            icon: const Icon(Icons.send, color: Colors.purple),
            onPressed: () {},
            tooltip: '傳訊息',
          ),
        );
      },
    );
  }

  Widget _buildPendingRequests() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('沒有待處理的申請',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
          ],
        ),
      );
    }
    return ListView.builder(
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple.shade100,
              child: Icon(Icons.person, color: Colors.purple.shade700),
            ),
            title: Text(request['displayName'] ?? '未知用戶'),
            subtitle: Text('@${request['username'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () =>
                      _acceptRequest(request['requestId'], request['fromUid']),
                  tooltip: '接受',
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _rejectRequest(request['requestId']),
                  tooltip: '拒絕',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '輸入用戶名稱或手機號碼',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.purple.shade600),
              ),
            ),
            onChanged: _searchUsers,
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 60, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('找不到用戶', style: TextStyle(color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('請確認用戶名稱或手機號碼是否正確',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                ],
              ),
            ),
          )
        else if (_searchResults.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.manage_search,
                      size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('搜尋好友',
                      style:
                          TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                  const SizedBox(height: 8),
                  Text('輸入對方的用戶名稱或手機號碼',
                      style: TextStyle(color: Colors.grey.shade400)),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final user = _searchResults[index];
                final isAlreadyFriend =
                    _friends.any((f) => f['uid'] == user['uid']);
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade100,
                      child: Text(
                        (user['displayName'] ?? '?')[0].toUpperCase(),
                        style: TextStyle(color: Colors.purple.shade700),
                      ),
                    ),
                    title: Text(user['displayName'] ?? '未知用戶'),
                    subtitle: Text('@${user['username'] ?? ''}'),
                    trailing: isAlreadyFriend
                        ? Chip(
                            label: const Text('已是好友'),
                            backgroundColor: Colors.green.shade100,
                          )
                        : ElevatedButton(
                            onPressed: () => _sendFriendRequest(user['uid']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('加好友'),
                          ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
