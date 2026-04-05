import 'user_manager.dart'; // ✅ 確保有這行 import
import 'package:flutter/material.dart';
import 'firebase_service.dart';

/// ✅ 用戶設定頁面 - 提供帳號管理與應用程式設定
class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final UserManager _userManager = UserManager();

  UserProfile? _userProfile;  // ✅ 正確
  bool _notificationEnabled = true;
  String _themeMode = 'system';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// 載入用戶資料和設定
  Future<void> _loadUserData() async {
    try {
      final profile = await _userManager.getCurrentUserProfile();
      final notificationEnabled = await _userManager.getNotificationEnabled();
      final themeMode = await _userManager.getThemeMode();

      setState(() {
        _userProfile = profile;
        _notificationEnabled = notificationEnabled;
        _themeMode = themeMode;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 載入用戶資料失敗: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 登出確認對話框
  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('您確定要登出嗎？登出後將無法同步資料到雲端。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleSignOut();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('登出'),
          ),
        ],
      ),
    );
  }

  /// 處理登出
  Future<void> _handleSignOut() async {
    try {
      await _firebaseService.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已成功登出'),
            backgroundColor: Colors.green,
          ),
        );

        // 返回登入頁面
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登出失敗：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 刪除帳號確認對話框
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('刪除帳號'),
        content: const Text(
          '⚠️ 警告：此操作無法復原！\n\n'
              '刪除帳號將會：\n'
              '• 永久刪除您的所有資料\n'
              '• 移除所有排程訊息\n'
              '• 無法恢復帳號資訊\n\n'
              '您確定要繼續嗎？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleDeleteAccount();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('確認刪除'),
          ),
        ],
      ),
    );
  }

  /// 處理刪除帳號
  Future<void> _handleDeleteAccount() async {
    try {
      // 需要重新認證
      await _firebaseService.reauthenticate();
      await _firebaseService.deleteAccount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('帳號已成功刪除'),
            backgroundColor: Colors.green,
          ),
        );

        // 返回登入頁面
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刪除帳號失敗：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 更新通知設定
  Future<void> _updateNotificationSetting(bool enabled) async {
    try {
      await _userManager.setNotificationEnabled(enabled);
      setState(() {
        _notificationEnabled = enabled;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? '通知已啟用' : '通知已關閉'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('❌ 更新通知設定失敗: $e');
    }
  }

  /// 更新主題設定
  Future<void> _updateThemeSetting(String mode) async {
    try {
      await _userManager.setThemeMode(mode);
      setState(() {
        _themeMode = mode;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('主題已切換為：${_getThemeDisplayName(mode)}'),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('❌ 更新主題設定失敗: $e');
    }
  }

  /// 取得主題顯示名稱
  String _getThemeDisplayName(String mode) {
    switch (mode) {
      case 'light':
        return '淺色模式';
      case 'dark':
        return '深色模式';
      case 'system':
      default:
        return '跟隨系統';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帳號設定'),
        backgroundColor: Colors.purple.shade600,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用戶資訊卡片
            if (_userProfile != null) _buildUserInfoCard(),
            const SizedBox(height: 24),

            // 應用程式設定
            _buildSectionTitle('應用程式設定'),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.notifications,
                title: '推播通知',
                subtitle: '接收排程提醒通知',
                value: _notificationEnabled,
                onChanged: _updateNotificationSetting,
              ),
              _buildListTile(
                icon: Icons.palette,
                title: '主題模式',
                subtitle: _getThemeDisplayName(_themeMode),
                onTap: _showThemeDialog,
              ),
              _buildListTile(
                icon: Icons.language,
                title: '語言設定',
                subtitle: '繁體中文',
                onTap: () {
                  // 暫時不實作語言切換
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('語言切換功能開發中')),
                  );
                },
              ),
            ]),
            const SizedBox(height: 24),

            // 帳號管理
            if (_firebaseService.isSignedIn) ...[
              _buildSectionTitle('帳號管理'),
              _buildSettingsCard([
                _buildListTile(
                  icon: Icons.logout,
                  title: '登出',
                  subtitle: '登出當前帳號',
                  onTap: _showSignOutDialog,
                  titleColor: Colors.orange,
                ),
                _buildListTile(
                  icon: Icons.delete_forever,
                  title: '刪除帳號',
                  subtitle: '永久刪除帳號和所有資料',
                  onTap: _showDeleteAccountDialog,
                  titleColor: Colors.red,
                ),
              ]),
              const SizedBox(height: 24),
            ],

            // 關於應用程式
            _buildSectionTitle('關於'),
            _buildSettingsCard([
              _buildListTile(
                icon: Icons.info,
                title: '應用程式版本',
                subtitle: '1.0.0',
                onTap: () {},
              ),
              _buildListTile(
                icon: Icons.privacy_tip,
                title: '隱私政策',
                subtitle: '了解我們如何保護您的隱私',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('隱私政策頁面開發中')),
                  );
                },
              ),
              _buildListTile(
                icon: Icons.description,
                title: '服務條款',
                subtitle: '查看使用條款',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('服務條款頁面開發中')),
                  );
                },
              ),
            ]),
          ],
        ),
      ),
    );
  }

  /// 建立用戶資訊卡片
  Widget _buildUserInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 用戶頭像
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.purple.shade100,
              backgroundImage: _userProfile!.photoURL.isNotEmpty
                  ? NetworkImage(_userProfile!.photoURL)
                  : null,
              child: _userProfile!.photoURL.isEmpty
                  ? Icon(
                Icons.person,
                size: 35,
                color: Colors.purple.shade600,
              )
                  : null,
            ),
            const SizedBox(width: 16),

            // 用戶資訊
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userProfile!.displayName.isNotEmpty
                        ? _userProfile!.displayName
                        : '未設定姓名',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _userProfile!.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (_userProfile!.lastLoginAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '上次登入：${_formatDateTime(_userProfile!.lastLoginAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建立區段標題
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.purple.shade700,
        ),
      ),
    );
  }

  /// 建立設定卡片
  Widget _buildSettingsCard(List<Widget> children) {
    return Card(
      elevation: 2,
      child: Column(children: children),
    );
  }

  /// 建立列表項目
  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? Colors.purple.shade600),
      title: Text(
        title,
        style: TextStyle(color: titleColor),
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  /// 建立開關項目
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.purple.shade600),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.purple.shade600,
      ),
    );
  }

  /// 顯示主題選擇對話框
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇主題'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('跟隨系統'),
              value: 'system',
              groupValue: _themeMode,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _updateThemeSetting(value);
              },
            ),
            RadioListTile<String>(
              title: const Text('淺色模式'),
              value: 'light',
              groupValue: _themeMode,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _updateThemeSetting(value);
              },
            ),
            RadioListTile<String>(
              title: const Text('深色模式'),
              value: 'dark',
              groupValue: _themeMode,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _updateThemeSetting(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化日期時間
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}