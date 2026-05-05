import 'package:flutter/material.dart';
import 'models/task_category.dart';
import 'package:intl/intl.dart';
import 'database_helper.dart';
import 'services/theme_manager.dart';

/// ✅ 任務分類管理頁面
class TaskCategoryPage extends StatefulWidget {
  const TaskCategoryPage({super.key});

  @override
  State<TaskCategoryPage> createState() => _TaskCategoryPageState();
}

class _TaskCategoryPageState extends State<TaskCategoryPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<TaskCategory> _categories = [];
  Map<int, Map<String, dynamic>> _categoryStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  /// 載入所有分類和統計資訊
  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _databaseHelper.getAllCategories();
      final stats = <int, Map<String, dynamic>>{};

      // 為每個分類載入統計資訊
      for (var category in categories) {
        if (category.id != null) {
          final categoryStats =
              await _databaseHelper.getCategoryUsageStats(category.id!);
          stats[category.id!] = categoryStats;
        }
      }

      setState(() {
        _categories = categories;
        _categoryStats = stats;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ 載入分類失敗: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 顯示新增/編輯分類對話框
  void _showCategoryDialog({TaskCategory? category}) {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    final descriptionController =
        TextEditingController(text: category?.description ?? '');
    Color selectedColor = category?.color ?? Colors.blue;
    IconData selectedIcon = category?.icon ?? Icons.category;

    // 可選顏色
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.brown,
      Colors.cyan,
      Colors.lime,
      Colors.deepOrange,
      Colors.deepPurple,
      Colors.blueGrey,
    ];

    // 可選圖示
    final icons = [
      Icons.work,
      Icons.person,
      Icons.favorite,
      Icons.school,
      Icons.sports_esports,
      Icons.home,
      Icons.attach_money,
      Icons.category,
      Icons.shopping_cart,
      Icons.fitness_center,
      Icons.restaurant,
      Icons.local_hospital,
      Icons.directions_car,
      Icons.flight,
      Icons.beach_access,
      Icons.pets,
      Icons.music_note,
      Icons.camera_alt,
      Icons.book,
      Icons.computer,
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '編輯分類' : '新增分類'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 分類名稱
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '分類名稱',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 分類描述
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: '分類描述',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // 顏色選擇
                  const Text('選擇顏色',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors.map((color) {
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: selectedColor == color
                                ? Border.all(color: Colors.black, width: 3)
                                : null,
                          ),
                          child: selectedColor == color
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // 圖示選擇
                  const Text('選擇圖示',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: icons.length,
                      itemBuilder: (context, index) {
                        final icon = icons[index];
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: selectedIcon == icon
                                  ? selectedColor.withOpacity(0.3)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: selectedIcon == icon
                                  ? Border.all(color: selectedColor, width: 2)
                                  : Border.all(color: Colors.grey.shade300),
                            ),
                            child: Icon(
                              icon,
                              color: selectedIcon == icon
                                  ? selectedColor
                                  : Colors.grey.shade600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // 預覽
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(selectedIcon, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nameController.text.isNotEmpty
                                    ? nameController.text
                                    : '分類名稱預覽',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                descriptionController.text.isNotEmpty
                                    ? descriptionController.text
                                    : '分類描述預覽',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請輸入分類名稱')),
                  );
                  return;
                }

                try {
                  final newCategory = TaskCategory(
                    id: category?.id,
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim(),
                    colorValue: selectedColor.value, // ✅ .value
                    iconData: selectedIcon.codePoint
                        .toString(), // ✅ .codePoint.toString()
                    createdAt: category?.createdAt ?? DateTime.now(),
                    isDefault: category?.isDefault ?? false,
                  );

                  if (isEditing) {
                    await _databaseHelper.updateCategory(
                        category.id!, newCategory);
                  } else {
                    await _databaseHelper.insertCategory(newCategory);
                  }

                  Navigator.pop(context);
                  _loadCategories();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEditing ? '分類已更新' : '分類已新增')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('操作失敗: $e')),
                  );
                }
              },
              child: Text(isEditing ? '更新' : '新增'),
            ),
          ],
        ),
      ),
    );
  }

  /// 刪除分類
  void _deleteCategory(TaskCategory category) {
    if (category.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('無法刪除預設分類')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認刪除'),
        content: Text('確定要刪除「${category.name}」分類嗎？\n\n使用此分類的所有排程將會變為無分類狀態。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _databaseHelper.deleteCategory(category.id!);
                Navigator.pop(context);
                _loadCategories();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分類已刪除')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('刪除失敗: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('刪除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// 查看分類詳情
  void _viewCategoryDetails(TaskCategory category) async {
    final messages = await _databaseHelper.getMessagesByCategory(category.id!);

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
              Text(category.description,
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),

              // 統計資訊
              if (_categoryStats.containsKey(category.id))
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('總任務數'),
                          Text(
                              '${_categoryStats[category.id]!['total_tasks']}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('已完成'),
                          Text(
                              '${_categoryStats[category.id]!['completed_tasks']}'),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('完成率'),
                          Text(
                              '${_categoryStats[category.id]!['completion_rate']}%'),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              const Text('相關排程', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

              // 排程列表
              Expanded(
                child: messages.isEmpty
                    ? const Center(
                        child: Text('此分類尚無排程',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.builder(
                        itemCount: messages.length,
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
                            ),
                            subtitle: Text(
                              DateFormat('yyyy/MM/dd HH:mm')
                                  .format(message.time),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分類管理'),
        backgroundColor: ThemeManager().currentColors['primary'] as Color,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCategoryDialog(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('尚無分類', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final stats = _categoryStats[category.id];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: category.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(category.icon, color: Colors.white),
                        ),
                        title: Row(
                          children: [
                            Text(
                              category.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (category.isDefault) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '預設',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.blue),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(category.description),
                            if (stats != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '任務數: ${stats['total_tasks']} | 完成率: ${stats['completion_rate']}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: ListTile(
                                leading: Icon(Icons.visibility),
                                title: Text('查看詳情'),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            if (!category.isDefault)
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  leading: Icon(Icons.edit),
                                  title: Text('編輯'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            if (!category.isDefault)
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                  leading:
                                      Icon(Icons.delete, color: Colors.red),
                                  title: Text('刪除',
                                      style: TextStyle(color: Colors.red)),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'view':
                                _viewCategoryDetails(category);
                                break;
                              case 'edit':
                                _showCategoryDialog(category: category);
                                break;
                              case 'delete':
                                _deleteCategory(category);
                                break;
                            }
                          },
                        ),
                        onTap: () => _viewCategoryDetails(category),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(),
        backgroundColor: ThemeManager().currentColors['primary'] as Color,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ), // FloatingActionButton
    ); // Scaffold
  }
}
