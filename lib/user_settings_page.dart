import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'privacy_policy_page.dart';
import 'user_manager.dart';
import 'firebase_service.dart';
import 'services/tts_service.dart';
import 'services/theme_manager.dart';
import 'login_page.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key});

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final UserManager _userManager = UserManager();

  UserProfile? _userProfile;
  bool _notificationEnabled = true;
  String _themeMode = 'system';
  bool _isLoading = true;
  String _textMessageMode = 'notify';
  String _voiceMessageMode = 'notify';
  bool _followSilentMode = true;

  // ✅ 新增欄位
  String _username = '';
  String _phoneNumber = '';
  bool _isEditingProfile = false;
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final profile = await _userManager.getCurrentUserProfile();
      final notificationEnabled = await _userManager.getNotificationEnabled();
      final themeMode = await _userManager.getThemeMode();
      final username = await _userManager.getUsername();
      final phoneNumber = await _userManager.getPhoneNumber();

      final textMessageMode = await TtsService.getTextMessageMode();
      final voiceMessageMode = await TtsService.getVoiceMessageMode();
      final followSilentMode = await TtsService.getFollowSilentMode();

      setState(() {
        _userProfile = profile;
        _notificationEnabled = notificationEnabled;
        _themeMode = themeMode;
        _username = username;
        _phoneNumber = phoneNumber;
        _usernameController.text = username;
        _phoneController.text = phoneNumber;
        _displayNameController.text = profile?.displayName ?? '';
        _textMessageMode = textMessageMode;
        _voiceMessageMode = voiceMessageMode;
        _followSilentMode = followSilentMode;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('請輸入用戶名稱'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await _userManager.updateUserProfile(
      username: _usernameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      displayName: _displayNameController.text.trim(),
    );

    if (success) {
      final uid = _firebaseService.getUserId();
      if (uid != null) {
        await _firebaseService.updateUserProfile(uid, {
          'username': _usernameController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'displayName': _displayNameController.text.trim(),
        });
      }
    }

    setState(() {
      _isLoading = false;
      if (success) {
        _username = _usernameController.text.trim();
        _phoneNumber = _phoneController.text.trim();
        _isEditingProfile = false;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ 資料已儲存' : '❌ 用戶名稱已被使用，請換一個'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認登出'),
        content: const Text('您確定要登出嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _firebaseService.signOut();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('登出'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('刪除帳號'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '此操作會永久刪除以下資料，且無法復原：',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• 您的個人資料'),
              Text('• 所有好友關係'),
              Text('• 所有寄出和收到的訊息'),
              Text('• 所有上傳的圖片和語音'),
              Text('• 訂閱方案資料'),
              SizedBox(height: 12),
              Text(
                '您確定要繼續嗎？',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showFinalConfirmDialog();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('我了解，繼續'),
          ),
        ],
      ),
    );
  }

  void _showFinalConfirmDialog() {
    final TextEditingController confirmController = TextEditingController();
    bool canDelete = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('最終確認'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('請輸入「刪除帳號」以確認此操作：'),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '刪除帳號',
                ),
                onChanged: (value) {
                  setDialogState(() {
                    canDelete = value.trim() == '刪除帳號';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: canDelete
                  ? () {
                      Navigator.pop(context);
                      _performDeleteAccount();
                    }
                  : null,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('永久刪除'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performDeleteAccount() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在刪除您的帳號和所有資料...'),
            SizedBox(height: 8),
            Text(
              '請勿關閉應用程式',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUserAccount',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      await callable.call();

      if (!mounted) return;

      // 立刻跳轉到登入頁，避免首頁讀到已被刪除的 user 而崩潰
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );

      // 跳轉後再顯示成功訊息（在登入頁的 Scaffold 上）
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 帳號已成功刪除'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 刪除失敗：${e.message ?? "未知錯誤"}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('🔥 刪除帳號崩潰: $e');
      debugPrint('🔥 Stack trace: $stackTrace');
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 發生錯誤：$e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ), // SnackBar
      );
    }
  }

  Future<void> _updateNotificationSetting(bool enabled) async {
    await _userManager.setNotificationEnabled(enabled);
    setState(() => _notificationEnabled = enabled);
  }

  Future<void> _updateThemeSetting(String mode) async {
    await _userManager.setThemeMode(mode);
    setState(() => _themeMode = mode);
  }

  String _getThemeDisplayName(String mode) {
    switch (mode) {
      case 'light':
        return '淺色模式';
      case 'dark':
        return '深色模式';
      default:
        return '跟隨系統';
    }
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('帳號設定'),
        backgroundColor: ThemeManager().currentColors['primary'] as Color,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_userProfile != null) _buildUserInfoCard(),
                  const SizedBox(height: 16),
                  _buildSectionTitle('個人資料設定'),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isEditingProfile) ...[
                            _buildInfoRow(Icons.badge, '用戶名稱',
                                _username.isEmpty ? '尚未設定' : '@$_username'),
                            const Divider(),
                            _buildInfoRow(Icons.phone, '手機號碼',
                                _phoneNumber.isEmpty ? '尚未設定' : _phoneNumber),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    setState(() => _isEditingProfile = true),
                                icon: const Icon(Icons.edit),
                                label: const Text('編輯個人資料'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ] else ...[
                            TextField(
                              controller: _displayNameController,
                              decoration: const InputDecoration(
                                labelText: '顯示名稱',
                                prefixIcon: Icon(Icons.person),
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: '用戶名稱（讓別人搜尋到你）',
                                prefixIcon: Icon(Icons.badge),
                                prefixText: '@',
                                border: OutlineInputBorder(),
                                helperText: '只能使用英文、數字、底線',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: '手機號碼（讓別人搜尋到你）',
                                prefixIcon: Icon(Icons.phone),
                                border: OutlineInputBorder(),
                                helperText: '格式：0912345678',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => setState(
                                        () => _isEditingProfile = false),
                                    child: const Text('取消'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('儲存'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('應用程式設定'),
                  Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        SwitchListTile(
                          secondary: Icon(Icons.notifications,
                              color: Colors.purple.shade600),
                          title: const Text('推播通知'),
                          subtitle: const Text('接收排程提醒通知'),
                          value: _notificationEnabled,
                          onChanged: _updateNotificationSetting,
                          activeColor: Colors.purple.shade600,
                        ),
                        ListTile(
                          leading: Icon(Icons.palette,
                              color: Colors.purple.shade600),
                          title: const Text('主題模式'),
                          subtitle: Text(_getThemeDisplayName(_themeMode)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showThemeDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('訊息接收偏好'),
                  Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.text_fields,
                              color: Colors.purple.shade600),
                          title: const Text('文字訊息收到時'),
                          subtitle:
                              Text(_getTextModeDisplayName(_textMessageMode)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showTextMessageModeDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading:
                              Icon(Icons.mic, color: Colors.purple.shade600),
                          title: const Text('語音訊息收到時'),
                          subtitle:
                              Text(_getVoiceModeDisplayName(_voiceMessageMode)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _showVoiceMessageModeDialog,
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          secondary: Icon(Icons.volume_off,
                              color: Colors.purple.shade600),
                          title: const Text('跟隨手機靜音設定'),
                          subtitle: const Text('手機靜音時自動變靜音'),
                          value: _followSilentMode,
                          onChanged: (val) async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('follow_silent_mode', val);
                            setState(() => _followSilentMode = val);
                          },
                          activeColor: Colors.purple.shade600,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_firebaseService.isSignedIn) ...[
                    _buildSectionTitle('帳號管理'),
                    Card(
                      elevation: 2,
                      child: Column(
                        children: [
                          ListTile(
                            leading:
                                const Icon(Icons.logout, color: Colors.orange),
                            title: const Text('登出',
                                style: TextStyle(color: Colors.orange)),
                            subtitle: const Text('登出當前帳號'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _showSignOutDialog,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.delete_forever,
                                color: Colors.red),
                            title: const Text('刪除帳號',
                                style: TextStyle(color: Colors.red)),
                            subtitle: const Text('永久刪除帳號和所有資料'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: _showDeleteAccountDialog,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildSectionTitle('關於'),
                  Card(
                    elevation: 2,
                    child: Column(
                      children: [
                        ListTile(
                          leading:
                              Icon(Icons.info, color: Colors.purple.shade600),
                          title: const Text('應用程式版本'),
                          subtitle: const Text('1.4.0'),
                          onTap: () {},
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.privacy_tip,
                              color: Colors.purple.shade600),
                          title: const Text('隱私權政策'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildUserInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Colors.purple,
              backgroundImage: (_userProfile!.photoURL.isNotEmpty)
                  ? NetworkImage(_userProfile!.photoURL)
                  : null,
              child: _userProfile!.photoURL.isEmpty
                  ? Icon(Icons.person, size: 35, color: Colors.purple.shade600)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userProfile!.displayName.isNotEmpty
                        ? _userProfile!.displayName
                        : '未設定姓名',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(_userProfile!.email,
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  if (_username.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('@$_username',
                        style: TextStyle(
                            fontSize: 13, color: Colors.purple.shade400)),
                  ],
                  if (_userProfile!.lastLoginAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '上次登入：${_formatDateTime(_userProfile!.lastLoginAt!)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple.shade700)),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.purple.shade400),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇主題'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['system', 'light'].map((mode) {
            return RadioListTile<String>(
              title: Text(_getThemeDisplayName(mode)),
              value: mode,
              groupValue: _themeMode,
              onChanged: (value) {
                Navigator.pop(context);
                if (value != null) _updateThemeSetting(value);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getTextModeDisplayName(String mode) {
    switch (mode) {
      case 'tts':
        return '🗣️ 朗讀模式';
      case 'silent':
        return '🔇 靜音模式';
      default:
        return '🔔 通知模式';
    }
  }

  String _getVoiceModeDisplayName(String mode) {
    switch (mode) {
      case 'autoplay':
        return '🎙️ 自動播放模式';
      case 'silent':
        return '🔇 靜音模式';
      default:
        return '🔔 通知模式';
    }
  }

  void _showTextMessageModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('文字訊息收到時'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['notify', 'tts', 'silent'].map((mode) {
            return RadioListTile<String>(
              title: Text(_getTextModeDisplayName(mode)),
              value: mode,
              groupValue: _textMessageMode,
              onChanged: (value) async {
                Navigator.pop(context);
                if (value != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('text_message_mode', value);
                  setState(() => _textMessageMode = value);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showVoiceMessageModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('語音訊息收到時'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['notify', 'autoplay', 'silent'].map((mode) {
            return RadioListTile<String>(
              title: Text(_getVoiceModeDisplayName(mode)),
              value: mode,
              groupValue: _voiceMessageMode,
              onChanged: (value) async {
                Navigator.pop(context);
                if (value != null) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('voice_message_mode', value);
                  setState(() => _voiceMessageMode = value);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}
