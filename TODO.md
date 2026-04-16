# 愛傳時APP 開發任務清單

## ✅ 已完成任務

### 任務1：重構main.dart（最優先）- 已完成
- 將 `SoundSettings` class 從 main.dart 搬移到獨立的檔案
- 建議路徑：`lib/models/sound_settings.dart`

### 任務2：重構main.dart續 - 已完成
- 將 `VibrationSettings` class 從 main.dart 搬移到 `lib/models/vibration_settings.dart`

### 任務3：重構main.dart續 - 已完成
- 將 `SimpleTimeZone` 和 `AppTimeZones` 搬移到 `lib/models/timezone_data.dart`

### 任務4：推播通知 - 已完成
- 實作 Firebase Cloud Messaging (FCM) 推播通知功能

### 任務5：付費訂閱功能 - 已完成
- 實作 Free / Lite / Plus / Pro 四個訂閱等級

---

## ✅ 已完成任務（2026-04-17）

### 任務6：收件匣未讀 Badge ✅
- 在 AppBar 新增收件匣按鈕（帶紅色數字 badge）
- 查詢 Firebase `scheduled_messages` collection 中 `receiverId = 當前用戶 uid` 且 `status = 'scheduled'` 的訊息數量
- 數量為 0 時不顯示紅點
- 使用 StreamSubscription 即時監聽未讀數量變化

### 任務7：發件人已讀回執 ✅
- 新增 `lib/inbox_page.dart` 收件匣頁面
- 用戶點開訊息時自動呼叫 `markMessageAsRead` 將 status 改為 'read'
- 更新 `messaging_service.dart` 新增收件匣相關方法

---

## ⏳ 待完成任務

### 任務8：群發功能（未來開發）
- 在新增排程頁面，收件人欄位改為可多選（從好友列表勾選多人）
- 儲存時對每個收件人各建立一筆 `scheduled_messages` 文件
- 發送手機排程列表顯示「群發（3人）」等字樣

---

## 📝 開發規範
- 每完成一個任務就執行 `flutter analyze --no-fatal-infos` 確認無錯誤
- 確認後執行 `git commit` 並推送至遠端
- 回報每個任務的完成狀態
