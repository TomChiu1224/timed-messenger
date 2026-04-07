// ========== 訂閱服務 ==========
// 管理應用內購買、訂閱狀態和權限檢查

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/subscription_tier.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  SubscriptionTier _currentTier = SubscriptionTier.free;
  bool _isInitialized = false;
  List<ProductDetails> _products = [];

  // Product IDs
  static const Set<String> _productIds = {
    'timed_messenger_lite_monthly',
    'timed_messenger_plus_monthly',
    'timed_messenger_pro_monthly',
  };

  // 通知訂閱狀態變更
  final _tierController = StreamController<SubscriptionTier>.broadcast();
  Stream<SubscriptionTier> get tierStream => _tierController.stream;

  SubscriptionTier get currentTier => _currentTier;
  SubscriptionPlan get currentPlan => SubscriptionPlan.getPlan(_currentTier);
  bool get isInitialized => _isInitialized;
  List<ProductDetails> get products => _products;

  // 初始化服務
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 檢查應用內購買是否可用
      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('⚠️ 應用內購買不可用');
        await _loadLocalTier();
        _isInitialized = true;
        return;
      }

      // 加載產品資訊
      await _loadProducts();

      // 監聽購買更新
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription.cancel(),
        onError: (error) => debugPrint('❌ 購買流錯誤: $error'),
      );

      // 恢復之前的購買
      await _restorePurchases();

      _isInitialized = true;
      debugPrint('✅ 訂閱服務初始化完成');
    } catch (e) {
      debugPrint('❌ 訂閱服務初始化失敗: $e');
      await _loadLocalTier();
      _isInitialized = true;
    }
  }

  // 加載產品資訊
  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        debugPrint('❌ 加載產品資訊失敗: ${response.error}');
        return;
      }

      _products = response.productDetails;
      debugPrint('✅ 已加載 ${_products.length} 個產品');

      for (var product in _products) {
        debugPrint('  - ${product.id}: ${product.title} (${product.price})');
      }
    } catch (e) {
      debugPrint('❌ 加載產品資訊錯誤: $e');
    }
  }

  // 購買訂閱
  Future<bool> purchase(String productId) async {
    if (!_isInitialized) {
      debugPrint('⚠️ 訂閱服務尚未初始化');
      return false;
    }

    try {
      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('找不到產品: $productId'),
      );

      final purchaseParam = PurchaseParam(productDetails: product);
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      return success;
    } catch (e) {
      debugPrint('❌ 購買失敗: $e');
      return false;
    }
  }

  // 處理購買更新
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 驗證購買（實際應用中應該在伺服器端驗證）
        await _verifyPurchase(purchaseDetails);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  // 驗證購買
  Future<void> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    try {
      final productId = purchaseDetails.productID;
      SubscriptionTier newTier;

      if (productId == 'timed_messenger_lite_monthly') {
        newTier = SubscriptionTier.lite;
      } else if (productId == 'timed_messenger_plus_monthly') {
        newTier = SubscriptionTier.plus;
      } else if (productId == 'timed_messenger_pro_monthly') {
        newTier = SubscriptionTier.pro;
      } else {
        debugPrint('⚠️ 未知產品ID: $productId');
        return;
      }

      await _setTier(newTier);
      debugPrint('✅ 訂閱已激活: ${newTier.name}');
    } catch (e) {
      debugPrint('❌ 驗證購買失敗: $e');
    }
  }

  // 恢復購買
  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
      debugPrint('✅ 已恢復購買記錄');
    } catch (e) {
      debugPrint('❌ 恢復購買失敗: $e');
    }
  }

  // 手動恢復購買（給用戶使用）
  Future<void> restorePurchases() async {
    await _restorePurchases();
  }

  // 設定訂閱等級
  Future<void> _setTier(SubscriptionTier tier) async {
    _currentTier = tier;
    _tierController.add(tier);

    // 儲存到本地
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('subscription_tier', tier.index);
  }

  // 從本地加載訂閱等級
  Future<void> _loadLocalTier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tierIndex = prefs.getInt('subscription_tier') ?? 0;
      _currentTier = SubscriptionTier.values[tierIndex];
      _tierController.add(_currentTier);
      debugPrint('✅ 已從本地加載訂閱等級: ${_currentTier.name}');
    } catch (e) {
      debugPrint('⚠️ 加載本地訂閱等級失敗: $e');
      _currentTier = SubscriptionTier.free;
    }
  }

  // 權限檢查方法
  bool canAddMessage(int currentCount) {
    final plan = currentPlan;
    if (plan.isUnlimitedMessages) return true;
    return currentCount < plan.maxMessages;
  }

  bool canAddCategory(int currentCount) {
    final plan = currentPlan;
    if (plan.isUnlimitedCategories) return true;
    return currentCount < plan.maxCategories;
  }

  bool hasFeature(String featureName) {
    final plan = currentPlan;
    switch (featureName) {
      case 'cloud_sync':
        return plan.hasCloudSync;
      case 'advanced_notifications':
        return plan.hasAdvancedNotifications;
      case 'multiple_timezones':
        return plan.hasMultipleTimezones;
      case 'data_export':
        return plan.hasDataExport;
      case 'custom_themes':
        return plan.hasCustomThemes;
      case 'ads_removed':
        return plan.hasAdsRemoved;
      default:
        return false;
    }
  }

  String getUpgradeMessage(String featureName) {
    switch (featureName) {
      case 'cloud_sync':
        return '升級至 Plus 或 Pro 版本以使用雲端同步功能';
      case 'advanced_notifications':
        return '升級至 Lite 或更高版本以使用進階通知功能';
      case 'multiple_timezones':
        return '升級至 Plus 或 Pro 版本以使用多時區功能';
      case 'data_export':
        return '升級至 Lite 或更高版本以使用資料匯出功能';
      case 'custom_themes':
        return '升級至 Plus 或 Pro 版本以使用自訂主題功能';
      default:
        return '升級訂閱以使用此功能';
    }
  }

  // 清理資源
  void dispose() {
    _subscription.cancel();
    _tierController.close();
  }
}
