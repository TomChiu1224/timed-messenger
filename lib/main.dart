// ========== 愛傳時APP - 完整修正版 main.dart 第1段（整合音效+震動功能）==========
// ✅ 修正 UI 渲染錯誤，移除有問題的時區組件
// ✅ 完整多時區功能支援（簡化版）
// ✅ 智能驗證和衝突檢查
// ✅ Windows 桌面完全相容
// ✅ 音效控制功能完整支援
// ✅ 震動模式功能完整支援
import 'package:firebase_auth/firebase_auth.dart'; // ✅ 新增
import 'package:firebase_core/firebase_core.dart';
import 'firebase_service.dart';
import 'modules/auth/views/login_page.dart';
import 'modules/auth/services/auth_service.dart';
import 'package:timed_messenger/modules/messaging/services/messaging_service.dart'; // ← 改成完整路徑
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/audio_manager.dart'; // 之前加入的音效引用
import 'services/vibration_manager.dart'; // 新加入的震動引用
import 'models/scheduled_message.dart';
import 'models/task_category.dart';
import 'models/sound_settings.dart';
import 'models/vibration_settings.dart';

// 通知與時區（僅移動平台）
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ✅ 資料庫助手
import 'database_helper.dart';

// ✅ 剪貼板功能
import 'package:flutter/services.dart';

// ✅ 音效功能相關依賴

// ✅ 震動功能相關依賴

import 'task_category_page.dart';
import 'statistics_page.dart';
import 'import_export_page.dart';
import 'services/theme_manager.dart';

// 初始化通知插件
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();

// ✅ 簡化版時區資料（移除複雜的UI組件依賴）
class SimpleTimeZone {
  final String id;
  final String displayName;
  final String shortName;

  const SimpleTimeZone({
    required this.id,
    required this.displayName,
    required this.shortName,
  });
}

// ✅ 支援的時區列表（簡化版）
class AppTimeZones {
  static const List<SimpleTimeZone> supportedZones = [
    SimpleTimeZone(
        id: 'Asia/Taipei', displayName: '台灣時間 (GMT+8)', shortName: '台灣'),
    SimpleTimeZone(
        id: 'Asia/Tokyo', displayName: '東京時間 (GMT+9)', shortName: '東京'),
    SimpleTimeZone(
        id: 'Asia/Seoul', displayName: '首爾時間 (GMT+9)', shortName: '首爾'),
    SimpleTimeZone(
        id: 'Asia/Shanghai', displayName: '北京時間 (GMT+8)', shortName: '北京'),
    SimpleTimeZone(
        id: 'Asia/Hong_Kong', displayName: '香港時間 (GMT+8)', shortName: '香港'),
    SimpleTimeZone(
        id: 'Asia/Singapore', displayName: '新加坡時間 (GMT+8)', shortName: '新加坡'),
    SimpleTimeZone(
        id: 'America/New_York', displayName: '紐約時間 (GMT-5)', shortName: '紐約'),
    SimpleTimeZone(
        id: 'America/Los_Angeles',
        displayName: '洛杉磯時間 (GMT-8)',
        shortName: '洛杉磯'),
    SimpleTimeZone(
        id: 'Europe/London', displayName: '倫敦時間 (GMT+0)', shortName: '倫敦'),
    SimpleTimeZone(
        id: 'Europe/Paris', displayName: '巴黎時間 (GMT+1)', shortName: '巴黎'),
    SimpleTimeZone(
        id: 'Australia/Sydney', displayName: '雪梨時間 (GMT+10)', shortName: '雪梨'),
  ];

  static SimpleTimeZone? getTimeZoneById(String id) {
    try {
      return supportedZones.firstWhere((zone) => zone.id == id);
    } catch (e) {
      return null;
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 初始化時區資料
  try {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Taipei'));
    debugPrint('✅ 時區初始化完成');
  } catch (e) {
    debugPrint('⚠️ 時區初始化失敗: $e');
  }

  // ✅ 桌面平台 SQLite 初始化
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    debugPrint('✅ 桌面平台 SQLite 初始化完成');
  }

  // ✅ 移動平台通知初始化（已註釋，移除通知功能）
  // if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
  //   try {
  //     final InitializationSettings initSettings = InitializationSettings(
  //       android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
  //       iOS: const DarwinInitializationSettings(),
  //     );
  //     await flutterLocalNotificationsPlugin.initialize(initSettings);
  //
  //     if (Platform.isAndroid) {
  //       const AndroidNotificationChannel channel = AndroidNotificationChannel(
  //         'scheduled_channel',
  //         '排程通知頻道',
  //         description: '用於排程任務的本地通知',
  //         importance: Importance.max,
  //       );
  //       final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  //       await androidPlugin?.createNotificationChannel(channel);
  //     }
  //     debugPrint('✅ 移動平台通知初始化完成');
  //   } catch (e) {
  //     debugPrint('⚠️ 通知初始化失敗: $e');
  //   }
  // }

  // ✅ 新增這3行
  await Firebase.initializeApp();
  final firebaseService = FirebaseService();
  await firebaseService.initialize();
  // ✅ 初始化主題管理器
  final themeManager = ThemeManager();
  await themeManager.loadThemeSettings();

  runApp(MyApp(themeManager: themeManager, firebaseService: firebaseService));
}

class MyApp extends StatelessWidget {
  final ThemeManager themeManager;
  final FirebaseService firebaseService;

  const MyApp(
      {super.key, required this.themeManager, required this.firebaseService});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeManager,
      builder: (context, child) {
        return MaterialApp(
          title: '愛傳時 定時訊息App',
          theme: themeManager.lightTheme,
          darkTheme: themeManager.darkTheme,
          themeMode: themeManager.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            // ✅ 全域修正底部安全距離
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.of(context).padding,
              viewPadding: MediaQuery.of(context).viewPadding,
            ),
            child: child!,
          ),
          home: StreamBuilder(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // ✅ 修正：明確判斷 data 不為 null 才跳轉
              if (snapshot.hasData && snapshot.data != null) {
                return HomePage(themeManager: themeManager);
              }
              return const LoginPage();
            },
          ),
        );
      },
    );
  }
}

// ========== 愛傳時APP - 第2段：HomePage主體邏輯、Timer週期檢查（整合音效+震動功能）==========

class HomePage extends StatefulWidget {
  final ThemeManager themeManager;

  const HomePage({super.key, required this.themeManager});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late ThemeManager _themeManager;
  final TextEditingController _messageController = TextEditingController();
  DateTime? _selectedDateTime;
  String _repeatType = 'none';
  final List<int> _selectedWeekdays = [];
  final List<int> _selectedMonths = [];
  final List<int> _selectedDates = []; // ✅ 每月多日選擇器：選中的日期列表
  int _customRepeatCount = 0;
  DateTime? _startDate;
  DateTime? _endDate;

  // ✅ EA功能相關變數
  int _monthlyOrdinal = 1; // 第幾個（1~4, 5=最後一個）
  int _monthlyWeekday = 1; // 星期幾（0~6）

  // ✅ repeatInterval功能相關變數
  int _repeatInterval = 1; // 間隔數量
  String _repeatIntervalUnit = 'days'; // 間隔單位

  // ✅ 時區相關變數（簡化版）
  String _selectedTimeZone = 'Asia/Taipei';
  String _selectedTimeZoneName = '台灣時間 (GMT+8)';

  // ✅ 音效相關狀態變數
  bool _soundEnabled = true; // 是否啟用音效
  String _selectedSoundId = 'notification'; // 選中的音效ID
  double _soundVolume = 0.8; // 音量
  int _soundRepeat = 1; // 重複次數
  bool _showSoundSettings = false; // 是否顯示音效設定區域

  // ✅ 震動相關狀態變數
  bool _vibrationEnabled = true; // 是否啟用震動
  String _selectedVibrationPattern = 'short'; // 選中的震動模式ID
  double _vibrationIntensity = 0.8; // 震動強度
  int _vibrationRepeat = 1; // 震動重複次數
  bool _showVibrationSettings = false; // 是否顯示震動設定區域

  final List<ScheduledMessage> _scheduledMessages = [];
  DateTime _lastResetDate = DateTime.now();
  bool _isFirstLoad = true; // ✅ 新增：標記是否為首次載入
  int _currentTabIndex = 0; // ✅ 新增：目前在哪個Tab

  // ✅ 新增：分類相關變數
  int? _selectedCategoryId;
  List<TaskCategory> _categories = [];
  final List<String> _selectedTags = [];

  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _themeManager = widget.themeManager;

    // ✅ 載入資料庫中的排程訊息
    _loadMessagesFromDatabase();
    _loadCategories();

    // ✅ 保持完整的 Timer 邏輯（整合音效+震動播放）
    Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();

      // 每日清晨：重設 sent 標記
      if (_lastResetDate.day != now.day) {
        setState(() {
          for (var msg in _scheduledMessages) {
            if (msg.repeatType != 'none') {
              msg.sent = false;
            }
          }
          _lastResetDate = now;
        });
      }

      // ✅ 防止首次載入時觸發過期任務
      if (_isFirstLoad) {
        _isFirstLoad = false;
        return; // 跳過第一次檢查
      }

      setState(() {
        for (var msg in _scheduledMessages) {
          if (!msg.sent &&
              now.isAfter(msg.time) &&
              (msg.startDate == null || now.isAfter(msg.startDate!)) &&
              (msg.endDate == null || now.isBefore(msg.endDate!))) {
            // ✅ 新增週期條件判斷：
            if (msg.repeatType == 'weekly' &&
                msg.repeatDays.isNotEmpty &&
                !msg.repeatDays.contains(now.weekday)) {
              continue;
            }

            // ✅ 新增平日模式條件判斷：僅週一至週五（1-5）
            if (msg.repeatType == 'weekdays' &&
                (now.weekday < 1 || now.weekday > 5)) {
              continue;
            }

            // ✅ 每月指定日期條件判斷（支援多日選擇）
            if (msg.repeatType == 'monthly' &&
                msg.repeatDates.isNotEmpty &&
                !msg.repeatDates.contains(now.day)) {
              continue;
            }

            // ✅ 每月多日選擇器條件判斷
            if (msg.repeatType == 'monthlyDates' &&
                msg.repeatDates.isNotEmpty &&
                !msg.repeatDates.contains(now.day)) {
              continue;
            }

            // ✅ 新增EA功能條件判斷：每月第幾個星期幾
            if (msg.repeatType == 'monthlyOrdinal' &&
                msg.repeatMonthlyOrdinal > 0) {
              if (!_isMatchingMonthlyOrdinal(
                  now, msg.repeatMonthlyOrdinal, msg.repeatMonthlyWeekday)) {
                continue;
              }
            }

            // ✅ 檢查是否已達指定執行次數上限
            if (msg.repeatType == 'custom' &&
                msg.repeatCount > 0 &&
                msg.currentCount >= msg.repeatCount) {
              msg.sent = true;
              continue;
            }

            // ✅ 觸發提醒邏輯（整合音效+震動播放）
            msg.sent = true;
            final bool isMobile =
                !kIsWeb && (Platform.isAndroid || Platform.isIOS);
            // final int idx = _scheduledMessages.indexOf(msg);
            // final int baseId = _notificationId(idx);

            // ✅ 增加 currentCount 次數
            if (msg.repeatType == 'custom') {
              msg.currentCount += 1;
            }

            // ✅ 播放音效（如果啟用）
            if (msg.soundEnabled) {
              _playScheduledSound(msg);
            }

            // ✅ 播放震動（如果啟用）
            if (msg.vibrationEnabled) {
              _playScheduledVibration(msg);
            }

            // ✅ 桌面版顯示對話框通知
            if (!isMobile) {
              _showDesktopNotification(msg.message);
            }

            // ✅ 原有重複邏輯保持不變
            if (msg.repeatType == 'daily') {
              msg.time = msg.time.add(const Duration(days: 1));
              if (isMobile) {
                // _scheduleNotification(baseId, msg.message, msg.time);
              }
            } else if (msg.repeatType == 'weekly') {
              final nextOffset = _findNextWeekday(msg.time, msg.repeatDays);
              msg.time = msg.time.add(Duration(days: nextOffset));
              if (isMobile) {
                // for (var d in msg.repeatDays) {
                //   flutterLocalNotificationsPlugin.cancel(baseId + d);
                // }
                // for (var w in msg.repeatDays) {
                //   int id = baseId + w;
                //   final tzDate = tz.TZDateTime.local(
                //     msg.time.year,
                //     msg.time.month,
                //     msg.time.day,
                //     msg.time.hour,
                //     msg.time.minute,
                //   );
                //   // flutterLocalNotificationsPlugin.zonedSchedule(...)
                // }
              }
            } else if (msg.repeatType == 'weekdays') {
              // ✅ 平日模式：計算下一個工作日
              final nextWorkday = _findNextWorkday(msg.time);
              msg.time = msg.time.add(Duration(days: nextWorkday));
              if (isMobile) {
                // _scheduleNotification(baseId, msg.message, msg.time);
              }
            } else if (msg.repeatType == 'monthly') {
              msg.time = DateTime(
                msg.time.year,
                msg.time.month + 1,
                msg.time.day,
                msg.time.hour,
                msg.time.minute,
              );
              if (isMobile) {
                // _scheduleNotification(baseId, msg.message, msg.time);
              }
            } else if (msg.repeatType == 'monthlyDates') {
              // ✅ 每月多日選擇器：計算下個月同樣日期
              final nextMonthDate =
                  _getNextMonthlyDatesTime(msg.time, msg.repeatDates);
              msg.time = DateTime(
                nextMonthDate.year,
                nextMonthDate.month,
                nextMonthDate.day,
                msg.time.hour,
                msg.time.minute,
              );
              if (isMobile) {
                // _scheduleNotification(baseId, msg.message, msg.time);
              }
            } else if (msg.repeatType == 'monthlyOrdinal') {
              // ✅ EA功能：計算下個月同樣的第N個星期X
              final nextMonthlyOrdinalDate = _getNextMonthlyOrdinalDate(
                  msg.time, msg.repeatMonthlyOrdinal, msg.repeatMonthlyWeekday);
              msg.time = DateTime(
                nextMonthlyOrdinalDate.year,
                nextMonthlyOrdinalDate.month,
                nextMonthlyOrdinalDate.day,
                msg.time.hour,
                msg.time.minute,
              );
              if (isMobile) {
                // _scheduleNotification(baseId, msg.message, msg.time);
              }
            } else if (msg.repeatType == 'yearly') {
              msg.time = DateTime(
                msg.time.year + 1,
                msg.time.month,
                msg.time.day,
                msg.time.hour,
                msg.time.minute,
              );
              if (isMobile) {
                // _scheduleNotification(baseId, msg.message, msg.time);
              }
            } else if (msg.repeatType == 'interval') {
              // ✅ 新增 repeatInterval 邏輯：根據間隔單位計算下次執行時間
              final nextTime = _calculateNextIntervalTime(
                  msg.time, msg.repeatInterval, msg.repeatIntervalUnit);
              msg.time = nextTime;
              if (isMobile) {
                // _scheduleNotification(baseId, msg.message, msg.time);
              }
            } else if (msg.repeatType == 'custom' && msg.repeatCount > 1) {
              msg.time = msg.time.add(const Duration(days: 1));
              if (isMobile) {
                // _scheduleNotification(baseId, msg.message, msg.time);
              }
            }
          }
        }
      });
    });
  }

  // ✅ 從資料庫載入訊息的方法（加入過期任務處理）
// ✅ 從資料庫載入訊息的方法（徹底處理過期任務）
  Future<void> _loadMessagesFromDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final List<Map<String, dynamic>> maps = await dbHelper.getAllMessages();

      setState(() {
        _scheduledMessages.clear();
        _scheduledMessages.addAll(
          maps.map((map) => ScheduledMessage.fromMap(map)).toList(),
        );
      });

      // ✅ APP啟動時徹底處理所有過期任務
      final now = DateTime.now();
      bool hasUpdates = false;

      for (var msg in _scheduledMessages) {
        // 檢查任務是否過期
        if (now.isAfter(msg.time) && !msg.sent) {
          if (msg.repeatType == 'none') {
            // 單次任務：直接標記為已完成
            msg.sent = true;
            hasUpdates = true;
          } else {
            // 重複任務：計算下一次觸發時間
            _updateNextRepeatTime(msg, now);
            msg.sent = false; // 重設為未發送
            hasUpdates = true;
          }

          // 更新資料庫
          if (msg.id != null) {
            try {
              await dbHelper.updateMessage(msg.id!, msg.toMap());
            } catch (e) {
              debugPrint('❌ 更新任務失敗: $e');
            }
          }
        }
      }

      if (hasUpdates) {
        setState(() {
          // 觸發UI更新
        });
      }

      debugPrint('✅ 從資料庫載入了 ${_scheduledMessages.length} 個排程訊息，已處理過期任務');
    } catch (e) {
      debugPrint('❌ 載入資料庫失敗: $e');
    }
  }

// ✅ 新增：更新重複任務的下次觸發時間
  void _updateNextRepeatTime(ScheduledMessage msg, DateTime now) {
    switch (msg.repeatType) {
      case 'daily':
        // 計算下一個未來的每日時間
        msg.time = DateTime(
            now.year, now.month, now.day, msg.time.hour, msg.time.minute);
        while (msg.time.isBefore(now) || msg.time.isAtSameMomentAs(now)) {
          msg.time = msg.time.add(const Duration(days: 1));
        }
        break;

      case 'weekly':
        // 計算下一個符合星期的時間
        msg.time = DateTime(
            now.year, now.month, now.day, msg.time.hour, msg.time.minute);
        while (msg.time.isBefore(now) || msg.time.isAtSameMomentAs(now)) {
          msg.time = msg.time.add(const Duration(days: 1));
          if (msg.repeatDays.contains(msg.time.weekday % 7)) {
            break;
          }
        }
        break;

      case 'weekdays':
        // 計算下一個工作日
        msg.time = DateTime(
            now.year, now.month, now.day, msg.time.hour, msg.time.minute);
        while (msg.time.isBefore(now) ||
            msg.time.isAtSameMomentAs(now) ||
            msg.time.weekday < 1 ||
            msg.time.weekday > 5) {
          msg.time = msg.time.add(const Duration(days: 1));
        }
        break;

      case 'monthly':
      case 'monthlyDates':
        // 計算下一個月的同樣日期
        msg.time = DateTime(
            now.year, now.month, msg.time.day, msg.time.hour, msg.time.minute);
        while (msg.time.isBefore(now) || msg.time.isAtSameMomentAs(now)) {
          msg.time = DateTime(msg.time.year, msg.time.month + 1, msg.time.day,
              msg.time.hour, msg.time.minute);
        }
        break;

      case 'yearly':
        // 計算下一年的同樣日期
        msg.time = DateTime(now.year, msg.time.month, msg.time.day,
            msg.time.hour, msg.time.minute);
        while (msg.time.isBefore(now) || msg.time.isAtSameMomentAs(now)) {
          msg.time = DateTime(msg.time.year + 1, msg.time.month, msg.time.day,
              msg.time.hour, msg.time.minute);
        }
        break;

      default:
        // 其他重複模式：簡單地加一天
        msg.time = DateTime(
            now.year, now.month, now.day, msg.time.hour, msg.time.minute);
        while (msg.time.isBefore(now) || msg.time.isAtSameMomentAs(now)) {
          msg.time = msg.time.add(const Duration(days: 1));
        }
        break;
    }
  }

  // ✅ 播放排程設定的音效
  Future<void> _playScheduledSound(ScheduledMessage msg) async {
    try {
      await AudioManager.playSound(
        soundId: msg.soundPath,
        volume: msg.soundVolume,
        repeat: msg.soundRepeat,
      );

      debugPrint('✅ 排程音效播放: ${msg.soundPath}');
    } catch (e) {
      debugPrint('❌ 排程音效播放失敗: $e');
      // 如果播放失敗，使用系統預設提示音作為備援
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  // ✅ 新增：播放排程設定的震動
  Future<void> _playScheduledVibration(ScheduledMessage msg) async {
    try {
      await VibrationManager.playVibration(
        patternId: msg.vibrationPattern,
        intensity: msg.vibrationIntensity,
        repeat: msg.vibrationRepeat,
      );

      debugPrint('✅ 排程震動播放: ${msg.vibrationPattern}');
    } catch (e) {
      debugPrint('❌ 排程震動播放失敗: $e');
      // 如果震動播放失敗，使用基礎震動作為備援
      try {
        await VibrationManager.playVibration(
          patternId: 'short',
          intensity: 0.5,
          repeat: 1,
        );
      } catch (fallbackError) {
        debugPrint('❌ 備援震動也失敗: $fallbackError');
      }
    }
  }

  /// ✅ 桌面版通知顯示
  void _showDesktopNotification(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔔 排程提醒'),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
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

  /// ✅ 每月多日選擇器：計算下個月的執行時間
  DateTime _getNextMonthlyDatesTime(DateTime currentTime, List<int> dates) {
    if (dates.isEmpty) return currentTime.add(const Duration(days: 30));

    // 找到下個月第一個有效日期
    final nextMonth = DateTime(currentTime.year, currentTime.month + 1, 1);
    final sortedDates = List<int>.from(dates)..sort();

    for (int date in sortedDates) {
      final targetDate = DateTime(nextMonth.year, nextMonth.month, date);
      // 檢查日期是否有效（如2月30號無效）
      if (targetDate.month == nextMonth.month) {
        return targetDate;
      }
    }

    // 如果都無效，回到下個月第一天
    return nextMonth;
  }

  /// ✅ repeatInterval功能：計算下次間隔時間
  DateTime _calculateNextIntervalTime(
      DateTime currentTime, int interval, String unit) {
    switch (unit) {
      case 'days':
        return currentTime.add(Duration(days: interval));
      case 'weeks':
        return currentTime.add(Duration(days: interval * 7));
      case 'months':
        return DateTime(
          currentTime.year,
          currentTime.month + interval,
          currentTime.day,
          currentTime.hour,
          currentTime.minute,
        );
      case 'years':
        return DateTime(
          currentTime.year + interval,
          currentTime.month,
          currentTime.day,
          currentTime.hour,
          currentTime.minute,
        );
      default:
        return currentTime.add(Duration(days: interval)); // 預設為天
    }
  }

  /// ✅ EA功能：判斷當前日期是否符合每月第N個星期X
  bool _isMatchingMonthlyOrdinal(DateTime date, int ordinal, int weekday) {
    // weekday: 0=日, 1=一, 2=二...6=六
    // ordinal: 1=第1個, 2=第2個, 3=第3個, 4=第4個, 5=最後一個

    final targetWeekday =
        weekday == 0 ? 7 : weekday; // 轉換為 DateTime.weekday 格式 (1-7)

    if (date.weekday != targetWeekday) return false;

    if (ordinal == 5) {
      // 最後一個
      final nextWeek = date.add(const Duration(days: 7));
      return nextWeek.month != date.month; // 下週已經是下個月，代表這週是最後一個
    } else {
      // 第1~4個
      final firstDayOfMonth = DateTime(date.year, date.month, 1);
      final firstTargetWeekday =
          _getFirstWeekdayOfMonth(firstDayOfMonth, targetWeekday);
      final targetDate =
          firstTargetWeekday.add(Duration(days: (ordinal - 1) * 7));
      return date.day == targetDate.day && date.month == targetDate.month;
    }
  }

  /// ✅ EA功能：取得當月第一個指定星期幾的日期
  DateTime _getFirstWeekdayOfMonth(DateTime firstDay, int targetWeekday) {
    int daysToAdd = (targetWeekday - firstDay.weekday) % 7;
    return firstDay.add(Duration(days: daysToAdd));
  }

  /// ✅ EA功能：計算下個月的第N個星期X日期
  DateTime _getNextMonthlyOrdinalDate(
      DateTime current, int ordinal, int weekday) {
    final nextMonth = DateTime(current.year, current.month + 1, 1);
    final targetWeekday = weekday == 0 ? 7 : weekday;
    final firstTargetWeekday =
        _getFirstWeekdayOfMonth(nextMonth, targetWeekday);

    if (ordinal == 5) {
      // 最後一個
      DateTime lastOccurrence = firstTargetWeekday;
      while (true) {
        final nextOccurrence = lastOccurrence.add(const Duration(days: 7));
        if (nextOccurrence.month != nextMonth.month) break;
        lastOccurrence = nextOccurrence;
      }
      return lastOccurrence;
    } else {
      // 第1~4個
      return firstTargetWeekday.add(Duration(days: (ordinal - 1) * 7));
    }
  }

  /// 計算下一個符合 weekday 的 offset（1~7）
  int _findNextWeekday(DateTime fromDate, List<int> repeatDays) {
    for (int i = 1; i <= 7; i++) {
      final next = fromDate.add(Duration(days: i));
      if (repeatDays.contains(next.weekday % 7)) return i;
    }
    return 7;
  }

  /// ✅ 平日模式：計算下一個工作日的 offset
  int _findNextWorkday(DateTime fromDate) {
    for (int i = 1; i <= 7; i++) {
      final next = fromDate.add(Duration(days: i));
      // 週一至週五（1-5）才是工作日
      if (next.weekday >= 1 && next.weekday <= 5) return i;
    }
    return 1; // 預設至少1天後
  }

  // 通知 ID 函數已移除

// ========== 愛傳時APP - 第3段：通知相關函數、智能驗證功能（正確修正版） ==========

  // 通知功能已移除

  /// 取消通知

  /// ✅ 顯示重複資訊（優化版時區顯示邏輯）
  String _getRepeatInfo(ScheduledMessage msg) {
    final format = DateFormat('yyyy/MM/dd');
    String range = '';

    if (msg.startDate != null || msg.endDate != null) {
      range =
          '(${msg.startDate != null ? format.format(msg.startDate!) : ''} 至 ${msg.endDate != null ? format.format(msg.endDate!) : ''})';
    }

    // ✅ 基礎重複資訊
    String baseInfo = '';
    switch (msg.repeatType) {
      case 'daily':
        baseInfo = '（每日）';
        break;
      case 'weekly':
        const days = ['日', '一', '二', '三', '四', '五', '六'];
        final sortedDays = List<int>.from(msg.repeatDays)..sort();
        final text = sortedDays.map((d) => '週${days[d]}').join(' ');
        baseInfo = '（每週 $text）';
        break;
      case 'weekdays':
        baseInfo = '（平日）';
        break;
      case 'monthly':
        final sortedMonths = List<int>.from(msg.repeatMonths)..sort();
        final text = sortedMonths.map((m) => '$m月').join(' ');
        baseInfo = '（每月 $text）';
        break;
      case 'monthlyDates':
        final sortedDates = List<int>.from(msg.repeatDates)..sort();
        final text = sortedDates.map((d) => '$d號').join(' ');
        baseInfo = '（每月 $text）';
        break;
      case 'monthlyOrdinal':
        const days = ['日', '一', '二', '三', '四', '五', '六'];
        const ordinals = ['', '第1個', '第2個', '第3個', '第4個', '最後一個'];
        final ordinalText =
            msg.repeatMonthlyOrdinal >= 1 && msg.repeatMonthlyOrdinal <= 5
                ? ordinals[msg.repeatMonthlyOrdinal]
                : '第${msg.repeatMonthlyOrdinal}個';
        final weekdayText =
            msg.repeatMonthlyWeekday >= 0 && msg.repeatMonthlyWeekday <= 6
                ? days[msg.repeatMonthlyWeekday]
                : '${msg.repeatMonthlyWeekday}';
        baseInfo = '（每月$ordinalText星期$weekdayText）';
        break;
      case 'yearly':
        baseInfo = '（每年）';
        break;
      case 'interval':
        const unitTexts = {
          'days': '天',
          'weeks': '週',
          'months': '個月',
          'years': '年'
        };
        final unitText = unitTexts[msg.repeatIntervalUnit] ?? '天';
        final intervalText = msg.repeatInterval == 1
            ? '每$unitText'
            : '每${msg.repeatInterval}$unitText';
        baseInfo = '（$intervalText）';
        break;
      case 'custom':
        final remaining = msg.repeatCount - msg.currentCount;
        baseInfo = '（剩餘 $remaining 次）';
        break;
      default:
        baseInfo = '';
    }

    // ✅ 優化的時區顯示邏輯 - 只影響 [東京] 這種方括號標示
    String timeZoneInfo = '';
    if (msg.targetTimeZone != 'Asia/Taipei') {
      // 判斷是否需要顯示時區標示
      bool shouldShowTimeZone = false;

      // 條件1：有重複設定（非單次任務）
      if (msg.repeatType != 'none') {
        shouldShowTimeZone = true;
      }

      // 條件2：有設定起始或結束日期
      if (msg.startDate != null || msg.endDate != null) {
        shouldShowTimeZone = true;
      }

      // 只有滿足條件才顯示時區標示
      if (shouldShowTimeZone) {
        final zone = AppTimeZones.getTimeZoneById(msg.targetTimeZone);
        timeZoneInfo = ' [${zone?.shortName ?? msg.targetTimeZoneName}]';
      }
    }

    return '$baseInfo$timeZoneInfo$range';
  }

  /// ✅ 格式化排程時間顯示（保留時區標示版）
  String _formatScheduleTime(ScheduledMessage msg) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(msg.time);

    // 如果是台灣時間，直接顯示
    if (msg.targetTimeZone == 'Asia/Taipei') {
      return timeText;
    }

    // ✅ 國外時區永遠顯示時區標示 (東京) 這種形式
    final zone = AppTimeZones.getTimeZoneById(msg.targetTimeZone);
    return '$timeText (${zone?.shortName ?? '其他時區'})';
  }

  /// ✅ 複製時間到剪貼板
  void _copyTimeToClipboard(ScheduledMessage msg) {
    final timeText = _formatScheduleTime(msg);
    Clipboard.setData(ClipboardData(text: timeText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 時間已複製到剪貼板'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ✅ 智能日期同步功能
  /// 智能日期同步 - 在重複模式改變時調用
  void _onRepeatTypeChanged(String newRepeatType) {
    setState(() {
      _repeatType = newRepeatType;

      // ✅ 智能同步：當選擇每月指定日期時，自動勾選初始時間的日期
      if (_repeatType == 'monthlyDates' && _selectedDateTime != null) {
        final initialDay = _selectedDateTime!.day;
        if (!_selectedDates.contains(initialDay)) {
          _selectedDates.add(initialDay);
          _selectedDates.sort();

          // 顯示提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💡 已自動選擇 $initialDay 號（與初始時間同步）'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }

      // ✅ 智能同步：當選擇每月第N個星期X時，根據初始時間設定
      if (_repeatType == 'monthlyOrdinal' && _selectedDateTime != null) {
        _monthlyWeekday = _selectedDateTime!.weekday % 7;

        // 計算是第幾個
        final ordinal = _calculateOrdinalPosition(_selectedDateTime!);
        if (ordinal > 0) {
          _monthlyOrdinal = ordinal;

          const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
          const ordinals = ['', '第1個', '第2個', '第3個', '第4個', '最後一個'];
          final weekdayText = weekdays[_monthlyWeekday];
          final ordinalText = ordinal <= 5 ? ordinals[ordinal] : '第$ordinal個';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💡 已自動設定為「$ordinalText星期$weekdayText」'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.blue,
            ),
          );
        }
      }
    });
  }

  /// 計算某日期是當月第幾個該星期
  int _calculateOrdinalPosition(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final targetWeekday = date.weekday % 7;

    // 找到當月第一個該星期幾
    int daysToAdd = (targetWeekday - firstDayOfMonth.weekday % 7) % 7;
    final firstOccurrence = firstDayOfMonth.add(Duration(days: daysToAdd));

    // 計算是第幾個
    final daysDiff = date.difference(firstOccurrence).inDays;
    final position = (daysDiff ~/ 7) + 1;

    // 檢查是否為最後一個
    final nextOccurrence = date.add(const Duration(days: 7));
    if (nextOccurrence.month != date.month) {
      return 5; // 最後一個
    }

    return position <= 4 ? position : 0;
  }

  // ✅ 衝突檢查相關方法
  /// 顯示月日衝突警告對話框
  Future<bool> _showDateConflictDialog(int initialDay) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('日期設定衝突'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('您設定的觸發時間是每月 $initialDay 號'),
                const SizedBox(height: 8),
                Text('但重複日期中不包含 $initialDay 號'),
                const SizedBox(height: 8),
                const Text('建議處理方式：'),
                const Text('1. 修改觸發時間到重複日期中'),
                Text('2. 或將 $initialDay 號加入重複日期'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('修改設定'),
              ),
              TextButton(
                onPressed: () {
                  // 自動將初始日期加入重複日期
                  setState(() {
                    if (!_selectedDates.contains(initialDay)) {
                      _selectedDates.add(initialDay);
                      _selectedDates.sort();
                    }
                  });
                  Navigator.pop(context, true);
                },
                child: Text('自動加入 $initialDay 號'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('仍要建立', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 檢查每月第N個星期X的邏輯是否合理
  bool _validateMonthlyOrdinal(DateTime dateTime) {
    final targetWeekday = _monthlyWeekday == 0 ? 7 : _monthlyWeekday;

    if (dateTime.weekday != targetWeekday) {
      return false; // 初始日期的星期幾不匹配
    }

    // 檢查是否符合第N個的設定
    return _isMatchingMonthlyOrdinal(
        dateTime, _monthlyOrdinal, _monthlyWeekday);
  }

  /// 顯示每月第N個星期X衝突警告
  Future<bool> _showOrdinalConflictDialog() async {
    const weekdays = ['日', '一', '二', '三', '四', '五', '六'];
    const ordinals = ['', '第1個', '第2個', '第3個', '第4個', '最後一個'];

    final ordinalText = _monthlyOrdinal >= 1 && _monthlyOrdinal <= 5
        ? ordinals[_monthlyOrdinal]
        : '第$_monthlyOrdinal個';
    final weekdayText = weekdays[_monthlyWeekday];

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('星期設定衝突'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('您選擇的初始時間與「$ordinalText星期$weekdayText」不匹配'),
                const SizedBox(height: 8),
                const Text('建議：'),
                const Text('• 修改初始時間到正確的星期'),
                const Text('• 或調整重複設定'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('修改設定'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('仍要建立', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 選擇日期時間
  void _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

// ========== 愛傳時APP - 第4段：新增任務方法、編輯任務對話框（整合音效功能）==========

  /// ✅ 改善版新增任務方法 - 加入驗證和衝突檢查 + 時區支援 + 音效設定
  void _addMessage() async {
    // ✅ 驗證訊息內容
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 請輸入任務內容'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ 驗證時間選擇
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ 請設定觸發提醒時間'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // ✅ 檢查月日設定邏輯衝突
    if (_repeatType == 'monthlyDates' && _selectedDates.isNotEmpty) {
      final initialDay = _selectedDateTime!.day;
      if (!_selectedDates.contains(initialDay)) {
        // 顯示衝突警告對話框
        final shouldContinue = await _showDateConflictDialog(initialDay);
        if (!shouldContinue) return;
      }
    }

    // ✅ 檢查每月第N個星期X的邏輯
    if (_repeatType == 'monthlyOrdinal') {
      final isValid = _validateMonthlyOrdinal(_selectedDateTime!);
      if (!isValid) {
        final shouldContinue = await _showOrdinalConflictDialog();
        if (!shouldContinue) return;
      }
    }

    // ✅ 建立新訊息（加入時區資訊和音效設定）
    final newMsg = ScheduledMessage(
      _messageController.text.trim(), // 去除前後空格
      _selectedDateTime!,
      repeatType: _repeatType,
      repeatDays: List.from(_selectedWeekdays),
      repeatCount: _customRepeatCount,
      currentCount: 0,
      repeatMonths: List.from(_selectedMonths),
      repeatDates: List.from(_selectedDates),
      repeatMonthlyOrdinal: _monthlyOrdinal,
      repeatMonthlyWeekday: _monthlyWeekday,
      repeatInterval: _repeatInterval,
      repeatIntervalUnit: _repeatIntervalUnit,
      startDate: _startDate,
      endDate: _endDate,
      // ✅ 時區資訊
      targetTimeZone: _selectedTimeZone,
      targetTimeZoneName: _selectedTimeZoneName,
      // ✅ 音效設定
      soundEnabled: _soundEnabled,
      soundType: 'system',
      soundPath: _selectedSoundId,
      soundVolume: _soundVolume,
      soundRepeat: _soundRepeat,
      // ✅ 分類設定
      categoryId: _selectedCategoryId,
      tags: List.from(_selectedTags),
    );

    // 儲存到資料庫
    try {
      final dbHelper = DatabaseHelper();
      final int insertedId = await dbHelper.insertMessage(newMsg.toMap());
      newMsg.id = insertedId;
      debugPrint('✅ 排程已儲存到資料庫，ID: $insertedId，音效: ${newMsg.soundPath}');
      MessagingService.addMessage(newMsg.toMap()); // ← 新增：同步存到雲端
    } catch (e) {
      debugPrint('❌ 儲存到資料庫失敗: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ 儲存失敗，請重試'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _scheduledMessages.add(newMsg);
      _resetForm();
    });

    // 顯示成功訊息（包含音效資訊）
    final zone = AppTimeZones.getTimeZoneById(newMsg.targetTimeZone);
    final soundName =
        AudioManager.getSoundById(newMsg.soundPath)?.name ?? '預設音效';
// 顯示成功訊息（包含音效和震動資訊）
    final vibrationName =
        VibrationManager.getVibrationPatternById(newMsg.vibrationPattern)
                ?.name ??
            '預設震動';

    String successMessage = '✅ 排程已新增！';
    if (newMsg.soundEnabled && newMsg.vibrationEnabled) {
      successMessage += '音效: $soundName | 震動: $vibrationName';
    } else if (newMsg.soundEnabled) {
      successMessage += '音效: $soundName | 震動: 已關閉';
    } else if (newMsg.vibrationEnabled) {
      successMessage += '音效: 已關閉 | 震動: $vibrationName';
    } else {
      successMessage += '音效: 已關閉 | 震動: 已關閉';
    }
    successMessage += ' (${zone?.shortName ?? newMsg.targetTimeZoneName})';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(successMessage),
        backgroundColor: Colors.green,
      ),
    );

    // 通知相關程式碼保持不變...
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    // final int newIndex = _scheduledMessages.length - 1;
    // final int baseId = _notificationId(newIndex);
    // DateTime fireDate = newMsg.time;

    if (newMsg.repeatType == 'weekly' && isMobile) {
      // for (var w in newMsg.repeatDays) {
      //   int id = baseId + w;
      //   final tzDate = tz.TZDateTime.local(
      //     fireDate.year,
      //     fireDate.month,
      //     fireDate.day + ((w + 7 - fireDate.weekday) % 7),
      //     fireDate.hour,
      //     fireDate.minute,
      //   );
      //   // flutterLocalNotificationsPlugin.zonedSchedule(...)
      // }
    } else if (isMobile) {
      // _scheduleNotification(baseId, newMsg.message, fireDate);
    }
  }

  /// ✅ 重設表單（加入時區重設和音效重設）
  void _resetForm() {
    _messageController.clear();
    _selectedDateTime = null;
    _repeatType = 'none';
    _selectedWeekdays.clear();
    _selectedMonths.clear();
    _selectedDates.clear();
    _customRepeatCount = 0;
    _monthlyOrdinal = 1;
    _monthlyWeekday = 1;
    _repeatInterval = 1;
    _repeatIntervalUnit = 'days';
    _startDate = null;
    _endDate = null;
    // ✅ 重設時區為預設值
    _selectedTimeZone = 'Asia/Taipei';
    _selectedTimeZoneName = '台灣時間 (GMT+8)';
    // ✅ 重設音效相關變數
    _soundEnabled = true;
    _selectedSoundId = 'notification';
    _soundVolume = 0.8;
    _soundRepeat = 1;
    _showSoundSettings = false;
    // ✅ 重設分類相關變數
    _selectedCategoryId = null;
    _selectedTags.clear();
  }

  /// 刪除任務 - ✅ 修正版本：使用ID刪除
  void _deleteMessage(int index) async {
    final msg = _scheduledMessages[index];
    // final int baseId = _notificationId(index);
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    // ✅ 修正：使用ID直接刪除
    if (msg.id != null) {
      try {
        final dbHelper = DatabaseHelper();
        await dbHelper.deleteMessage(msg.id!);
        debugPrint('✅ 已從資料庫刪除排程 ID: ${msg.id}');
      } catch (e) {
        debugPrint('❌ 從資料庫刪除失敗: $e');
      }
    }

    // 取消通知（原有邏輯保持不變）
    if (isMobile) {
      // if (msg.repeatType == 'weekly') {
      //   for (var d in msg.repeatDays) {
      //     // flutterLocalNotificationsPlugin.cancel(baseId + d);
      //   }
      // }
      // flutterLocalNotificationsPlugin.cancel(baseId);
    }

    setState(() {
      _scheduledMessages.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('排程已刪除！')),
    );
  }

  /// ✅ 編輯任務（完整功能版本）
  void _editMessage(int index) {
    final msg = _scheduledMessages[index];
    final controller = TextEditingController(text: msg.message);
    DateTime newTime = msg.time;
    String repeat = msg.repeatType;
    List<int> days = List.from(msg.repeatDays);
    int count = msg.repeatCount;
    List<int> months = List.from(msg.repeatMonths);
    List<int> dates = List.from(msg.repeatDates);
    int monthlyOrdinal = msg.repeatMonthlyOrdinal;
    int monthlyWeekday = msg.repeatMonthlyWeekday;
    int interval = msg.repeatInterval;
    String intervalUnit = msg.repeatIntervalUnit;
    DateTime? start = msg.startDate;
    DateTime? end = msg.endDate;

    // ✅ 時區編輯支援
    String editTimeZone = msg.targetTimeZone;
    String editTimeZoneName = msg.targetTimeZoneName;

    // ✅ 音效編輯相關變數
    bool editSoundEnabled = msg.soundEnabled;
    String editSoundId = msg.soundPath;
    double editSoundVolume = msg.soundVolume;
    int editSoundRepeat = msg.soundRepeat;

    // ✅ 震動編輯相關變數
    bool editVibrationEnabled = msg.vibrationEnabled;
    String editVibrationPattern = msg.vibrationPattern;
    double editVibrationIntensity = msg.vibrationIntensity;
    int editVibrationRepeat = msg.vibrationRepeat;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('修改訊息'),
          content: SizedBox(
            width: double.maxFinite,
            height: 800, // ✅ 增加高度以容納完整功能
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 訊息內容
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: '訊息內容'),
                  ),
                  const SizedBox(height: 8),

                  // 時間選擇
                  ElevatedButton(
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: newTime,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(newTime),
                        );
                        if (pickedTime != null) {
                          setDialogState(() {
                            newTime = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    child: Text(
                        '時間：${DateFormat('yyyy-MM-dd HH:mm').format(newTime)}'),
                  ),
                  const SizedBox(height: 8),

                  // ✅ 時區選擇器
                  DropdownButtonFormField<String>(
                    value: editTimeZone,
                    decoration: const InputDecoration(
                      labelText: '時區',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        final timeZoneInfo =
                            AppTimeZones.getTimeZoneById(newValue);
                        if (timeZoneInfo != null) {
                          setDialogState(() {
                            editTimeZone = newValue;
                            editTimeZoneName = timeZoneInfo.displayName;
                          });
                        }
                      }
                    },
                    items: AppTimeZones.supportedZones
                        .map<DropdownMenuItem<String>>((SimpleTimeZone zone) {
                      return DropdownMenuItem<String>(
                        value: zone.id,
                        child: Text(zone.displayName),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // ✅ 音效設定區域
                  Card(
                    elevation: 2,
                    child: ExpansionTile(
                      leading: Icon(
                        editSoundEnabled ? Icons.volume_up : Icons.volume_off,
                        color: editSoundEnabled ? Colors.blue : Colors.grey,
                      ),
                      title: const Text(
                        '音效設定',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        editSoundEnabled
                            ? AudioManager.getSoundById(editSoundId)?.name ??
                                "預設音效"
                            : '已關閉音效',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 音效開關
                              SwitchListTile(
                                title: const Text('啟用音效提醒'),
                                value: editSoundEnabled,
                                onChanged: (value) {
                                  setDialogState(() {
                                    editSoundEnabled = value;
                                  });
                                },
                                dense: true,
                              ),

                              if (editSoundEnabled) ...[
                                const SizedBox(height: 8),

                                // 音效選擇
                                DropdownButtonFormField<String>(
                                  value: editSoundId,
                                  decoration: const InputDecoration(
                                    labelText: '選擇音效',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() {
                                        editSoundId = value;
                                      });
                                    }
                                  },
                                  items:
                                      AudioManager.getAllSounds().map((sound) {
                                    return DropdownMenuItem<String>(
                                      value: sound.id,
                                      child: Text(sound.name),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),

                                // 試聽按鈕
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      AudioManager.previewSound(editSoundId);
                                    },
                                    icon: const Icon(Icons.play_circle_outline,
                                        size: 16),
                                    label: const Text('試聽'),
                                  ),
                                ),

                                // 音量控制
                                Text('音量: ${(editSoundVolume * 100).round()}%'),
                                Slider(
                                  value: editSoundVolume,
                                  min: 0.1,
                                  max: 1.0,
                                  divisions: 9,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      editSoundVolume = value;
                                    });
                                  },
                                ),

                                // 重複次數
                                Row(
                                  children: [
                                    const Text('重複次數: '),
                                    DropdownButton<int>(
                                      value: editSoundRepeat,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() {
                                            editSoundRepeat = value;
                                          });
                                        }
                                      },
                                      items: [1, 2, 3, 5].map((count) {
                                        return DropdownMenuItem<int>(
                                          value: count,
                                          child: Text('$count 次'),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ✅ 震動設定區域
                  Card(
                    elevation: 2,
                    child: ExpansionTile(
                      leading: Icon(
                        editVibrationEnabled
                            ? Icons.vibration
                            : Icons.phonelink_erase,
                        color:
                            editVibrationEnabled ? Colors.purple : Colors.grey,
                      ),
                      title: const Text(
                        '震動設定',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        editVibrationEnabled
                            ? VibrationManager.getVibrationPatternById(
                                        editVibrationPattern)
                                    ?.name ??
                                "預設震動"
                            : '已關閉震動',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 震動開關
                              SwitchListTile(
                                title: const Text('啟用震動提醒'),
                                value: editVibrationEnabled,
                                onChanged: (value) {
                                  setDialogState(() {
                                    editVibrationEnabled = value;
                                  });
                                },
                                dense: true,
                              ),

                              if (editVibrationEnabled) ...[
                                const SizedBox(height: 8),

                                // 震動模式選擇
                                DropdownButtonFormField<String>(
                                  value: editVibrationPattern,
                                  decoration: const InputDecoration(
                                    labelText: '選擇震動模式',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                  ),
                                  onChanged: (value) {
                                    if (value != null) {
                                      setDialogState(() {
                                        editVibrationPattern = value;
                                      });
                                    }
                                  },
                                  items:
                                      VibrationManager.getAllVibrationPatterns()
                                          .map((pattern) {
                                    return DropdownMenuItem<String>(
                                      value: pattern.id,
                                      child: Text(pattern.name),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 8),

                                // 試震按鈕
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      VibrationManager.previewVibration(
                                          editVibrationPattern);
                                    },
                                    icon: const Icon(Icons.vibration, size: 16),
                                    label: const Text('試震'),
                                  ),
                                ),

                                // 震動強度控制
                                Text(
                                    '震動強度: ${(editVibrationIntensity * 100).round()}%'),
                                Slider(
                                  value: editVibrationIntensity,
                                  min: 0.1,
                                  max: 1.0,
                                  divisions: 9,
                                  onChanged: (value) {
                                    setDialogState(() {
                                      editVibrationIntensity = value;
                                    });
                                  },
                                ),

                                // 重複次數
                                Row(
                                  children: [
                                    const Text('重複次數: '),
                                    DropdownButton<int>(
                                      value: editVibrationRepeat,
                                      onChanged: (value) {
                                        if (value != null) {
                                          setDialogState(() {
                                            editVibrationRepeat = value;
                                          });
                                        }
                                      },
                                      items: [1, 2, 3, 5].map((count) {
                                        return DropdownMenuItem<int>(
                                          value: count,
                                          child: Text('$count 次'),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ✅ 重複模式選擇器（完整版本）
                  DropdownButtonFormField<String>(
                    value: repeat,
                    decoration: const InputDecoration(
                      labelText: '重複模式',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => setDialogState(() {
                      repeat = val!;
                      // 切換重複模式時清空相關設定
                      if (repeat != 'weekly') days.clear();
                      if (repeat != 'monthly') months.clear();
                      if (repeat != 'monthlyDates') dates.clear();
                      if (repeat != 'monthlyOrdinal') {
                        monthlyOrdinal = 1;
                        monthlyWeekday = 1;
                      }
                      if (repeat != 'interval') {
                        interval = 1;
                        intervalUnit = 'days';
                      }
                      if (repeat != 'custom') count = 0;
                    }),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('不重複')),
                      DropdownMenuItem(value: 'daily', child: Text('每日')),
                      DropdownMenuItem(value: 'weekly', child: Text('每週')),
                      DropdownMenuItem(
                          value: 'weekdays', child: Text('平日 (週一至週五)')),
                      DropdownMenuItem(value: 'monthly', child: Text('每月')),
                      DropdownMenuItem(
                          value: 'monthlyDates', child: Text('每月指定日期')),
                      DropdownMenuItem(
                          value: 'monthlyOrdinal', child: Text('每月第幾個星期幾')),
                      DropdownMenuItem(value: 'yearly', child: Text('每年')),
                      DropdownMenuItem(value: 'interval', child: Text('自訂間隔')),
                      DropdownMenuItem(value: 'custom', child: Text('自訂次數')),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ✅ 條件性UI顯示：每週星期選擇器
                  if (repeat == 'weekly') ...[
                    const Text('選擇星期幾',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        children: List.generate(7, (i) {
                          const daysText = ['日', '一', '二', '三', '四', '五', '六'];
                          return CheckboxListTile(
                            title: Text('週${daysText[i]}'),
                            value: days.contains(i),
                            onChanged: (val) {
                              setDialogState(() {
                                val == true ? days.add(i) : days.remove(i);
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ✅ 條件性UI顯示：每月多日選擇器
                  if (repeat == 'monthlyDates') ...[
                    const Text('選擇每月日期',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        children: List.generate(31, (i) {
                          final day = i + 1;
                          return CheckboxListTile(
                            title: Text('$day號'),
                            value: dates.contains(day),
                            onChanged: (val) {
                              setDialogState(() {
                                val == true
                                    ? dates.add(day)
                                    : dates.remove(day);
                              });
                            },
                            controlAffinity: ListTileControlAffinity.leading,
                            dense: true,
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ✅ 條件性UI顯示：EA功能設定
                  if (repeat == 'monthlyOrdinal') ...[
                    const Text('EA功能：每月第N個星期X',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Text('每月第'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: monthlyOrdinal,
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                monthlyOrdinal = value;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1')),
                            DropdownMenuItem(value: 2, child: Text('2')),
                            DropdownMenuItem(value: 3, child: Text('3')),
                            DropdownMenuItem(value: 4, child: Text('4')),
                            DropdownMenuItem(value: 5, child: Text('最後一')),
                          ],
                        ),
                        const SizedBox(width: 8),
                        const Text('個'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: monthlyWeekday,
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                monthlyWeekday = value;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('星期日')),
                            DropdownMenuItem(value: 1, child: Text('星期一')),
                            DropdownMenuItem(value: 2, child: Text('星期二')),
                            DropdownMenuItem(value: 3, child: Text('星期三')),
                            DropdownMenuItem(value: 4, child: Text('星期四')),
                            DropdownMenuItem(value: 5, child: Text('星期五')),
                            DropdownMenuItem(value: 6, child: Text('星期六')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ✅ 條件性UI顯示：自訂間隔重複設定
                  if (repeat == 'interval') ...[
                    const Text('自訂間隔重複',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Text('每'),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              final parsed = int.tryParse(value);
                              if (parsed != null && parsed > 0) {
                                setDialogState(() {
                                  interval = parsed;
                                });
                              }
                            },
                            controller: TextEditingController(
                                text: interval.toString()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: intervalUnit,
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                intervalUnit = value;
                              });
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'days', child: Text('天')),
                            DropdownMenuItem(value: 'weeks', child: Text('週')),
                            DropdownMenuItem(value: 'months', child: Text('月')),
                          ],
                        ),
                        const Text('重複一次'),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ✅ 條件性UI顯示：自訂次數
                  if (repeat == 'custom') ...[
                    TextFormField(
                      initialValue: count.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '重複次數',
                      ),
                      onChanged: (val) {
                        count = int.tryParse(val) ?? 0;
                      },
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ✅ 條件性UI顯示：開始和結束日期（重複模式時才顯示）
                  if (repeat != 'none') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: start ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365 * 5)),
                              );
                              if (date != null) {
                                setDialogState(() {
                                  start = date;
                                });
                              }
                            },
                            child: Text(start == null
                                ? '選擇開始日'
                                : '開始：${DateFormat('yyyy/MM/dd').format(start!)}'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: end ??
                                    DateTime.now()
                                        .add(const Duration(days: 30)),
                                firstDate: start ?? DateTime.now(),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 365 * 5)),
                              );
                              if (date != null) {
                                setDialogState(() {
                                  end = date;
                                });
                              }
                            },
                            child: Text(end == null
                                ? '選擇結束日'
                                : '結束：${DateFormat('yyyy/MM/dd').format(end!)}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                // ✅ 時間驗證：檢查是否設定過去時間
                if (newTime.isBefore(DateTime.now())) {
                  final shouldContinue = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('時間設定警告'),
                        ],
                      ),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('您設定的時間早於現在時間'),
                          SizedBox(height: 8),
                          Text('過去時間的任務不會觸發提醒'),
                          SizedBox(height: 16),
                          Text('建議：'),
                          Text('• 設定未來的時間'),
                          Text('• 或確認這是您想要的設定'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('重新設定時間'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('確定使用過去時間',
                              style: TextStyle(color: Colors.orange)),
                        ),
                      ],
                    ),
                  );

                  if (shouldContinue != true) {
                    return; // 用戶選擇重新設定，停止執行
                  }
                }

                // final bool isMobile =
                //     !kIsWeb && (Platform.isAndroid || Platform.isIOS);
                // final int baseId = _notificationId(index);
                // if (isMobile) {
                //   if (msg.repeatType == 'weekly') {
                //     for (var d in msg.repeatDays) {
                //       // flutterLocalNotificationsPlugin.cancel(baseId + d);
                //     }
                //   }
                //   // flutterLocalNotificationsPlugin.cancel(baseId);
                // }

                // ✅ 更新物件屬性（包含完整功能）
                msg.message = controller.text;
                msg.time = newTime;
                msg.repeatType = repeat;
                msg.repeatDays = days;
                msg.repeatCount = count;
                msg.currentCount = 0;
                msg.repeatMonths = months;
                msg.repeatDates = dates;
                msg.repeatMonthlyOrdinal = monthlyOrdinal;
                msg.repeatMonthlyWeekday = monthlyWeekday;
                msg.repeatInterval = interval;
                msg.repeatIntervalUnit = intervalUnit;
                msg.startDate = start;
                msg.endDate = end;
                // ✅ 智能 sent 狀態：只有未來時間才重設為false
                if (newTime.isAfter(DateTime.now())) {
                  msg.sent = false; // 未來時間：重設為未發送
                } else if (msg.repeatType != 'none') {
                  msg.sent = false; // 重複任務：重設為未發送，等下次週期
                } else {
                  msg.sent = true; // 過去時間的單次任務：保持已發送狀態
                }
                // ✅ 更新時區資訊
                msg.targetTimeZone = editTimeZone;
                msg.targetTimeZoneName = editTimeZoneName;
                // ✅ 更新音效設定
                msg.soundEnabled = editSoundEnabled;
                msg.soundType = 'system';
                msg.soundPath = editSoundId;
                msg.soundVolume = editSoundVolume;
                msg.soundRepeat = editSoundRepeat;
                // ✅ 更新震動設定
                msg.vibrationEnabled = editVibrationEnabled;
                msg.vibrationPattern = editVibrationPattern;
                msg.vibrationIntensity = editVibrationIntensity;
                msg.vibrationRepeat = editVibrationRepeat;

                // ✅ 使用ID更新資料庫
                if (msg.id != null) {
                  try {
                    final dbHelper = DatabaseHelper();
                    await dbHelper.updateMessage(msg.id!, msg.toMap());
                    debugPrint('✅ 排程已更新到資料庫 ID: ${msg.id}');
                  } catch (e) {
                    debugPrint('❌ 更新資料庫失敗: $e');
                  }
                }

                setState(() {
                  // 物件已在上面更新，這裡只需觸發 UI 重繪
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('排程已更新！')),
                );
              },
              child: const Text('確認修改'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 顯示清空所有排程的確認對話框
  void _showClearAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有排程'),
        content: const Text('確定要刪除所有排程嗎？此操作無法復原。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final dbHelper = DatabaseHelper();
                await dbHelper.deleteAllMessages();

                setState(() {
                  _scheduledMessages.clear();
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('所有排程已清空！')),
                );
              } catch (e) {
                debugPrint('❌ 清空資料庫失敗: $e');
              }
            },
            child: const Text('確認', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// ✅ 顯示主題設定對話框
  void _showThemeSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.palette, color: Colors.purple),
              SizedBox(width: 8),
              Text('主題設定'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 深色模式切換
                SwitchListTile(
                  title: const Text('深色模式'),
                  subtitle:
                      Text(_themeManager.isDarkMode ? '已開啟深色主題' : '使用淺色主題'),
                  value: _themeManager.isDarkMode,
                  onChanged: (value) {
                    setDialogState(() {
                      _themeManager.setDarkMode(value);
                    });
                  },
                  secondary: Icon(
                    _themeManager.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: _themeManager.currentColors['primary'],
                  ),
                ),

                const Divider(),

                // 主題色彩選擇
                const Text(
                  '選擇主題色彩',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: ThemeManager.availableThemes.length,
                    itemBuilder: (context, index) {
                      final themeName = ThemeManager.availableThemes[index];
                      final themeColors = ThemeManager.themeColors[themeName]!;
                      final isSelected =
                          _themeManager.currentThemeColor == themeName;

                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            _themeManager.changeThemeColor(themeName);
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: themeColors['primary'],
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                        color: themeColors['primary']!
                                            .withOpacity(0.5),
                                        blurRadius: 8)
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.check_circle
                                      : Icons.palette,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  ThemeManager.getThemeDisplayName(themeName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 顯示App資訊
  void _showAppInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('關於愛傳時APP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('愛傳時 定時訊息App v1.4 (音效支援版)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                '平台：${Platform.isWindows ? 'Windows' : Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : '未知'}'),
            const SizedBox(height: 8),
            const Text('功能：本地排程提醒'),
            const SizedBox(height: 8),
            const Text('儲存：SQLite本地資料庫'),
            const SizedBox(height: 8),
            const Text('✅ 完整功能：',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.green)),
            const Text('• 11個時區支援'),
            const Text('• 智能驗證和衝突檢查'),
            const Text('• 自動日期同步'),
            const Text('• 複製時間到剪貼板'),
            const Text('• 5種音效選擇'),
            const Text('• 音量和重複次數控制'),
            const SizedBox(height: 8),
            const Text('排程功能：', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('• EA功能（每月第N個星期X）'),
            const Text('• 自訂間隔重複'),
            const Text('• 平日模式'),
            const Text('• 每月多日選擇'),
            const Text('• 執行次數控制'),
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

// ========== 愛傳時APP - 第5段：UI建構和列表顯示（完整音效設定UI）==========

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // ✅ 修正：防止底部溢出

      appBar: AppBar(
        title: const Text('愛傳時 定時訊息提醒App'),
        backgroundColor: _themeManager.currentColors['primary'],
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            onSelected: (value) async {
              switch (value) {
                case 'categories':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const TaskCategoryPage()),
                  ).then((_) => _loadCategories());
                  break;
                case 'statistics':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StatisticsPage()),
                  );
                  break;
                case 'import_export':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ImportExportPage()),
                  ).then((_) => _loadMessagesFromDatabase());
                  break;

                case 'theme':
                  _showThemeSettings();
                  break;

                case 'info':
                  _showAppInfo();
                  break;
                case 'logout':
                  await AuthService.signOut();
                  break;
              } // ← switch 結束
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'categories',
                child: ListTile(
                  leading: Icon(Icons.category),
                  title: Text('分類管理'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'statistics',
                child: ListTile(
                  leading: Icon(Icons.bar_chart),
                  title: Text('統計報表'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'import_export',
                child: ListTile(
                  leading: Icon(Icons.import_export),
                  title: Text('匯入匯出'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'theme',
                child: ListTile(
                  leading: Icon(Icons.palette),
                  title: Text('主題設定'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('關於應用'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('登出', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ), // ListTile
              ), // PopupMenuItem
            ],
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16,
            16 + MediaQuery.of(context).padding.bottom), // ✅ 修正：加入底部導航列安全距離
        child: Column(
          children: [
            // 訊息輸入區

            Flexible(
              // ✅ 修正：允許輸入區自動縮放
              child: SingleChildScrollView(
                // ✅ 修正：輸入區可捲動
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('新增排程',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),

                        // 訊息內容輸入
                        TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            labelText: '請輸入訊息內容',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // 時間選擇
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _pickDateTime,
                                icon: const Icon(Icons.schedule),
                                label: Text(_selectedDateTime == null
                                    ? '選擇時間'
                                    : DateFormat('yyyy-MM-dd HH:mm')
                                        .format(_selectedDateTime!)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ✅ 時區選擇器
                        DropdownButtonFormField<String>(
                          value: _selectedTimeZone,
                          decoration: const InputDecoration(
                            labelText: '選擇時區',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.public),
                          ),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              final timeZoneInfo =
                                  AppTimeZones.getTimeZoneById(newValue);
                              if (timeZoneInfo != null) {
                                setState(() {
                                  _selectedTimeZone = newValue;
                                  _selectedTimeZoneName =
                                      timeZoneInfo.displayName;
                                });
                              }
                            }
                          },
                          items: AppTimeZones.supportedZones
                              .map<DropdownMenuItem<String>>(
                                  (SimpleTimeZone zone) {
                            return DropdownMenuItem<String>(
                              value: zone.id,
                              child: Text(zone.displayName),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),

                        // ✅ 時間預覽（如果有選擇時間）
                        if (_selectedDateTime != null &&
                            _selectedTimeZone != 'Asia/Taipei')
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.preview,
                                    size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '時區預覽：${_formatScheduleTime(ScheduledMessage("", _selectedDateTime!, targetTimeZone: _selectedTimeZone, targetTimeZoneName: _selectedTimeZoneName))}',
                                    style: const TextStyle(
                                        fontSize: 14, color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_selectedDateTime != null &&
                            _selectedTimeZone != 'Asia/Taipei')
                          const SizedBox(height: 8),

// ✅ 分類選擇區域
                        DropdownButtonFormField<int>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: '選擇分類（可選）',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          onChanged: (int? newValue) {
                            setState(() {
                              _selectedCategoryId = newValue;
                            });
                          },
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('無分類'),
                            ),
                            ..._categories.map<DropdownMenuItem<int>>(
                                (TaskCategory category) {
                              return DropdownMenuItem<int>(
                                value: category.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: category.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(category.icon, size: 16),
                                    const SizedBox(width: 8),
                                    Text(category.name),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // ✅ 音效設定區域
                        Card(
                          elevation: 2,
                          child: ExpansionTile(
                            leading: Icon(
                              _soundEnabled
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              color: _soundEnabled ? Colors.blue : Colors.grey,
                            ),
                            title: Text(
                              '音效設定',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    _soundEnabled ? Colors.black : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              _soundEnabled
                                  ? '${AudioManager.getSoundById(_selectedSoundId)?.name ?? "預設音效"} - 音量${(_soundVolume * 100).round()}%'
                                  : '已關閉音效',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            initiallyExpanded: _showSoundSettings,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _showSoundSettings = expanded;
                              });
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 音效開關
                                    SwitchListTile(
                                      title: const Text('啟用音效提醒'),
                                      subtitle: const Text('關閉後將使用靜音模式'),
                                      value: _soundEnabled,
                                      onChanged: (value) {
                                        setState(() {
                                          _soundEnabled = value;
                                        });
                                      },
                                      secondary: const Icon(
                                          Icons.notifications_active),
                                    ),

                                    if (_soundEnabled) ...[
                                      const Divider(),

                                      // 音效選擇
                                      const Text(
                                        '選擇音效',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: _selectedSoundId,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.audiotrack),
                                        ),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedSoundId = value;
                                            });
                                          }
                                        },
                                        items: AudioManager.getAllSounds()
                                            .map((sound) {
                                          return DropdownMenuItem<String>(
                                            value: sound.id,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  sound.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                                Text(
                                                  sound.description,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 8),

                                      // 試聽按鈕
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () {
                                            AudioManager.previewSound(
                                                _selectedSoundId);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('🔊 正在播放預覽音效'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                              Icons.play_circle_outline,
                                              size: 18),
                                          label: const Text('試聽'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // 音量控制
                                      const Text(
                                        '音量設定',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.volume_down,
                                              size: 20),
                                          Expanded(
                                            child: Slider(
                                              value: _soundVolume,
                                              min: 0.1,
                                              max: 1.0,
                                              divisions: 9,
                                              label:
                                                  '${(_soundVolume * 100).round()}%',
                                              onChanged: (value) {
                                                setState(() {
                                                  _soundVolume = value;
                                                });
                                              },
                                            ),
                                          ),
                                          const Icon(Icons.volume_up, size: 20),
                                          SizedBox(
                                            width: 40,
                                            child: Text(
                                              '${(_soundVolume * 100).round()}%',
                                              textAlign: TextAlign.center,
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // 重複次數
                                      const Text(
                                        '重複次數',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          const Text('播放'),
                                          const SizedBox(width: 8),
                                          DropdownButton<int>(
                                            value: _soundRepeat,
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _soundRepeat = value;
                                                });
                                              }
                                            },
                                            items: [1, 2, 3, 5].map((count) {
                                              return DropdownMenuItem<int>(
                                                value: count,
                                                child: Text('$count 次'),
                                              );
                                            }).toList(),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('重複'),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ✅ 震動設定區域
                        Card(
                          elevation: 2,
                          child: ExpansionTile(
                            leading: Icon(
                              _vibrationEnabled
                                  ? Icons.vibration
                                  : Icons.phonelink_erase,
                              color: _vibrationEnabled
                                  ? Colors.purple
                                  : Colors.grey,
                            ),
                            title: Text(
                              '震動設定',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _vibrationEnabled
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              _vibrationEnabled
                                  ? '${VibrationManager.getVibrationPatternById(_selectedVibrationPattern)?.name ?? "預設震動"} - 強度${(_vibrationIntensity * 100).round()}%'
                                  : '已關閉震動',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            initiallyExpanded: _showVibrationSettings,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                _showVibrationSettings = expanded;
                              });
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 震動開關
                                    SwitchListTile(
                                      title: const Text('啟用震動提醒'),
                                      subtitle: const Text('關閉後將使用靜音模式'),
                                      value: _vibrationEnabled,
                                      onChanged: (value) {
                                        setState(() {
                                          _vibrationEnabled = value;
                                        });
                                      },
                                      secondary: const Icon(Icons.vibration),
                                    ),

                                    if (_vibrationEnabled) ...[
                                      const Divider(),

                                      // 震動模式選擇
                                      const Text(
                                        '選擇震動模式',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      DropdownButtonFormField<String>(
                                        value: _selectedVibrationPattern,
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.vibration),
                                        ),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedVibrationPattern = value;
                                            });
                                          }
                                        },
                                        items: VibrationManager
                                                .getAllVibrationPatterns()
                                            .map((pattern) {
                                          return DropdownMenuItem<String>(
                                            value: pattern.id,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  pattern.name,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                                Text(
                                                  pattern.description,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 8),

                                      // 試震按鈕
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () {
                                            VibrationManager.previewVibration(
                                                _selectedVibrationPattern);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text('📳 正在播放預覽震動'),
                                                duration: Duration(seconds: 1),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.vibration,
                                              size: 18),
                                          label: const Text('試震'),
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // 震動強度控制
                                      const Text(
                                        '震動強度',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          const Icon(Icons.vibration,
                                              size: 20, color: Colors.grey),
                                          Expanded(
                                            child: Slider(
                                              value: _vibrationIntensity,
                                              min: 0.1,
                                              max: 1.0,
                                              divisions: 9,
                                              label:
                                                  '${(_vibrationIntensity * 100).round()}%',
                                              onChanged: (value) {
                                                setState(() {
                                                  _vibrationIntensity = value;
                                                });
                                              },
                                            ),
                                          ),
                                          const Icon(Icons.vibration, size: 20),
                                          SizedBox(
                                            width: 40,
                                            child: Text(
                                              '${(_vibrationIntensity * 100).round()}%',
                                              textAlign: TextAlign.center,
                                              style:
                                                  const TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      // 重複次數
                                      const Text(
                                        '重複次數',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Row(
                                        children: [
                                          const Text('震動'),
                                          const SizedBox(width: 8),
                                          DropdownButton<int>(
                                            value: _vibrationRepeat,
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _vibrationRepeat = value;
                                                });
                                              }
                                            },
                                            items: [1, 2, 3, 5].map((count) {
                                              return DropdownMenuItem<int>(
                                                value: count,
                                                child: Text('$count 次'),
                                              );
                                            }).toList(),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('重複'),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

// 重複模式選擇
                        DropdownButtonFormField<String>(
                          value: _repeatType,
                          decoration: const InputDecoration(
                            labelText: '重複模式',
                            border: OutlineInputBorder(),
                          ),
                          // ✅ 智能同步功能整合：使用 _onRepeatTypeChanged
                          onChanged: (value) => _onRepeatTypeChanged(value!),
                          items: const [
                            DropdownMenuItem(value: 'none', child: Text('不重複')),
                            DropdownMenuItem(value: 'daily', child: Text('每日')),
                            DropdownMenuItem(
                                value: 'weekly', child: Text('每週')),
                            DropdownMenuItem(
                                value: 'weekdays', child: Text('平日 (週一至週五)')),
                            DropdownMenuItem(
                                value: 'monthly', child: Text('每月')),
                            DropdownMenuItem(
                                value: 'monthlyDates', child: Text('每月指定日期')),
                            DropdownMenuItem(
                                value: 'monthlyOrdinal',
                                child: Text('每月第幾個星期幾')),
                            DropdownMenuItem(
                                value: 'yearly', child: Text('每年')),
                            DropdownMenuItem(
                                value: 'interval', child: Text('自訂間隔')),
                            DropdownMenuItem(
                                value: 'custom', child: Text('自訂次數')),
                          ],
                        ),

                        // ✅ 條件性UI顯示：每週星期選擇器
                        if (_repeatType == 'weekly') ...[
                          const SizedBox(height: 8),
                          const Text('選擇星期幾',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (int i = 0; i < 7; i++)
                                FilterChip(
                                  label: Text(
                                      ['日', '一', '二', '三', '四', '五', '六'][i]),
                                  selected: _selectedWeekdays.contains(i),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedWeekdays.add(i);
                                      } else {
                                        _selectedWeekdays.remove(i);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],

                        // ✅ 條件性UI顯示：每月多日選擇器
                        if (_repeatType == 'monthly') ...[
                          const SizedBox(height: 8),
                          const Text('選擇每月日期',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (int day = 1; day <= 31; day++)
                                FilterChip(
                                  label: Text('$day'),
                                  selected: _selectedDates.contains(day),
                                  onSelected: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _selectedDates.add(day);
                                      } else {
                                        _selectedDates.remove(day);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],

                        // ✅ 條件性UI顯示：EA功能設定
                        if (_repeatType == 'monthly_ordinal') ...[
                          const SizedBox(height: 8),
                          const Text('EA功能：每月第N個星期X',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('每月第'),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: _monthlyOrdinal,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _monthlyOrdinal = value;
                                    });
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(value: 1, child: Text('1')),
                                  DropdownMenuItem(value: 2, child: Text('2')),
                                  DropdownMenuItem(value: 3, child: Text('3')),
                                  DropdownMenuItem(value: 4, child: Text('4')),
                                  DropdownMenuItem(
                                      value: 5, child: Text('最後一')),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Text('個'),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: _monthlyWeekday,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _monthlyWeekday = value;
                                    });
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                      value: 0, child: Text('星期日')),
                                  DropdownMenuItem(
                                      value: 1, child: Text('星期一')),
                                  DropdownMenuItem(
                                      value: 2, child: Text('星期二')),
                                  DropdownMenuItem(
                                      value: 3, child: Text('星期三')),
                                  DropdownMenuItem(
                                      value: 4, child: Text('星期四')),
                                  DropdownMenuItem(
                                      value: 5, child: Text('星期五')),
                                  DropdownMenuItem(
                                      value: 6, child: Text('星期六')),
                                ],
                              ),
                            ],
                          ),
                        ],

                        // ✅ 條件性UI顯示：自訂間隔重複設定
                        if (_repeatType == 'repeat_interval') ...[
                          const SizedBox(height: 8),
                          const Text('自訂間隔重複',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Text('每'),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (value) {
                                    final parsed = int.tryParse(value);
                                    if (parsed != null && parsed > 0) {
                                      setState(() {
                                        _repeatInterval = parsed;
                                      });
                                    }
                                  },
                                  controller: TextEditingController(
                                      text: _repeatInterval.toString()),
                                ),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: _repeatIntervalUnit,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _repeatIntervalUnit = value;
                                    });
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                      value: 'days', child: Text('天')),
                                  DropdownMenuItem(
                                      value: 'weeks', child: Text('週')),
                                  DropdownMenuItem(
                                      value: 'months', child: Text('月')),
                                ],
                              ),
                              const Text('重複一次'),
                            ],
                          ),
                        ],

                        // ✅ 條件性UI顯示：開始和結束日期（重複模式時才顯示）
                        if (_repeatType != 'none') ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate ?? DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365 * 5)),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _startDate = date;
                                      });
                                    }
                                  },
                                  child: Text(_startDate == null
                                      ? '選擇開始日'
                                      : '開始：${DateFormat('yyyy/MM/dd').format(_startDate!)}'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate ??
                                          DateTime.now()
                                              .add(const Duration(days: 30)),
                                      firstDate: _startDate ?? DateTime.now(),
                                      lastDate: DateTime.now()
                                          .add(const Duration(days: 365 * 5)),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _endDate = date;
                                      });
                                    }
                                  },
                                  child: Text(_endDate == null
                                      ? '選擇結束日'
                                      : '結束：${DateFormat('yyyy/MM/dd').format(_endDate!)}'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addMessage,
                            icon: const Icon(Icons.add),
                            label: const Text('新增排程'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _themeManager.currentColors['primary'],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ), // 👈 補這行：關閉 SingleChildScrollView
            ),
          ],
        ),
      ),
      bottomSheet: DraggableScrollableSheet(
        initialChildSize: 0.13,
        minChildSize: 0.08,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: ListView(
              controller: scrollController,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.list, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text('排程列表 (${_scheduledMessages.length})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_scheduledMessages.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                        child: Text('尚無排程訊息',
                            style: TextStyle(color: Colors.grey))),
                  )
                else
                  ...List.generate(_scheduledMessages.length, (index) {
                    final message = _scheduledMessages[index];
                    final isOverdue =
                        DateTime.now().isAfter(message.time) && !message.sent;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      color: message.sent
                          ? Colors.green.shade50
                          : isOverdue
                              ? Colors.red.shade50
                              : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: message.sent
                              ? Colors.green
                              : isOverdue
                                  ? Colors.red
                                  : Colors.purple,
                          child: Icon(
                              message.sent
                                  ? Icons.check
                                  : isOverdue
                                      ? Icons.warning
                                      : Icons.schedule,
                              color: Colors.white),
                        ),
                        title: Text(message.message,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            '🕐 ${DateFormat('yyyy/MM/dd HH:mm').format(message.time)}'),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('編輯')),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('刪除',
                                    style: TextStyle(color: Colors.red))),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') _editMessage(index);
                            if (value == 'delete') _deleteMessage(index);
                          },
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    ); // Scaffold
  }

  /// ✅ 取得任務狀態文字
  String _getTaskStatusText(ScheduledMessage message, bool isOverdue) {
    if (message.repeatType == 'none') {
      // 單次任務
      return message.sent
          ? '✅ 已發送'
          : isOverdue
              ? '⚠️ 逾時未發送'
              : '⏳ 等待發送';
    } else {
      // 重複任務
      if (message.sent) {
        return '🔄 等待下次觸發';
      } else {
        return isOverdue ? '⚠️ 逾時未發送' : '⏳ 等待發送';
      }
    }
  }

  /// ✅ 取得任務狀態顏色
  Color _getTaskStatusColor(ScheduledMessage message, bool isOverdue) {
    if (message.repeatType == 'none') {
      // 單次任務
      return message.sent
          ? Colors.green
          : isOverdue
              ? Colors.red
              : Colors.orange;
    } else {
      // 重複任務
      if (message.sent) {
        return Colors.blue; // 藍色表示等待下次
      } else {
        return isOverdue ? Colors.red : Colors.orange;
      }
    }
  }

  /// ✅ 載入分類資料
  Future<void> _loadCategories() async {
    try {
      final categories = await _databaseHelper.getAllCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      debugPrint('❌ 載入分類失敗: $e');
    }
  }

  /// ✅ 顯示標籤選擇對話框
}



// ========== 程式結束 ==========


