# Firebase Cloud Messaging (FCM) 推播通知配置指南

## 📋 概述

本專案已整合 Firebase Cloud Messaging (FCM)，可在 App 關閉時也能收到排程提醒。

## 🔧 必要配置步驟

### 1️⃣ Firebase 專案設定

1. 前往 [Firebase Console](https://console.firebase.google.com/)
2. 選擇您的專案（如沒有專案，需先建立）
3. 進入「專案設定」→「Cloud Messaging」

### 2️⃣ Android 配置

1. 下載 `google-services.json` 檔案
2. 將檔案放置於 `android/app/` 目錄下
3. 確認 `android/app/build.gradle` 包含以下設定：

```gradle
dependencies {
    // ... 其他依賴
    implementation platform('com.google.firebase:firebase-bom:33.6.0')
    implementation 'com.google.firebase:firebase-messaging'
}

apply plugin: 'com.google.gms.google-services'
```

4. 確認 `android/build.gradle` 包含：

```gradle
buildscript {
    dependencies {
        // ... 其他依賴
        classpath 'com.google.gms:google-services:4.4.2'
    }
}
```

5. 在 `android/app/src/main/AndroidManifest.xml` 添加權限：

```xml
<manifest>
    <!-- FCM 推播通知權限 -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    
    <application>
        <!-- ... 其他配置 -->
    </application>
</manifest>
```

### 3️⃣ iOS 配置

1. 下載 `GoogleService-Info.plist` 檔案
2. 將檔案放置於 `ios/Runner/` 目錄下
3. 在 Xcode 中：
   - 開啟 `ios/Runner.xcworkspace`
   - 選擇 Runner target
   - 前往「Signing & Capabilities」
   - 點擊「+ Capability」
   - 添加「Push Notifications」
   - 添加「Background Modes」並勾選「Remote notifications」

4. 取得 APNs 認證金鑰：
   - 前往 [Apple Developer](https://developer.apple.com/account/resources/authkeys/list)
   - 建立新的 APNs 認證金鑰
   - 下載 `.p8` 檔案
   - 在 Firebase Console 中上傳此金鑰

### 4️⃣ 測試推播通知

#### 在 App 內測試

執行 App 後，FCM Token 會自動產生並顯示在控制台：

```
✅ FCM Token: [您的 Token]
```

#### 使用 Firebase Console 測試

1. 前往 Firebase Console → Cloud Messaging
2. 點擊「傳送測試訊息」
3. 輸入 FCM Token
4. 填寫通知標題和內容
5. 點擊「測試」

#### 使用 curl 測試

```bash
curl -X POST https://fcm.googleapis.com/fcm/send \
  -H "Authorization: key=YOUR_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "to": "YOUR_FCM_TOKEN",
    "notification": {
      "title": "測試通知",
      "body": "這是一則測試推播訊息"
    },
    "data": {
      "message_id": "123",
      "type": "scheduled_reminder"
    }
  }'
```

## 📱 功能說明

### 已實作功能

✅ **前景通知**：App 在前台時收到推播並播放音效、震動
✅ **背景通知**：App 在背景時收到推播
✅ **關閉狀態通知**：App 完全關閉時也能收到推播
✅ **FCM Token 管理**：自動更新和儲存 Token
✅ **主題訂閱**：支援訂閱/取消訂閱推播主題
✅ **權限管理**：自動請求通知權限

### 整合的服務

- `lib/services/fcm_service.dart` - FCM 核心服務
- `lib/services/notification_manager.dart` - 本地通知管理
- `lib/services/audio_manager.dart` - 音效播放
- `lib/services/vibration_manager.dart` - 震動控制

## 🔐 安全注意事項

⚠️ **請勿將以下檔案提交到版本控制系統：**

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- Firebase Server Key

建議在 `.gitignore` 中添加：

```
# Firebase 配置檔案
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

## 📊 後端整合

若要從後端發送推播通知，需要：

1. **儲存 FCM Token**：當用戶登入時，將 `fcmService.fcmToken` 傳送到後端儲存
2. **發送通知**：使用 Firebase Admin SDK 或 FCM HTTP API 發送推播

### Node.js 範例（使用 Firebase Admin SDK）

```javascript
const admin = require('firebase-admin');

// 初始化 Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// 發送推播通知
async function sendNotification(fcmToken, title, body, data) {
  const message = {
    notification: {
      title: title,
      body: body
    },
    data: data,
    token: fcmToken
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('成功發送訊息:', response);
  } catch (error) {
    console.log('發送訊息失敗:', error);
  }
}
```

## 🐛 常見問題

### Q: 收不到推播通知？

1. 檢查是否已授予通知權限
2. 確認 FCM Token 已正確取得
3. 檢查 `google-services.json` / `GoogleService-Info.plist` 是否正確放置
4. 確認 Firebase 專案設定正確

### Q: iOS 收不到背景通知？

1. 確認已添加 Push Notifications capability
2. 確認已添加 Background Modes → Remote notifications
3. 確認已上傳 APNs 認證金鑰到 Firebase

### Q: Android 編譯錯誤？

1. 確認 `google-services.json` 在正確位置
2. 檢查 gradle 配置是否正確
3. 執行 `flutter clean` 後重新編譯

## 📚 相關資源

- [Firebase Cloud Messaging 官方文檔](https://firebase.google.com/docs/cloud-messaging)
- [Flutter Firebase Messaging 套件](https://pub.dev/packages/firebase_messaging)
- [FCM HTTP v1 API](https://firebase.google.com/docs/reference/fcm/rest/v1/projects.messages)

---

**最後更新**：2026-04-07
**版本**：v1.0.0
