import 'package:flutter/material.dart';
import 'firebase_service.dart';

/// ✅ 登入頁面 - 提供Google登入功能
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  /// Google 登入處理
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await _firebaseService.signInWithGoogle();

      if (userCredential != null && mounted) {
        // 登入成功，顯示歡迎訊息
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('歡迎 ${userCredential.user?.displayName ?? '用戶'}！'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // 登入成功後會自動透過 StreamBuilder 跳轉到主頁面
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登入失敗：$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 遊客模式（暫時跳過登入）
  void _continueAsGuest() {
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade400,
              Colors.purple.shade600,
              Colors.purple.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 應用程式標誌區域
                const Icon(
                  Icons.schedule_send,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),

                // 應用程式標題
                const Text(
                  '定時訊息提醒',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),

                // 應用程式副標題
                const Text(
                  '讓重要訊息準時送達',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 48),

                // 功能特色卡片
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureItem(
                        Icons.calendar_today,
                        '靈活排程',
                        '支援多種重複模式，如每日、每週、每月等',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        Icons.cloud_sync,
                        '雲端同步',
                        '登入後資料安全儲存，多裝置同步',
                      ),
                      const SizedBox(height: 16),
                      _buildFeatureItem(
                        Icons.notifications_active,
                        '準時提醒',
                        '本地通知確保不會錯過重要時刻',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Google 登入按鈕
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleGoogleSignIn,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.purple),
                          ),
                        )
                      : const Icon(Icons.login, color: Colors.purple),
                  label: Text(
                    _isLoading ? '登入中...' : '使用 Google 帳號登入',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
                const SizedBox(height: 16),

                // 遊客模式按鈕
                TextButton(
                  onPressed: _continueAsGuest,
                  child: const Text(
                    '暫時跳過登入',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 隱私條款
                const Text(
                  '登入即表示您同意我們的服務條款和隱私政策',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 建立功能特色項目
  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
