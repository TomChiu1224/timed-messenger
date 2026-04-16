import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/task_category.dart';
import 'models/scheduled_message.dart';

/// ✅ SQLite 資料庫助手類別 - 支援分類功能的完整版
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'scheduled_messages.db');
    return await openDatabase(
      path,
      version: 6, // ✅ 版本號更新為6（加入收件人支援）
      onCreate: _createDb,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE scheduled_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT NOT NULL,
        time INTEGER NOT NULL,
        sent INTEGER DEFAULT 0,
        repeat_type TEXT DEFAULT 'none',
        repeat_days TEXT,
        repeat_months TEXT,
        repeat_dates TEXT,
        repeat_monthly_ordinal INTEGER DEFAULT 0,
        repeat_monthly_weekday INTEGER DEFAULT 0,
        repeat_interval INTEGER DEFAULT 1,
        repeat_interval_unit TEXT DEFAULT 'days',
        repeat_count INTEGER DEFAULT 0,
        current_count INTEGER DEFAULT 0,
        start_date INTEGER,
        end_date INTEGER,
        target_timezone TEXT DEFAULT 'Asia/Taipei',
        target_timezone_name TEXT DEFAULT '台灣時間',
        sound_enabled INTEGER DEFAULT 1,
        sound_type TEXT DEFAULT 'system',
        sound_path TEXT DEFAULT 'notification',
        sound_volume REAL DEFAULT 0.8,
        sound_repeat INTEGER DEFAULT 1,
        vibration_enabled INTEGER DEFAULT 1,
        vibration_pattern TEXT DEFAULT 'short',
        vibration_intensity REAL DEFAULT 0.8,
        vibration_repeat INTEGER DEFAULT 1,
        category_id INTEGER,
        tags TEXT DEFAULT '',
        receiver_id TEXT,
        receiver_name TEXT,
        FOREIGN KEY (category_id) REFERENCES task_categories (id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE task_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT DEFAULT '',
        color_value INTEGER NOT NULL,
        icon_data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_default INTEGER DEFAULT 0
      )
    ''');

    await _insertDefaultCategories(db);
    print('✅ 資料庫建立完成（含收件人支援）');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 資料庫升級：從版本 $oldVersion 到 $newVersion');

    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN target_timezone TEXT DEFAULT "Asia/Taipei"');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN target_timezone_name TEXT DEFAULT "台灣時間"');
      print('✅ 升級至版本2：新增時區支援');
    }

    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN sound_enabled INTEGER DEFAULT 1');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN sound_type TEXT DEFAULT "system"');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN sound_path TEXT DEFAULT "notification"');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN sound_volume REAL DEFAULT 0.8');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN sound_repeat INTEGER DEFAULT 1');
      print('✅ 升級至版本3：新增音效支援');
    }

    if (oldVersion < 4) {
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN vibration_enabled INTEGER DEFAULT 1');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN vibration_pattern TEXT DEFAULT "short"');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN vibration_intensity REAL DEFAULT 0.8');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN vibration_repeat INTEGER DEFAULT 1');
      print('✅ 升級至版本4：新增震動支援');
    }

    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS task_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL UNIQUE,
          description TEXT DEFAULT '',
          color_value INTEGER NOT NULL,
          icon_data TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_default INTEGER DEFAULT 0
        )
      ''');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN category_id INTEGER');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN tags TEXT DEFAULT ""');
      await _insertDefaultCategories(db);
      print('✅ 升級至版本5：新增分類支援');
    }

    // ✅ 版本5到6：收件人支援
    if (oldVersion < 6) {
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN receiver_id TEXT');
      await db.execute(
          'ALTER TABLE scheduled_messages ADD COLUMN receiver_name TEXT');
      print('✅ 升級至版本6：新增收件人支援');
    }
  }

  Future<void> _insertDefaultCategories(Database db) async {
    final defaultCategories = DefaultCategories.all;
    for (var category in defaultCategories) {
      try {
        await db.insert('task_categories', category.toMap());
      } catch (e) {
        print('⚠️ 插入預設分類失敗: ${category.name} - $e');
      }
    }
    print('✅ 預設分類插入完成');
  }

  Future<int> insertMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert('scheduled_messages', message);
  }

  Future<List<Map<String, dynamic>>> getAllMessages() async {
    final db = await database;
    return await db.query('scheduled_messages', orderBy: 'time ASC');
  }

  Future<int> updateMessage(int id, Map<String, dynamic> message) async {
    final db = await database;
    return await db.update(
      'scheduled_messages',
      message,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMessage(int id) async {
    final db = await database;
    return await db.delete(
      'scheduled_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllMessages() async {
    final db = await database;
    return await db.delete('scheduled_messages');
  }

  Future<List<TaskCategory>> getAllCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'task_categories',
      orderBy: 'name ASC',
    );
    return maps.map((map) => TaskCategory.fromMap(map)).toList();
  }

  Future<int> insertCategory(TaskCategory category) async {
    final db = await database;
    return await db.insert('task_categories', category.toMap());
  }

  Future<int> updateCategory(int id, TaskCategory category) async {
    final db = await database;
    return await db.update(
      'task_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    await db.update(
      'scheduled_messages',
      {'category_id': null},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'task_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<ScheduledMessage>> getMessagesByCategory(int categoryId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scheduled_messages',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'time ASC',
    );
    return maps.map((map) => ScheduledMessage.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>> getCategoryUsageStats(int categoryId) async {
    final db = await database;
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scheduled_messages WHERE category_id = ?',
      [categoryId],
    );
    final totalTasks = totalResult.first['count'] as int;
    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scheduled_messages WHERE category_id = ? AND sent = 1',
      [categoryId],
    );
    final completedTasks = completedResult.first['count'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final activeResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scheduled_messages WHERE category_id = ? AND sent = 0 AND time > ?',
      [categoryId, now],
    );
    final activeTasks = activeResult.first['count'] as int;
    final repeatingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scheduled_messages WHERE category_id = ? AND repeat_type != ?',
      [categoryId, 'none'],
    );
    final repeatingTasks = repeatingResult.first['count'] as int;
    final completionRate =
        totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;
    return {
      'total_tasks': totalTasks,
      'completed_tasks': completedTasks,
      'active_tasks': activeTasks,
      'repeating_tasks': repeatingTasks,
      'completion_rate': completionRate,
    };
  }

  Future<List<String>> getAllTags() async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT DISTINCT tags FROM scheduled_messages WHERE tags IS NOT NULL AND tags != ""');
    Set<String> allTags = {};
    for (var row in result) {
      final tagsString = row['tags'] as String?;
      if (tagsString != null && tagsString.isNotEmpty) {
        final tags = tagsString
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty);
        allTags.addAll(tags);
      }
    }
    return allTags.toList()..sort();
  }

  Future<Map<String, dynamic>> getOverallStats() async {
    final db = await database;
    final totalResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM scheduled_messages');
    final totalTasks = totalResult.first['count'] as int;
    final completedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scheduled_messages WHERE sent = 1');
    final completedTasks = completedResult.first['count'] as int;
    final pendingTasks = totalTasks - completedTasks;
    final completionRate =
        totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;
    final repeatResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scheduled_messages WHERE repeat_type != "none"');
    final repeatTasks = repeatResult.first['count'] as int;
    final timezoneResult = await db.rawQuery('''
      SELECT target_timezone, target_timezone_name, COUNT(*) as count 
      FROM scheduled_messages 
      GROUP BY target_timezone, target_timezone_name 
      ORDER BY count DESC
    ''');
    return {
      'total_messages': totalTasks,
      'sent_messages': completedTasks,
      'active_messages': pendingTasks,
      'completion_rate': completionRate,
      'repeating_messages': repeatTasks,
      'timezone_stats': timezoneResult,
    };
  }

  Future<Map<String, dynamic>> getStatsInDateRange(
      DateTime startDate, DateTime endDate) async {
    final db = await database;
    final startMs = startDate.millisecondsSinceEpoch;
    final endMs = endDate.millisecondsSinceEpoch;
    final totalResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scheduled_messages WHERE time >= ? AND time <= ?',
      [startMs, endMs],
    );
    final totalTasks = totalResult.first['count'] as int;
    final completedResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM scheduled_messages WHERE time >= ? AND time <= ? AND sent = 1',
      [startMs, endMs],
    );
    final completedTasks = completedResult.first['count'] as int;
    final categoriesResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT category_id) as count FROM scheduled_messages WHERE time >= ? AND time <= ? AND category_id IS NOT NULL',
      [startMs, endMs],
    );
    final categoriesUsed = categoriesResult.first['count'] as int;
    return {
      'total': totalTasks,
      'completed': completedTasks,
      'categories_used': categoriesUsed,
    };
  }

  Future<List<Map<String, dynamic>>> getDailyStats({int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    List<Map<String, dynamic>> dailyStats = [];
    for (int i = 0; i < days; i++) {
      final date = startDate.add(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
      final stats = await getStatsInDateRange(dayStart, dayEnd);
      stats['date'] = dayStart.toIso8601String();
      dailyStats.add(stats);
    }
    return dailyStats;
  }

  Future<List<Map<String, dynamic>>> getCategoryStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        tc.id,
        tc.name,
        tc.color_value,
        tc.icon_data,
        COUNT(sm.id) as total_tasks,
        SUM(CASE WHEN sm.sent = 1 THEN 1 ELSE 0 END) as completed_tasks
      FROM task_categories tc
      LEFT JOIN scheduled_messages sm ON tc.id = sm.category_id
      GROUP BY tc.id, tc.name, tc.color_value, tc.icon_data
      ORDER BY total_tasks DESC
    ''');
    return result.map((row) {
      final totalTasks = row['total_tasks'] as int;
      final completedTasks = row['completed_tasks'] as int;
      final completionRate =
          totalTasks > 0 ? ((completedTasks / totalTasks) * 100).round() : 0;
      return {
        'category_id': row['id'],
        'category_name': row['name'],
        'color_value': row['color_value'],
        'icon_data': row['icon_data'],
        'total_tasks': totalTasks,
        'completed_tasks': completedTasks,
        'completion_rate': completionRate,
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getMessagesByTimeZone(
      String timeZone) async {
    final db = await database;
    return await db.query(
      'scheduled_messages',
      where: 'target_timezone = ?',
      whereArgs: [timeZone],
      orderBy: 'time ASC',
    );
  }

  Future<List<String>> getUsedTimeZones() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT DISTINCT target_timezone, target_timezone_name FROM scheduled_messages ORDER BY target_timezone_name');
    return result
        .map((row) =>
            '${row['target_timezone_name']} (${row['target_timezone']})')
        .toList();
  }

  Future<int> updateMessageSoundSettings(
      int id, Map<String, dynamic> soundSettings) async {
    final db = await database;
    return await db.update('scheduled_messages', soundSettings,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getMessageSoundSettings(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scheduled_messages',
      columns: [
        'sound_enabled',
        'sound_type',
        'sound_path',
        'sound_volume',
        'sound_repeat'
      ],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<int> updateMessageVibrationSettings(
      int id, Map<String, dynamic> vibrationSettings) async {
    final db = await database;
    return await db.update('scheduled_messages', vibrationSettings,
        where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>?> getMessageVibrationSettings(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scheduled_messages',
      columns: [
        'vibration_enabled',
        'vibration_pattern',
        'vibration_intensity',
        'vibration_repeat'
      ],
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<int> getEnabledSoundMessagesCount() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scheduled_messages WHERE sound_enabled = 1');
    return result.first['count'] as int;
  }

  Future<int> getEnabledVibrationMessagesCount() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM scheduled_messages WHERE vibration_enabled = 1');
    return result.first['count'] as int;
  }

  Future<String> getMostUsedSound() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT sound_path, COUNT(*) as usage_count 
      FROM scheduled_messages 
      WHERE sound_enabled = 1 
      GROUP BY sound_path 
      ORDER BY usage_count DESC 
      LIMIT 1
    ''');
    if (result.isNotEmpty) return result.first['sound_path'] as String;
    return 'notification';
  }

  Future<String> getMostUsedVibrationPattern() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT vibration_pattern, COUNT(*) as usage_count 
      FROM scheduled_messages 
      WHERE vibration_enabled = 1 
      GROUP BY vibration_pattern 
      ORDER BY usage_count DESC 
      LIMIT 1
    ''');
    if (result.isNotEmpty) return result.first['vibration_pattern'] as String;
    return 'short';
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
