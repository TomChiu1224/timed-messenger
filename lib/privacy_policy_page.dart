import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('隱私權政策'),
        backgroundColor: const Color(0xFF7B2FBE),
        foregroundColor: Colors.white,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '愛傳時 隱私權政策',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '最後更新日期：2025年7月',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            SizedBox(height: 24),

            _SectionTitle('一、我們收集的資料'),
            _SectionBody(
              '使用愛傳時時，我們會收集以下資料：\n\n'
              '• Google 帳號資訊（名稱、電子郵件、大頭貼）：用於登入與識別用戶身份。\n\n'
              '• FCM 推播通知 Token：用於發送定時訊息通知到您的裝置。\n\n'
              '• 您建立的排程訊息內容與時間：儲存於 Firebase 雲端資料庫，用於定時發送訊息。\n\n'
              '• 好友關係資料：用於實現好友間的訊息傳送功能。',
            ),
            SizedBox(height: 20),

            _SectionTitle('二、資料的使用方式'),
            _SectionBody(
              '我們收集的資料僅用於以下目的：\n\n'
              '• 提供定時訊息傳送服務。\n\n'
              '• 發送推播通知提醒您排程訊息已觸發。\n\n'
              '• 維護好友系統與訊息收件匣功能。\n\n'
              '• 改善 App 功能與使用體驗。',
            ),
            SizedBox(height: 20),

            _SectionTitle('三、資料的儲存與安全'),
            _SectionBody(
              '您的資料儲存於 Google Firebase 雲端平台，受到 Google 的安全機制保護。'
              '我們採取合理的技術措施保護您的個人資料，防止未經授權的存取、洩露或竄改。',
            ),
            SizedBox(height: 20),

            _SectionTitle('四、資料分享'),
            _SectionBody(
              '我們不會將您的個人資料出售、出租或提供給任何第三方。\n\n'
              '僅在以下情況下才會分享資料：\n\n'
              '• 您主動傳送訊息給好友時，對方可看到您的名稱與訊息內容。\n\n'
              '• 法律要求時。',
            ),
            SizedBox(height: 20),

            _SectionTitle('五、第三方服務'),
            _SectionBody(
              '本 App 使用以下第三方服務：\n\n'
              '• Google Firebase（身份驗證、資料庫、推播通知）\n\n'
              '• Google Sign-In（登入服務）\n\n'
              '以上服務有各自的隱私權政策，請參閱 Google 的隱私權政策了解詳情。',
            ),
            SizedBox(height: 20),

            _SectionTitle('六、您的權利'),
            _SectionBody(
              '您隨時可以：\n\n'
              '• 刪除您的帳號及所有相關資料。\n\n'
              '• 要求我們提供您的個人資料副本。\n\n'
              '• 要求我們更正或刪除您的個人資料。',
            ),
            SizedBox(height: 20),

            _SectionTitle('七、聯絡我們'),
            _SectionBody(
              '如果您對本隱私權政策有任何疑問，請透過以下方式聯絡我們：\n\n'
              '電子郵件：maddox013190@gmail.com',
            ),
            SizedBox(height: 40),

            Center(
              child: Text(
                '© 2025 愛傳時 TimedMessenger',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF7B2FBE),
        ),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String text;
  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, height: 1.6),
    );
  }
}
