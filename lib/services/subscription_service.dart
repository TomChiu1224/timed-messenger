import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // ✅ 白名單狀態
  bool _isSpecialAccount = false;
  String _specialAccountType = '';
  int _discountPercent = 0;
  DateTime? _trialExpireAt;

  static const Set<String> _productIds = {
    'timed_messenger_lite_monthly',
    'timed_messenger_plus_monthly',
    'timed_messenger_pro_monthly',
  };

  final _tierController = StreamController<SubscriptionTier>.broadcast();
  Stream<SubscriptionTier> get tierStream => _tierController.stream;

  SubscriptionTier get currentTier => _currentTier;
  SubscriptionPlan get currentPlan => SubscriptionPlan.getPlan(_currentTier);
  bool get isInitialized => _isInitialized;
  List<ProductDetails> get products => _products;

  bool get isSpecialAccount => _isSpecialAccount;
  String get specialAccountType => _specialAccountType;
  int get discountPercent => _discountPercent;
  DateTime? get trialExpireAt => _trialExpireAt;

  /// 白名單是否仍然有效（trial 有可能已過期）
  bool get isSpecialAccountActive {
    if (!_isSpecialAccount) return false;
    if (_specialAccountType == 'trial') {
      if (_trialExpireAt == null) return false;
      return DateTime.now().isBefore(_trialExpireAt!);
    }
    return true;
  }

  /// 到期日提示文字（給 UI 顯示用）
  String get specialAccountLabel {
    if (!_isSpecialAccount) return '';
    switch (_specialAccountType) {
      case 'free':
        return '🎁 永久免費帳號';
      case 'pro':
        return '⭐ Pro 贈送帳號';
      case 'trial':
        if (_trialExpireAt == null) return '🕐 試用帳號（無到期日）';
        final now = DateTime.now();
        if (now.isAfter(_trialExpireAt!)) return '⚠️ 試用已到期';
        final days = _trialExpireAt!.difference(now).inDays;
        return '🕐 試用帳號（還有 $days 天）';
      case 'discount':
        return '💰 優惠帳號（${_discountPercent}% off）';
      default:
        return '✅ 特殊帳號';
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // ✅ 優先檢查白名單
      await _checkSpecialAccount();

      final available = await _iap.isAvailable();
      if (!available) {
        debugPrint('⚠️ 應用內購買不可用');
        await _loadLocalTier();
        _isInitialized = true;
        return;
      }

      await _loadProducts();

      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription.cancel(),
        onError: (error) => debugPrint('❌ 購買流錯誤: $error'),
      );

      await _restorePurchases();

      _isInitialized = true;
      debugPrint('✅ 訂閱服務初始化完成');
    } catch (e) {
      debugPrint('❌ 訂閱服務初始化失敗: $e');
      await _loadLocalTier();
      _isInitialized = true;
    }
  }

  // ✅ 檢查白名單，並讀取 type / expireAt / discount
  Future<void> _checkSpecialAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isSpecialAccount = false;
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('special_accounts')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        _isSpecialAccount = false;
        debugPrint('ℹ️ 一般帳號：${user.email}');
        return;
      }

      final data = doc.data()!;
      _isSpecialAccount = true;
      _specialAccountType = data['type'] ?? 'free';

      // 讀取到期日（trial 用）
      if (data['expireAt'] != null) {
        _trialExpireAt = (data['expireAt'] as Timestamp).toDate();
      }

      // 讀取折扣（discount 用）
      if (data['discount'] != null) {
        _discountPercent = data['discount'] as int;
      }

      debugPrint(
          '✅ 特殊帳號：$_specialAccountType（${user.email}）$specialAccountLabel');
    } catch (e) {
      debugPrint('⚠️ 白名單檢查失敗（忽略）: $e');
      _isSpecialAccount = false;
    }
  }

  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(_productIds);
      if (response.error != null) {
        debugPrint('❌ 加載產品資訊失敗: ${response.error}');
        return;
      }
      _products = response.productDetails;
      debugPrint('✅ 已加載 ${_products.length} 個產品');
    } catch (e) {
      debugPrint('❌ 加載產品資訊錯誤: $e');
    }
  }

  Future<bool> purchase(String productId) async {
    if (!_isInitialized) return false;
    try {
      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('找不到產品: $productId'),
      );
      final purchaseParam = PurchaseParam(productDetails: product);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('❌ 購買失敗: $e');
      return false;
    }
  }

  Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        await _verifyPurchase(purchaseDetails);
      }
      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

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
        return;
      }
      await _setTier(newTier);
    } catch (e) {
      debugPrint('❌ 驗證購買失敗: $e');
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('❌ 恢復購買失敗: $e');
    }
  }

  Future<void> restorePurchases() async {
    await _restorePurchases();
  }

  Future<void> _setTier(SubscriptionTier tier) async {
    _currentTier = tier;
    _tierController.add(tier);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('subscription_tier', tier.index);
  }

  Future<void> _loadLocalTier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tierIndex = prefs.getInt('subscription_tier') ?? 0;
      _currentTier = SubscriptionTier.values[tierIndex];
      _tierController.add(_currentTier);
    } catch (e) {
      _currentTier = SubscriptionTier.free;
    }
  }

  // ✅ 權限檢查：依照 type 決定解禁程度
  bool get _isFullyUnlocked {
    if (!isSpecialAccountActive) return false;
    // discount 帳號只有折扣，功能不解禁
    if (_specialAccountType == 'discount') return false;
    return true;
  }

  bool canAddMessage(int currentCount) {
    if (_isFullyUnlocked) return true;
    final plan = currentPlan;
    if (plan.isUnlimitedMessages) return true;
    return currentCount < plan.maxMessages;
  }

  bool canAddCategory(int currentCount) {
    if (_isFullyUnlocked) return true;
    final plan = currentPlan;
    if (plan.isUnlimitedCategories) return true;
    return currentCount < plan.maxCategories;
  }

  bool hasFeature(String featureName) {
    if (_isFullyUnlocked) return true;
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

  void dispose() {
    _subscription.cancel();
    _tierController.close();
  }
}
