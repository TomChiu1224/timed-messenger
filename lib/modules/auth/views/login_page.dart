import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    final user = await AuthService.signInWithGoogle();

    if (mounted) {
      setState(() => _isLoading = false);
      if (user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('歡迎！${user.displayName}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登入失敗，請再試一次')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              const Icon(
                Icons.send_rounded,
                size: 80,
                color: Color(0xFF2E75B6),
              ),
              const SizedBox(height: 24),

              // App 名稱
              const Text(
                '愛傳時',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F3864),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '定時傳遞每份心意',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),

              // Google 登入按鈕
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _handleGoogleSignIn,
                        icon: Image.network(
                          'https://www.google.com/favicon.ico',
                          width: 24,
                          height: 24,
                        ),
                        label: const Text(
                          '使用 Google 帳號登入',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
