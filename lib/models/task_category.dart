import 'package:flutter/material.dart';

/// 任務分類資料模型 - 完整正式版
class TaskCategory {
  /// 支援的 icon codePoint 對應表（僅允許這些 icon，避免動態產生）
  static const Map<String, IconData> iconMap = {
    '57349': Icons.category, // 預設
    '59530': Icons.work,
    '59542': Icons.home,
    '59475': Icons.star,
    '59499': Icons.school,
    // 你可以依需求擴充更多 codePoint 對應
  };
  int? id;                    // 資料庫主鍵ID
  String name;                // 分類名稱
  String description;         // 分類描述
  int colorValue;            // 顏色值（Color.value）
  String iconData;           // 圖示資料（IconData.codePoint 的字串形式）
  DateTime createdAt;        // 建立時間
  DateTime updatedAt;        // 更新時間
  bool isDefault;            // 是否為預設分類

  TaskCategory({
    this.id,
    required this.name,
    this.description = '',
    required this.colorValue,
    this.iconData = '57349', // Icons.category 的 codePoint
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isDefault = false,
  }) : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// 將物件轉換為 Map（用於儲存到資料庫）
  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'description': description,
      'color_value': colorValue,
      'icon_data': iconData,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_default': isDefault ? 1 : 0,
    };

    // 只有在更新時才包含ID
    if (id != null) {
      map['id'] = id!;  // ✅ 加上 ! 表示非null
    }

    return map;
  }

  /// 從 Map 建立物件（用於從資料庫載入）
  static TaskCategory fromMap(Map<String, dynamic> map) {
    return TaskCategory(
      id: map['id'],
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      colorValue: map['color_value'] ?? Colors.purple.value,
      iconData: map['icon_data'] ?? '57349',
      createdAt: map['created_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
          : DateTime.now(),
      isDefault: (map['is_default'] ?? 0) == 1,
    );
  }

  /// 取得顏色物件
  Color get color => Color(colorValue);

  /// 取得圖示物件
  IconData get icon {
    // 只允許 map 裡的常數 icon，否則回傳預設
    return iconMap[iconData] ?? Icons.category;
  }

  /// 複製分類（用於編輯）
  TaskCategory copyWith({
    int? id,
    String? name,
    String? description,
    int? colorValue,
    String? iconData,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
  }) {
    return TaskCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      colorValue: colorValue ?? this.colorValue,
      iconData: iconData ?? this.iconData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// 統計相關方法
  /// 計算該分類下的任務數量
  int getTaskCount(List<dynamic> allTasks) {
    return allTasks.where((task) =>
    task is Map && task['category_id'] == id).length;
  }

  /// 計算該分類下已完成的任務數量
  int getCompletedTaskCount(List<dynamic> allTasks) {
    return allTasks.where((task) =>
    task is Map &&
        task['category_id'] == id &&
        (task['sent'] == 1 || task['sent'] == true)).length;
  }

  /// 計算該分類的完成率
  double getCompletionRate(List<dynamic> allTasks) {
    final total = getTaskCount(allTasks);
    if (total == 0) return 0.0;
    final completed = getCompletedTaskCount(allTasks);
    return completed / total;
  }

  /// 取得該分類下最近的任務
  List<dynamic> getRecentTasks(List<dynamic> allTasks, {int limit = 5}) {
    final categoryTasks = allTasks.where((task) =>
    task is Map && task['category_id'] == id).toList();

    categoryTasks.sort((a, b) {
      final timeA = a['time'] as int? ?? 0;
      final timeB = b['time'] as int? ?? 0;
      return timeB.compareTo(timeA); // 降序排列（最新的在前面）
    });

    return categoryTasks.take(limit).toList();
  }

  /// 檢查分類是否可以刪除（預設分類和有關聯任務的分類不能刪除）
  bool canDelete(List<dynamic> allTasks) {
    if (isDefault) return false;
    return getTaskCount(allTasks) == 0;
  }

  /// 取得分類的使用頻率（基於任務數量）
  String getUsageFrequency(List<dynamic> allTasks) {
    final count = getTaskCount(allTasks);
    if (count == 0) return '未使用';
    if (count <= 2) return '偶爾使用';
    if (count <= 5) return '經常使用';
    return '頻繁使用';
  }

  /// 驗證分類資料的完整性
  bool isValid() {
    return name.trim().isNotEmpty &&
        colorValue > 0 &&
        iconData.isNotEmpty;
  }

  /// 取得分類的顯示標籤（包含任務數量）
  String getDisplayLabel(List<dynamic> allTasks) {
    final count = getTaskCount(allTasks);
    return '$name ($count)';
  }

  @override
  String toString() {
    return 'TaskCategory(id: $id, name: $name, color: ${color.toString()}, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TaskCategory && other.id == id && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

/// 預設分類資料 - 完整版
class DefaultCategories {
  static List<TaskCategory> get all => [
    TaskCategory(
      name: '個人',
      description: '個人生活相關提醒',
      colorValue: Colors.green.value,
      iconData: Icons.person.codePoint.toString(),
      isDefault: true,
    ),
    TaskCategory(
      name: '健康',
      description: '健康相關提醒',
      colorValue: Colors.red.value,
      iconData: Icons.favorite.codePoint.toString(),
      isDefault: true,
    ),
    TaskCategory(
      name: '其他',
      description: '其他未分類項目',
      colorValue: Colors.grey.value,
      iconData: Icons.category.codePoint.toString(),
      isDefault: true,
    ),
    TaskCategory(
      name: '娛樂',
      description: '休閒娛樂活動',
      colorValue: Colors.purple.value,
      iconData: Icons.games.codePoint.toString(),
      isDefault: true,
    ),
    TaskCategory(
      name: '學習',
      description: '學習和進修相關',
      colorValue: Colors.orange.value,
      iconData: Icons.school.codePoint.toString(),
      isDefault: true,
    ),
    TaskCategory(
      name: '家庭',
      description: '家庭相關事務',
      colorValue: Colors.pink.value,
      iconData: Icons.home.codePoint.toString(),
      isDefault: true,
    ),
    TaskCategory(
      name: '工作',
      description: '工作相關的提醒事項',
      colorValue: Colors.blue.value,
      iconData: Icons.work.codePoint.toString(),
      isDefault: true,
    ),
    TaskCategory(
      name: '財務',
      description: '理財和支付相關',
      colorValue: Colors.teal.value,
      iconData: Icons.attach_money.codePoint.toString(),
      isDefault: true,
    ),
  ];

  /// 取得預設分類的名稱列表
  static List<String> get defaultNames => all.map((c) => c.name).toList();

  /// 根據名稱取得預設分類
  static TaskCategory? getByName(String name) {
    try {
      return all.firstWhere((category) => category.name == name);
    } catch (e) {
      return null;
    }
  }

  /// 檢查是否為預設分類名稱
  static bool isDefaultCategory(String name) {
    return defaultNames.contains(name);
  }

  /// 取得所有預設分類的ID列表（用於資料庫操作）
  static List<int> getDefaultIds(List<TaskCategory> allCategories) {
    return allCategories
        .where((category) => category.isDefault)
        .map((category) => category.id!)
        .toList();
  }
}