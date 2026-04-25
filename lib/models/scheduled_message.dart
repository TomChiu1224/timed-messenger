// ✅ 定時任務資料模型（支援分類功能的完整版）
import 'package:intl/intl.dart';

/// ✅ 定時任務資料模型，加入分類支援、時區支援、音效支援和震動支援
class ScheduledMessage {
  int? id; // ✅ 資料庫主鍵ID
  String message;
  DateTime time;
  bool sent;
  String repeatType;
  List<int> repeatDays;
  int repeatCount;
  int currentCount;
  List<int> repeatMonths;
  List<int> repeatDates; // ✅ 每月指定日期（如：每月5號、15號）
  int repeatMonthlyOrdinal; // ✅ EA功能：每月第幾個（1=第1個, 2=第2個, 5=最後一個）
  int repeatMonthlyWeekday; // ✅ EA功能：星期幾（0=日, 1=一, 2=二...6=六）
  int repeatInterval; // ✅ repeatInterval功能：間隔數量（如：每2天、每3週）
  String
      repeatIntervalUnit; // ✅ repeatInterval功能：間隔單位（'days', 'weeks', 'months', 'years'）
  DateTime? startDate;
  DateTime? endDate;

  // ✅ 時區支援欄位
  String targetTimeZone; // 目標時區ID
  String targetTimeZoneName; // 目標時區顯示名稱

  // ✅ 音效支援欄位
  bool soundEnabled; // 是否啟用音效
  String soundType; // 音效類型 ('system' 或 'custom')
  String soundPath; // 音效路徑或系統音效名稱
  double soundVolume; // 音量 (0.0-1.0)
  int soundRepeat; // 音效重複次數

  // ✅ 震動支援欄位
  bool vibrationEnabled; // 是否啟用震動
  String vibrationPattern; // 震動模式ID
  double vibrationIntensity; // 震動強度 (0.0-1.0)
  int vibrationRepeat; // 震動重複次數

  // ✅ 新增分類支援欄位
  int? categoryId; // 分類ID（可為null）
  List<String> tags; // 標籤列表

  // ✅ 收件人欄位
  String? receiverId; // 收件人的 Firebase UID
  String? receiverName; // 收件人的顯示名稱
  List<String> firestoreIds; // ✅ 對應的 Firestore 文件 ID 清單

  ScheduledMessage(
    this.message,
    this.time, {
    this.id, // ✅ 可選的ID參數
    this.sent = false,
    this.repeatType = 'none',
    this.repeatDays = const [],
    this.repeatCount = 0,
    this.currentCount = 0,
    this.repeatMonths = const [],
    this.repeatDates = const [], // ✅ 每月指定日期
    this.repeatMonthlyOrdinal = 0, // ✅ EA功能：0=未設定, 1~4=第1~4個, 5=最後一個
    this.repeatMonthlyWeekday = 0, // ✅ EA功能：星期幾（0~6）
    this.repeatInterval = 1, // ✅ repeatInterval功能：預設間隔1
    this.repeatIntervalUnit = 'days', // ✅ repeatInterval功能：預設單位天
    this.startDate,
    this.endDate,
    // ✅ 時區欄位預設值
    this.targetTimeZone = 'Asia/Taipei',
    this.targetTimeZoneName = '台灣時間 (GMT+8)',
    // ✅ 音效欄位預設值
    this.soundEnabled = true,
    this.soundType = 'system',
    this.soundPath = 'notification',
    this.soundVolume = 0.8,
    this.soundRepeat = 1,
    // ✅ 震動欄位預設值
    this.vibrationEnabled = true,
    this.vibrationPattern = 'short',
    this.vibrationIntensity = 0.8,
    this.vibrationRepeat = 1,
    // ✅ 分類欄位預設值
    this.categoryId,
    this.tags = const [],
    this.receiverId,
    this.receiverName,
    this.firestoreIds = const [],
  });

  // ========== ✅ SQLite 序列化方法 - 分類+音效+震動整合版本 ==========

  /// 將物件轉換為 Map（用於儲存到資料庫）
  Map<String, dynamic> toMap() {
    final map = {
      'message': message,
      'time': time.millisecondsSinceEpoch,
      'sent': sent ? 1 : 0,
      'repeat_type': repeatType,
      'repeat_days': repeatDays.join(','),
      'repeat_months': repeatMonths.join(','),
      'repeat_dates': repeatDates.join(','),
      'repeat_monthly_ordinal': repeatMonthlyOrdinal,
      'repeat_monthly_weekday': repeatMonthlyWeekday,
      'repeat_interval': repeatInterval,
      'repeat_interval_unit': repeatIntervalUnit,
      'repeat_count': repeatCount,
      'current_count': currentCount,
      'start_date': startDate?.millisecondsSinceEpoch,
      'end_date': endDate?.millisecondsSinceEpoch,
      // ✅ 時區欄位
      'target_timezone': targetTimeZone,
      'target_timezone_name': targetTimeZoneName,
      // ✅ 音效欄位
      'sound_enabled': soundEnabled ? 1 : 0,
      'sound_type': soundType,
      'sound_path': soundPath,
      'sound_volume': soundVolume,
      'sound_repeat': soundRepeat,
      // ✅ 震動欄位
      'vibration_enabled': vibrationEnabled ? 1 : 0,
      'vibration_pattern': vibrationPattern,
      'vibration_intensity': vibrationIntensity,
      'vibration_repeat': vibrationRepeat,
      // ✅ 分類欄位
      'category_id': categoryId,
      'tags': tags.join(','),
      'receiver_id': receiverId,
      'receiver_name': receiverName,
      'firestore_ids': firestoreIds.join(','),
    };

    // 只有在更新時才包含ID
    if (id != null) {
      map['id'] = id!;
    }

    return map;
  }

  /// 從 Map 建立物件（用於從資料庫載入）- 完整版本
  static ScheduledMessage fromMap(Map<String, dynamic> map) {
    // ✅ 安全的列表解析函數
    List<int> parseIntList(String? str) {
      if (str == null || str.isEmpty) return [];
      return str
          .split(',')
          .where((s) => s.isNotEmpty)
          .map((s) => int.tryParse(s.trim()) ?? 0)
          .toList();
    }

    // ✅ 安全的字串列表解析函數
    List<String> parseStringList(String? str) {
      if (str == null || str.isEmpty) return [];
      return str
          .split(',')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList();
    }

    return ScheduledMessage(
      map['message'] ?? '',
      DateTime.fromMillisecondsSinceEpoch(map['time'] ?? 0),
      id: map['id'],
      sent: (map['sent'] ?? 0) == 1,
      repeatType: map['repeat_type'] ?? 'none',
      repeatDays: parseIntList(map['repeat_days']),
      repeatMonths: parseIntList(map['repeat_months']),
      repeatDates: parseIntList(map['repeat_dates']),
      repeatMonthlyOrdinal: map['repeat_monthly_ordinal'] ?? 0,
      repeatMonthlyWeekday: map['repeat_monthly_weekday'] ?? 0,
      repeatInterval: map['repeat_interval'] ?? 1,
      repeatIntervalUnit: map['repeat_interval_unit'] ?? 'days',
      repeatCount: map['repeat_count'] ?? 0,
      currentCount: map['current_count'] ?? 0,
      startDate: map['start_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['start_date'])
          : null,
      endDate: map['end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_date'])
          : null,
      // ✅ 時區欄位
      targetTimeZone: map['target_timezone'] ?? 'Asia/Taipei',
      targetTimeZoneName: map['target_timezone_name'] ?? '台灣時間 (GMT+8)',
      // ✅ 音效欄位
      soundEnabled: (map['sound_enabled'] ?? 1) == 1,
      soundType: map['sound_type'] ?? 'system',
      soundPath: map['sound_path'] ?? 'notification',
      soundVolume: (map['sound_volume'] ?? 0.8).toDouble(),
      soundRepeat: map['sound_repeat'] ?? 1,
      // ✅ 震動欄位
      vibrationEnabled: (map['vibration_enabled'] ?? 1) == 1,
      vibrationPattern: map['vibration_pattern'] ?? 'short',
      vibrationIntensity: (map['vibration_intensity'] ?? 0.8).toDouble(),
      vibrationRepeat: map['vibration_repeat'] ?? 1,
      // ✅ 分類欄位
      categoryId: map['category_id'],
      tags: parseStringList(map['tags']),
      receiverId: map['receiver_id'],
      receiverName: map['receiver_name'],
      firestoreIds: parseStringList(map['firestore_ids']),
    );
  }

  // ========== ✅ 分類相關輔助方法 ==========

  /// 檢查是否有指定分類
  bool hasCategory() => categoryId != null;

  /// 檢查是否有標籤
  bool hasTags() => tags.isNotEmpty;

  /// 新增標籤
  void addTag(String tag) {
    final trimmedTag = tag.trim();
    if (trimmedTag.isNotEmpty && !tags.contains(trimmedTag)) {
      tags.add(trimmedTag);
    }
  }

  /// 移除標籤
  void removeTag(String tag) {
    tags.remove(tag);
  }

  /// 檢查是否包含指定標籤
  bool hasTag(String tag) => tags.contains(tag);

  /// 取得標籤字串（用於顯示）
  String getTagsString() => tags.join(', ');

  /// 清除所有標籤
  void clearTags() => tags.clear();

  // ========== 原有的其他方法保持不變 ==========

  /// ✅ 複製建構子（支援分類）
  ScheduledMessage copyWith({
    int? id,
    String? message,
    DateTime? time,
    bool? sent,
    String? repeatType,
    List<int>? repeatDays,
    int? repeatCount,
    int? currentCount,
    List<int>? repeatMonths,
    List<int>? repeatDates,
    int? repeatMonthlyOrdinal,
    int? repeatMonthlyWeekday,
    int? repeatInterval,
    String? repeatIntervalUnit,
    DateTime? startDate,
    DateTime? endDate,
    String? targetTimeZone,
    String? targetTimeZoneName,
    bool? soundEnabled,
    String? soundType,
    String? soundPath,
    double? soundVolume,
    int? soundRepeat,
    bool? vibrationEnabled,
    String? vibrationPattern,
    double? vibrationIntensity,
    int? vibrationRepeat,
    int? categoryId,
    List<String>? tags,
    String? receiverId,
    String? receiverName,
    List<String>? firestoreIds,
  }) {
    return ScheduledMessage(
      message ?? this.message,
      time ?? this.time,
      id: id ?? this.id,
      sent: sent ?? this.sent,
      repeatType: repeatType ?? this.repeatType,
      repeatDays: repeatDays ?? this.repeatDays,
      repeatCount: repeatCount ?? this.repeatCount,
      currentCount: currentCount ?? this.currentCount,
      repeatMonths: repeatMonths ?? this.repeatMonths,
      repeatDates: repeatDates ?? this.repeatDates,
      repeatMonthlyOrdinal: repeatMonthlyOrdinal ?? this.repeatMonthlyOrdinal,
      repeatMonthlyWeekday: repeatMonthlyWeekday ?? this.repeatMonthlyWeekday,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatIntervalUnit: repeatIntervalUnit ?? this.repeatIntervalUnit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      targetTimeZone: targetTimeZone ?? this.targetTimeZone,
      targetTimeZoneName: targetTimeZoneName ?? this.targetTimeZoneName,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundType: soundType ?? this.soundType,
      soundPath: soundPath ?? this.soundPath,
      soundVolume: soundVolume ?? this.soundVolume,
      soundRepeat: soundRepeat ?? this.soundRepeat,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
      vibrationIntensity: vibrationIntensity ?? this.vibrationIntensity,
      vibrationRepeat: vibrationRepeat ?? this.vibrationRepeat,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      firestoreIds: firestoreIds ?? this.firestoreIds,
    );
  }

  /// 取得重複資訊文字
  String getRepeatInfo() {
    switch (repeatType) {
      case 'daily':
        return '每日重複';
      case 'weekly':
        if (repeatDays.isEmpty) return '每週重複';
        const days = ['日', '一', '二', '三', '四', '五', '六'];
        final dayNames = repeatDays.map((d) => '週${days[d]}').join('、');
        return '每週 $dayNames';
      case 'weekdays':
        return '平日重複 (週一至週五)';
      case 'monthly':
        return '每月重複';
      case 'monthlyDates':
        if (repeatDates.isEmpty) return '每月重複';
        final dates = repeatDates.map((d) => '$d號').join('、');
        return '每月 $dates';
      case 'monthlyOrdinal':
        const days = ['日', '一', '二', '三', '四', '五', '六'];
        const ordinals = ['', '第1個', '第2個', '第3個', '第4個', '最後一個'];
        final ordinalText =
            repeatMonthlyOrdinal >= 1 && repeatMonthlyOrdinal <= 5
                ? ordinals[repeatMonthlyOrdinal]
                : '第$repeatMonthlyOrdinal個';
        final weekdayText =
            repeatMonthlyWeekday >= 0 && repeatMonthlyWeekday <= 6
                ? days[repeatMonthlyWeekday]
                : '$repeatMonthlyWeekday';
        return '每月$ordinalText星期$weekdayText';
      case 'yearly':
        return '每年重複';
      case 'interval':
        const unitTexts = {
          'days': '天',
          'weeks': '週',
          'months': '月',
          'years': '年'
        };
        final unitText = unitTexts[repeatIntervalUnit] ?? '天';
        return '每$repeatInterval$unitText重複';
      case 'custom':
        return '自訂重複 $repeatCount 次';
      default:
        return '不重複';
    }
  }

  /// 檢查是否為重複任務
  bool isRepeating() => repeatType != 'none';

  /// 取得狀態文字
  String getStatusText() {
    if (sent) {
      return isRepeating() ? '等待下次觸發' : '已完成';
    } else {
      final now = DateTime.now();
      if (time.isBefore(now)) {
        return '逾時未執行';
      } else {
        return '等待執行';
      }
    }
  }

  /// 格式化時間顯示
  String getFormattedTime() {
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  /// 格式化時間顯示（含時區）
  String getFormattedTimeWithZone() {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(time);
    if (targetTimeZone == 'Asia/Taipei') {
      return timeText;
    }
    return '$timeText ($targetTimeZoneName)';
  }

  @override
  String toString() {
    return 'ScheduledMessage(id: $id, message: $message, time: $time, categoryId: $categoryId, tags: $tags)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduledMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
