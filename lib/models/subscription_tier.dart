// ========== 訂閱等級模型 ==========
// 定義 Free/Lite/Plus/Pro 四個付費等級及其權限

enum SubscriptionTier {
  free,
  lite,
  plus,
  pro,
}

class SubscriptionPlan {
  final SubscriptionTier tier;
  final String name;
  final String description;
  final int maxMessages;
  final int maxCategories;
  final bool hasCloudSync;
  final bool hasAdvancedNotifications;
  final bool hasMultipleTimezones;
  final bool hasDataExport;
  final bool hasCustomThemes;
  final bool hasAdsRemoved;
  final String price;
  final String productId;

  const SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.description,
    required this.maxMessages,
    required this.maxCategories,
    required this.hasCloudSync,
    required this.hasAdvancedNotifications,
    required this.hasMultipleTimezones,
    required this.hasDataExport,
    required this.hasCustomThemes,
    required this.hasAdsRemoved,
    required this.price,
    required this.productId,
  });

  // 預定義的訂閱方案
  static const SubscriptionPlan free = SubscriptionPlan(
    tier: SubscriptionTier.free,
    name: 'Free 免費版',
    description: '基本功能，適合輕度使用',
    maxMessages: 10,
    maxCategories: 3,
    hasCloudSync: false,
    hasAdvancedNotifications: false,
    hasMultipleTimezones: false,
    hasDataExport: false,
    hasCustomThemes: false,
    hasAdsRemoved: false,
    price: 'NT\$0',
    productId: '',
  );

  static const SubscriptionPlan lite = SubscriptionPlan(
    tier: SubscriptionTier.lite,
    name: 'Lite 輕量版',
    description: '移除廣告，增加訊息數量',
    maxMessages: 50,
    maxCategories: 10,
    hasCloudSync: false,
    hasAdvancedNotifications: true,
    hasMultipleTimezones: false,
    hasDataExport: true,
    hasCustomThemes: false,
    hasAdsRemoved: true,
    price: 'NT\$30/月',
    productId: 'timed_messenger_lite_monthly',
  );

  static const SubscriptionPlan plus = SubscriptionPlan(
    tier: SubscriptionTier.plus,
    name: 'Plus 進階版',
    description: '雲端同步，無限訊息',
    maxMessages: 200,
    maxCategories: 30,
    hasCloudSync: true,
    hasAdvancedNotifications: true,
    hasMultipleTimezones: true,
    hasDataExport: true,
    hasCustomThemes: true,
    hasAdsRemoved: true,
    price: 'NT\$60/月',
    productId: 'timed_messenger_plus_monthly',
  );

  static const SubscriptionPlan pro = SubscriptionPlan(
    tier: SubscriptionTier.pro,
    name: 'Pro 專業版',
    description: '完整功能，無限制使用',
    maxMessages: -1, // -1 表示無限制
    maxCategories: -1,
    hasCloudSync: true,
    hasAdvancedNotifications: true,
    hasMultipleTimezones: true,
    hasDataExport: true,
    hasCustomThemes: true,
    hasAdsRemoved: true,
    price: 'NT\$120/月',
    productId: 'timed_messenger_pro_monthly',
  );

  // 獲取所有方案列表
  static List<SubscriptionPlan> get allPlans => [free, lite, plus, pro];

  // 根據等級獲取方案
  static SubscriptionPlan getPlan(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.free:
        return free;
      case SubscriptionTier.lite:
        return lite;
      case SubscriptionTier.plus:
        return plus;
      case SubscriptionTier.pro:
        return pro;
    }
  }

  // 檢查是否有權限
  bool get isUnlimitedMessages => maxMessages == -1;
  bool get isUnlimitedCategories => maxCategories == -1;

  // 方便比較等級高低
  int get tierLevel {
    switch (tier) {
      case SubscriptionTier.free:
        return 0;
      case SubscriptionTier.lite:
        return 1;
      case SubscriptionTier.plus:
        return 2;
      case SubscriptionTier.pro:
        return 3;
    }
  }

  bool isHigherThan(SubscriptionTier other) {
    return tierLevel > getPlan(other).tierLevel;
  }

  bool isAtLeast(SubscriptionTier required) {
    return tierLevel >= getPlan(required).tierLevel;
  }
}
