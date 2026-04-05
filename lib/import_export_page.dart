import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'models/task_category.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'models/scheduled_message.dart';
import 'database_helper.dart';

/// ✅ 匯入匯出功能頁面
class ImportExportPage extends StatefulWidget {
  const ImportExportPage({super.key});

  @override
  State<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends State<ImportExportPage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  bool _isProcessing = false;
  String _statusMessage = '';

  /// 匯出為JSON格式
  Future<void> _exportToJSON() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在匯出JSON檔案...';
    });

    try {
      // 獲取所有排程資料
      final messages = await _databaseHelper.getAllMessages();
      final categories = await _databaseHelper.getAllCategories();

      // 建立匯出資料結構
      final exportData = {
        'version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'total_messages': messages.length,
        'total_categories': categories.length,
        'messages': messages,
        'categories': categories.map((cat) => cat.toMap()).toList(),
      };

      // 轉換為JSON
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      // 生成檔案名稱
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '愛傳時_排程備份_$timestamp.json';

      // 儲存檔案
      await _saveFile(jsonString, fileName, 'application/json');

      setState(() {
        _statusMessage = '✅ JSON匯出成功！共匯出 ${messages.length} 個排程';
      });

    } catch (e) {
      setState(() {
        _statusMessage = '❌ JSON匯出失敗: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// 匯出為CSV格式
  Future<void> _exportToCSV() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在匯出CSV檔案...';
    });

    try {
      // 獲取所有排程資料
      final messages = await _databaseHelper.getAllMessages();
      final categories = await _databaseHelper.getAllCategories();

      // 建立分類對照表
      final categoryMap = <int, String>{};
      for (var cat in categories) {
        if (cat.id != null) {
          categoryMap[cat.id!] = cat.name;
        }
      }

      // 建立CSV標題行
      final csvLines = <String>[];
      csvLines.add([
        'ID',
        '訊息內容',
        '觸發時間',
        '已發送',
        '重複模式',
        '重複天數',
        '重複次數',
        '目前次數',
        '開始日期',
        '結束日期',
        '目標時區',
        '時區名稱',
        '分類',
        '標籤',
        '音效啟用',
        '音效類型',
        '音效音量',
        '震動啟用',
        '震動模式',
        '震動強度',
      ].map((field) => '"$field"').join(','));

      // 轉換每個排程為CSV行
      for (var msgMap in messages) {
        final msg = ScheduledMessage.fromMap(msgMap);
        final categoryName = msg.categoryId != null ? categoryMap[msg.categoryId] ?? '未分類' : '無分類';

        csvLines.add([
          msg.id?.toString() ?? '',
          msg.message.replaceAll('"', '""'), // 轉義雙引號
          DateFormat('yyyy-MM-dd HH:mm:ss').format(msg.time),
          msg.sent ? '是' : '否',
          _getRepeatTypeText(msg.repeatType),
          msg.repeatDays.join(';'),
          msg.repeatCount.toString(),
          msg.currentCount.toString(),
          msg.startDate != null ? DateFormat('yyyy-MM-dd').format(msg.startDate!) : '',
          msg.endDate != null ? DateFormat('yyyy-MM-dd').format(msg.endDate!) : '',
          msg.targetTimeZone,
          msg.targetTimeZoneName,
          categoryName,
          msg.tags.join(';'),
          msg.soundEnabled ? '是' : '否',
          msg.soundPath,
          msg.soundVolume.toString(),
          msg.vibrationEnabled ? '是' : '否',
          msg.vibrationPattern,
          msg.vibrationIntensity.toString(),
        ].map((field) => '"$field"').join(','));
      }

      final csvContent = csvLines.join('\n');

      // 加入BOM以支援Excel正確顯示中文
      final csvWithBOM = '\uFEFF' + csvContent;

      // 生成檔案名稱
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = '愛傳時_排程清單_$timestamp.csv';

      // 儲存檔案
      await _saveFile(csvWithBOM, fileName, 'text/csv');

      setState(() {
        _statusMessage = '✅ CSV匯出成功！共匯出 ${messages.length} 個排程';
      });

    } catch (e) {
      setState(() {
        _statusMessage = '❌ CSV匯出失敗: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// 複製到剪貼板
  Future<void> _copyToClipboard() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在複製到剪貼板...';
    });

    try {
      // 獲取所有排程資料
      final messages = await _databaseHelper.getAllMessages();
      final categories = await _databaseHelper.getAllCategories();

      // 建立分類對照表
      final categoryMap = <int, String>{};
      for (var cat in categories) {
        if (cat.id != null) {
          categoryMap[cat.id!] = cat.name;
        }
      }

      // 建立文字格式的排程列表
      final textLines = <String>[];
      textLines.add('愛傳時 排程清單 - ${DateFormat('yyyy年MM月dd日 HH:mm').format(DateTime.now())}');
      textLines.add('=' * 50);
      textLines.add('總排程數：${messages.length}');
      textLines.add('');

      // 按分類分組
      final messagesByCategory = <String, List<ScheduledMessage>>{};
      for (var msgMap in messages) {
        final msg = ScheduledMessage.fromMap(msgMap);
        final categoryName = msg.categoryId != null ? categoryMap[msg.categoryId] ?? '未分類' : '無分類';

        if (!messagesByCategory.containsKey(categoryName)) {
          messagesByCategory[categoryName] = [];
        }
        messagesByCategory[categoryName]!.add(msg);
      }

      // 輸出每個分類的排程
      for (var entry in messagesByCategory.entries) {
        textLines.add('【${entry.key}】(${entry.value.length}個)');
        textLines.add('-' * 30);

        for (var msg in entry.value) {
          textLines.add('• ${msg.message}');
          textLines.add('  時間：${DateFormat('yyyy/MM/dd HH:mm').format(msg.time)}');
          textLines.add('  狀態：${msg.sent ? "已發送" : "待發送"}');
          if (msg.repeatType != 'none') {
            textLines.add('  重複：${_getRepeatTypeText(msg.repeatType)}');
          }
          if (msg.tags.isNotEmpty) {
            textLines.add('  標籤：${msg.tags.join(', ')}');
          }
          textLines.add('');
        }
        textLines.add('');
      }

      textLines.add('由愛傳時APP匯出 - ${DateTime.now().toIso8601String()}');

      final textContent = textLines.join('\n');

      // 複製到剪貼板
      await Clipboard.setData(ClipboardData(text: textContent));

      setState(() {
        _statusMessage = '✅ 已複製到剪貼板！共 ${messages.length} 個排程';
      });

      // 顯示預覽對話框
      _showClipboardPreview(textContent);

    } catch (e) {
      setState(() {
        _statusMessage = '❌ 複製失敗: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// 顯示剪貼板預覽
  void _showClipboardPreview(String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('剪貼板內容預覽'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('關閉'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Share.share(content, subject: '愛傳時 排程清單');
            },
            child: const Text('分享'),
          ),
        ],
      ),
    );
  }

  /// 從JSON匯入
  Future<void> _importFromJSON() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = '正在選擇JSON檔案...';
    });

    try {
      // 選擇檔案
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();

        setState(() {
          _statusMessage = '正在解析JSON資料...';
        });

        // 解析JSON
        final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

        // 驗證檔案格式
        if (!jsonData.containsKey('messages')) {
          throw Exception('無效的JSON格式：缺少messages欄位');
        }

        final messages = jsonData['messages'] as List;
        final categories = jsonData['categories'] as List? ?? [];

        // 詢問匯入方式
        final importMode = await _showImportModeDialog(messages.length, categories.length);
        if (importMode == null) return;

        setState(() {
          _statusMessage = '正在匯入資料...';
        });

        int importedMessages = 0;
        int importedCategories = 0;

        // 匯入分類（如果有）
        if (categories.isNotEmpty) {
          for (var catData in categories) {
            try {
              final category = TaskCategory.fromMap(catData as Map<String, dynamic>);
              // 檢查分類是否已存在
              final existingCategories = await _databaseHelper.getAllCategories();
              final exists = existingCategories.any((cat) => cat.name == category.name);

              if (!exists || importMode == 'replace') {
                await _databaseHelper.insertCategory(category.copyWith(id: null));
                importedCategories++;
              }
            } catch (e) {
              print('匯入分類失敗: $e');
            }
          }
        }

        // 匯入排程
        if (importMode == 'replace') {
          await _databaseHelper.deleteAllMessages();
        }

        for (var msgData in messages) {
          try {
            final messageMap = msgData as Map<String, dynamic>;
            messageMap.remove('id'); // 移除原始ID，讓資料庫自動分配新ID
            await _databaseHelper.insertMessage(messageMap);
            importedMessages++;
          } catch (e) {
            print('匯入排程失敗: $e');
          }
        }

        setState(() {
          _statusMessage = '✅ 匯入完成！排程：$importedMessages 個，分類：$importedCategories 個';
        });

        // 顯示結果對話框
        _showImportResultDialog(importedMessages, importedCategories);

      } else {
        setState(() {
          _statusMessage = '取消選擇檔案';
        });
      }

    } catch (e) {
      setState(() {
        _statusMessage = '❌ JSON匯入失敗: $e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// 顯示匯入模式選擇對話框
  Future<String?> _showImportModeDialog(int messageCount, int categoryCount) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選擇匯入模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即將匯入：'),
            Text('• 排程：$messageCount 個'),
            Text('• 分類：$categoryCount 個'),
            const SizedBox(height: 16),
            const Text('請選擇匯入模式：'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'append'),
            child: const Text('新增模式', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            child: const Text('替換模式', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 顯示匯入結果對話框
  void _showImportResultDialog(int messageCount, int categoryCount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ 匯入完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('成功匯入：'),
            Text('• 排程：$messageCount 個'),
            Text('• 分類：$categoryCount 個'),
            const SizedBox(height: 16),
            const Text('建議重新啟動應用程式以確保資料正確載入。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  /// 儲存檔案
  Future<void> _saveFile(String content, String fileName, String mimeType) async {
    try {
      // 獲取文件目錄
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      // 寫入檔案
      await file.writeAsString(content, encoding: utf8);

      // 分享檔案
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: fileName,
        text: '愛傳時APP資料匯出',
      );

    } catch (e) {
      throw Exception('儲存檔案失敗: $e');
    }
  }

  /// 轉換重複類型為中文
  String _getRepeatTypeText(String repeatType) {
    switch (repeatType) {
      case 'none': return '不重複';
      case 'daily': return '每日';
      case 'weekly': return '每週';
      case 'weekdays': return '平日';
      case 'monthly': return '每月';
      case 'monthlyDates': return '每月指定日期';
      case 'monthlyOrdinal': return '每月第N個星期X';
      case 'yearly': return '每年';
      case 'interval': return '自訂間隔';
      case 'custom': return '自訂次數';
      default: return repeatType;
    }
  }

  /// 建立功能卡片
  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Card(
      elevation: enabled ? 3 : 1,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: enabled ? color : Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: enabled ? Colors.black : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('匯入匯出'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 狀態訊息
            if (_statusMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _statusMessage.startsWith('✅') ? Colors.green.shade50 :
                  _statusMessage.startsWith('❌') ? Colors.red.shade50 :
                  Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _statusMessage.startsWith('✅') ? Colors.green :
                    _statusMessage.startsWith('❌') ? Colors.red :
                    Colors.blue,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.startsWith('✅') ? Colors.green.shade800 :
                    _statusMessage.startsWith('❌') ? Colors.red.shade800 :
                    Colors.blue.shade800,
                  ),
                ),
              ),

            // 匯出功能
            const Text(
              '匯出功能',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Expanded(
              flex: 2,
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildFeatureCard(
                    title: 'JSON備份',
                    description: '完整備份所有資料\n包含分類和設定',
                    icon: Icons.backup,
                    color: Colors.blue,
                    onTap: _exportToJSON,
                    enabled: !_isProcessing,
                  ),
                  _buildFeatureCard(
                    title: 'CSV匯出',
                    description: '匯出為表格格式\n可在Excel開啟',
                    icon: Icons.table_chart,
                    color: Colors.green,
                    onTap: _exportToCSV,
                    enabled: !_isProcessing,
                  ),
                  _buildFeatureCard(
                    title: '複製清單',
                    description: '複製到剪貼板\n方便分享和檢視',
                    icon: Icons.content_copy,
                    color: Colors.orange,
                    onTap: _copyToClipboard,
                    enabled: !_isProcessing,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 匯入功能
            const Text(
              '匯入功能',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Expanded(
              flex: 1,
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildFeatureCard(
                    title: 'JSON匯入',
                    description: '從備份檔案還原資料',
                    icon: Icons.restore,
                    color: Colors.purple,
                    onTap: _importFromJSON,
                    enabled: !_isProcessing,
                  ),
                ],
              ),
            ),

            // 載入中指示器
            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),

            // 使用說明
            Card(
              color: Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '使用說明',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('• JSON備份：完整保存所有排程和分類資料，建議定期備份'),
                    const Text('• CSV匯出：可在Excel等軟體開啟，方便資料分析'),
                    const Text('• 複製清單：快速分享排程內容給他人'),
                    const Text('• JSON匯入：可選擇「新增」或「替換」模式還原資料'),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ 替換模式會清空現有資料，請謹慎使用',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w500,
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