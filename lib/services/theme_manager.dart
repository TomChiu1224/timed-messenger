import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🎨 主題管理器 - 負責主題色彩的切換和儲存
class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  // 當前主題設定
  String _currentThemeColor = 'purple';
  bool _isDarkMode = false;

  // Getters
  String get currentThemeColor => _currentThemeColor;
  bool get isDarkMode => _isDarkMode;

  /// 預設主題色彩方案
  static const Map<String, Map<String, Color>> themeColors = {
    'purple': {
      'primary': Color(0xFF9C27B0),
      'primaryDark': Color(0xFF7B1FA2),
      'accent': Color(0xFFE1BEE7),
      'background': Color(0xFFF3E5F5),
    },
    'blue': {
      'primary': Color(0xFF2196F3),
      'primaryDark': Color(0xFF1976D2),
      'accent': Color(0xFFBBDEFB),
      'background': Color(0xFFE3F2FD),
    },
    'green': {
      'primary': Color(0xFF4CAF50),
      'primaryDark': Color(0xFF388E3C),
      'accent': Color(0xFFC8E6C9),
      'background': Color(0xFFE8F5E8),
    },
    'orange': {
      'primary': Color(0xFFFF9800),
      'primaryDark': Color(0xFFF57C00),
      'accent': Color(0xFFFFCC02),
      'background': Color(0xFFFFF3E0),
    },
    'pink': {
      'primary': Color(0xFFE91E63),
      'primaryDark': Color(0xFFC2185B),
      'accent': Color(0xFFF8BBD9),
      'background': Color(0xFFFCE4EC),
    },
  };

  /// 取得當前主題色彩配置
  Map<String, Color> get currentColors => themeColors[_currentThemeColor]!;

  /// 建立淺色主題
  ThemeData get lightTheme {
    final colors = currentColors;
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: _createMaterialColor(colors['primary']!),
      primaryColor: colors['primary'],
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: colors['primary'],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors['primary'],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors['primary'],
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors['primary'],
      ),
    );
  }

  /// 建立深色主題
  ThemeData get darkTheme {
    final colors = currentColors;
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: _createMaterialColor(colors['primary']!),
      primaryColor: colors['primary'],
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: AppBarTheme(
        backgroundColor: colors['primaryDark'],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      cardTheme: CardThemeData(
        color: Colors.grey[800],
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors['primary'],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors['primary'],
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors['primary'],
      ),
    );
  }

  /// 取得當前主題
  ThemeData get currentTheme => _isDarkMode ? darkTheme : lightTheme;

  /// 切換主題色彩
  Future<void> changeThemeColor(String colorName) async {
    if (themeColors.containsKey(colorName)) {
      _currentThemeColor = colorName;
      await _saveThemeSettings();
      notifyListeners();
    }
  }

  /// 切換深色/淺色模式
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemeSettings();
    notifyListeners();
  }

  /// 設定深色模式
  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _saveThemeSettings();
    notifyListeners();
  }

  /// 載入已儲存的主題設定
  Future<void> loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentThemeColor = prefs.getString('theme_color') ?? 'purple';
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      notifyListeners();
    } catch (e) {
      print('❌ 載入主題設定失敗: $e');
    }
  }

  /// 儲存主題設定到本地
  Future<void> _saveThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_color', _currentThemeColor);
      await prefs.setBool('is_dark_mode', _isDarkMode);
    } catch (e) {
      print('❌ 儲存主題設定失敗: $e');
    }
  }

  /// 建立MaterialColor（Flutter主題系統需要）
  MaterialColor _createMaterialColor(Color color) {
    List strengths = <double>[.05];
    Map<int, Color> swatch = <int, Color>{};
    final int r = color.red, g = color.green, b = color.blue;

    for (int i = 1; i < 10; i++) {
      strengths.add(0.1 * i);
    }
    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  /// 取得主題色彩的顯示名稱
  static String getThemeDisplayName(String colorName) {
    const Map<String, String> displayNames = {
      'purple': '典雅紫',
      'blue': '海洋藍',
      'green': '自然綠',
      'orange': '活力橙',
      'pink': '浪漫粉',
    };
    return displayNames[colorName] ?? colorName;
  }

  /// 取得所有可用的主題色彩
  static List<String> get availableThemes => themeColors.keys.toList();
}