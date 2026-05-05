import 'package:flutter/material.dart';
import 'models/task_category.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'services/theme_manager.dart';

/// ✅ 統計報表頁面（已移除音效統計）
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  Map<String, dynamic> _overallStats = {};
  List<TaskCategory> _categories = [];
  Map<int, Map<String, dynamic>> _categoryStats = {};
  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  /// 載入統計資料
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 載入總體統計
      final overallStats = await _databaseHelper.getOverallStats();

      // 載入分類列表
      final categories = await _databaseHelper.getAllCategories();

      // 載入各分類統計
      final categoryStats = <int, Map<String, dynamic>>{};
      for (var category in categories) {
        if (category.id != null) {
          final stats =
              await _databaseHelper.getCategoryUsageStats(category.id!);
          categoryStats[category.id!] = stats;
        }
      }

      setState(() {
        _overallStats = overallStats;
        _categories = categories;
        _categoryStats = categoryStats;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 載入統計資料失敗: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 選擇日期範圍
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange,
    );

    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadDateRangeStats();
    }
  }

  /// 載入日期範圍統計
  Future<void> _loadDateRangeStats() async {
    if (_selectedDateRange == null) return;

    try {
      final rangeStats = await _databaseHelper.getStatsInDateRange(
        _selectedDateRange!.start,
        _selectedDateRange!.end,
      );

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('日期範圍統計'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '統計期間：${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end)}'),
              const SizedBox(height: 16),
              _buildStatRow('總任務數', '${rangeStats['total']}'),
              _buildStatRow('已完成', '${rangeStats['completed']}'),
              _buildStatRow('使用分類數', '${rangeStats['categories_used']}'),
              _buildStatRow('完成率',
                  '${rangeStats['total'] > 0 ? ((rangeStats['completed'] / rangeStats['total']) * 100).round() : 0}%'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('關閉'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('載入日期範圍統計失敗: $e')),
      );
    }
  }

  /// 建立統計行
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// 建立統計卡片
  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 建立分類統計列表
  Widget _buildCategoryStatsList() {
    if (_categories.isEmpty) {
      return const Center(
        child: Text('尚無分類資料'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final stats = _categoryStats[category.id] ?? {};
        final totalTasks = stats['total_tasks'] ?? 0;
        final completionRate = stats['completion_rate'] ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(category.icon, color: Colors.white, size: 20),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(category.description),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$totalTasks 個任務',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '完成率 $completionRate%',
                  style: TextStyle(
                    color: completionRate >= 80
                        ? Colors.green
                        : completionRate >= 50
                            ? Colors.orange
                            : Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onTap: () => _showCategoryDetails(category),
          ),
        );
      },
    );
  }

  /// 顯示分類詳情
  void _showCategoryDetails(TaskCategory category) async {
    final messages = await _databaseHelper.getMessagesByCategory(category.id!);
    final stats = _categoryStats[category.id!] ?? {};

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: category.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(category.icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(category.name),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 統計資訊
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: category.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildStatRow('總任務數', '${stats['total_tasks'] ?? 0}'),
                    _buildStatRow('已完成', '${stats['completed_tasks'] ?? 0}'),
                    _buildStatRow('進行中', '${stats['active_tasks'] ?? 0}'),
                    _buildStatRow('重複任務', '${stats['repeating_tasks'] ?? 0}'),
                    _buildStatRow('完成率', '${stats['completion_rate'] ?? 0}%'),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Text('最近任務', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 任務列表
              Expanded(
                child: messages.isEmpty
                    ? const Center(
                        child: Text('此分類尚無任務'),
                      )
                    : ListView.builder(
                        itemCount: messages.length > 10 ? 10 : messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(
                              message.sent
                                  ? Icons.check_circle
                                  : Icons.schedule,
                              color:
                                  message.sent ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            title: Text(
                              message.message,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              DateFormat('MM/dd HH:mm').format(message.time),
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }

  /// 建立時區統計圖表
  Widget _buildTimezoneStats() {
    final timezoneStats =
        _overallStats['timezone_stats'] as List<Map<String, dynamic>>? ?? [];

    if (timezoneStats.isEmpty) {
      return const Center(
        child: Text('尚無時區使用資料'),
      );
    }

    return Column(
      children: timezoneStats.map((stat) {
        final name = stat['target_timezone_name'] as String? ?? '未知時區';
        final count = stat['count'] as int? ?? 0;
        final percentage = _overallStats['total_messages'] > 0
            ? (count / _overallStats['total_messages'] * 100).round()
            : 0;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 2),
          child: ListTile(
            leading: const Icon(Icons.public, color: Colors.blue),
            title: Text(name),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$count 個',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('統計報表'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: '選擇日期範圍',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
            tooltip: '重新整理',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 總體統計卡片
                  const Text(
                    '總體統計',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: [
                      _buildStatCard(
                        title: '總排程數',
                        value: '${_overallStats['total_messages'] ?? 0}',
                        icon: Icons.schedule,
                        color: ThemeManager().currentColors['primary'] as Color,
                      ),
                      _buildStatCard(
                        title: '已發送',
                        value: '${_overallStats['sent_messages'] ?? 0}',
                        icon: Icons.check_circle,
                        color: Colors.green,
                      ),
                      _buildStatCard(
                        title: '進行中',
                        value: '${_overallStats['active_messages'] ?? 0}',
                        icon: Icons.pending,
                        color: Colors.orange,
                      ),
                      _buildStatCard(
                        title: '完成率',
                        value: '${_overallStats['completion_rate'] ?? 0}%',
                        icon: Icons.trending_up,
                        color: Colors.blue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 重複任務統計
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '重複任務統計',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildStatRow('重複任務數',
                              '${_overallStats['repeating_messages'] ?? 0}'),
                          _buildStatRow('單次任務數',
                              '${(_overallStats['total_messages'] ?? 0) - (_overallStats['repeating_messages'] ?? 0)}'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 分類統計
                  const Text(
                    '分類統計',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryStatsList(),

                  const SizedBox(height: 24),

                  // 時區統計
                  const Text(
                    '時區使用統計',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildTimezoneStats(),

                  const SizedBox(height: 24),

                  // 日期範圍查詢
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '自訂日期統計',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '點擊右上角日曆圖示選擇日期範圍，查看指定期間的統計資料。',
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          if (_selectedDateRange != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '已選擇：${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy/MM/dd').format(_selectedDateRange!.end)}',
                                style: const TextStyle(color: Colors.blue),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
