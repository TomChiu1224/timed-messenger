// ========== 訂閱管理頁面 ==========
// 顯示訂閱方案、購買和管理訂閱

import 'package:flutter/material.dart';
import 'models/subscription_tier.dart';
import 'services/subscription_service.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initSubscriptionService();
  }

  Future<void> _initSubscriptionService() async {
    setState(() => _isLoading = true);
    await _subscriptionService.initialize();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('訂閱方案'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: '恢復購買',
            onPressed: _restorePurchases,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<SubscriptionTier>(
              stream: _subscriptionService.tierStream,
              initialData: _subscriptionService.currentTier,
              builder: (context, snapshot) {
                final currentTier = snapshot.data ?? SubscriptionTier.free;
                return _buildContent(currentTier);
              },
            ),
    );
  }

  Widget _buildContent(SubscriptionTier currentTier) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 當前訂閱狀態
            _buildCurrentPlanCard(currentTier),
            const SizedBox(height: 24),

            // 訂閱方案列表
            const Text(
              '選擇您的方案',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...SubscriptionPlan.allPlans.map((plan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPlanCard(plan, currentTier),
                )),

            const SizedBox(height: 24),

            // 功能比較表
            _buildFeatureComparisonTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(SubscriptionTier currentTier) {
    final plan = SubscriptionPlan.getPlan(currentTier);
    return Card(
      color: Colors.blue.shade50,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  '目前方案',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plan.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan.description,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (plan.tier != SubscriptionTier.free) ...[
              const SizedBox(height: 8),
              Text(
                plan.price,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, SubscriptionTier currentTier) {
    final isCurrent = plan.tier == currentTier;
    final isUpgrade = plan.tierLevel > SubscriptionPlan.getPlan(currentTier).tierLevel;

    return Card(
      elevation: isCurrent ? 4 : 2,
      color: isCurrent ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: isUpgrade ? () => _purchasePlan(plan) : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.description,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        plan.price,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: plan.tier == SubscriptionTier.free
                              ? Colors.green
                              : Colors.blue.shade700,
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade700,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '目前方案',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else if (isUpgrade)
                        ElevatedButton(
                          onPressed: () => _purchasePlan(plan),
                          child: const Text('升級'),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFeatureList(plan),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList(SubscriptionPlan plan) {
    final features = <String>[];

    if (plan.maxMessages == -1) {
      features.add('無限訊息');
    } else {
      features.add('最多 ${plan.maxMessages} 則訊息');
    }

    if (plan.maxCategories == -1) {
      features.add('無限分類');
    } else {
      features.add('最多 ${plan.maxCategories} 個分類');
    }

    if (plan.hasAdsRemoved) features.add('移除廣告');
    if (plan.hasAdvancedNotifications) features.add('進階通知');
    if (plan.hasCloudSync) features.add('雲端同步');
    if (plan.hasMultipleTimezones) features.add('多時區支援');
    if (plan.hasDataExport) features.add('資料匯出');
    if (plan.hasCustomThemes) features.add('自訂主題');

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: features.map((feature) {
        return Chip(
          label: Text(
            feature,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: Colors.grey.shade200,
          padding: EdgeInsets.zero,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _buildFeatureComparisonTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '功能比較',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildComparisonRow('訊息數量', ['10', '50', '200', '無限']),
            _buildComparisonRow('分類數量', ['3', '10', '30', '無限']),
            _buildComparisonRow('移除廣告', [false, true, true, true]),
            _buildComparisonRow('進階通知', [false, true, true, true]),
            _buildComparisonRow('雲端同步', [false, false, true, true]),
            _buildComparisonRow('多時區', [false, false, true, true]),
            _buildComparisonRow('資料匯出', [false, true, true, true]),
            _buildComparisonRow('自訂主題', [false, false, true, true]),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String feature, List<dynamic> values) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              feature,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          ...values.map((value) {
            return Expanded(
              child: Center(
                child: value is bool
                    ? Icon(
                        value ? Icons.check_circle : Icons.cancel,
                        color: value ? Colors.green : Colors.grey,
                        size: 20,
                      )
                    : Text(
                        value.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _purchasePlan(SubscriptionPlan plan) async {
    if (plan.tier == SubscriptionTier.free) return;

    setState(() => _isLoading = true);

    try {
      final success = await _subscriptionService.purchase(plan.productId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '購買成功！' : '購買失敗，請稍後再試'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('購買錯誤: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isLoading = true);

    try {
      await _subscriptionService.restorePurchases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已恢復購買記錄'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('恢復購買失敗: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
