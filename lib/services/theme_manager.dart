import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager extends ChangeNotifier {
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  String _currentThemeColor = 'purple';
  bool _isDarkMode = false;

  String get currentThemeColor => _currentThemeColor;
  bool get isDarkMode => _isDarkMode;

  static const Map<String, Map<String, Color>> themeColors = {
    'purple': {
      'primary': Color(0xFF9C27B0),
      'primaryDark': Color(0xFF7B1FA2),
      'accent': Color(0xFFE1BEE7),
      'background': Color(0xFFF3E5F5),
    },
    'pink': {
      'primary': Color(0xFFE91E63),
      'primaryDark': Color(0xFFC2185B),
      'accent': Color(0xFFF8BBD9),
      'background': Color(0xFFFCE4EC),
    },
    'blue': {
      'primary': Color(0xFF1565C0),
      'primaryDark': Color(0xFF0D47A1),
      'accent': Color(0xFF90CAF9),
      'background': Color(0xFFE3F2FD),
    },
    'green': {
      'primary': Color(0xFF2E7D32),
      'primaryDark': Color(0xFF1B5E20),
      'accent': Color(0xFFA5D6A7),
      'background': Color(0xFFE8F5E9),
    },
    'midnight': {
      'primary': Color(0xFF37474F),
      'primaryDark': Color(0xFF263238),
      'accent': Color(0xFF78909C),
      'background': Color(0xFF121212),
    },
    'neon': {
      'primary': Color(0xFF00BCD4),
      'primaryDark': Color(0xFF006064),
      'accent': Color(0xFF00E5FF),
      'background': Color(0xFF0A0A1A),
    },
    'japanese': {
      'primary': Color(0xFFAD8B73),
      'primaryDark': Color(0xFF795548),
      'accent': Color(0xFFFFCCBC),
      'background': Color(0xFFFFF8F0),
    },
    'gold': {
      'primary': Color(0xFFB8860B),
      'primaryDark': Color(0xFF7B5800),
      'accent': Color(0xFFFFD700),
      'background': Color(0xFF1A1A1A),
    },
  };

  Map<String, Color> get currentColors => themeColors[_currentThemeColor]!;

  ThemeData get lightTheme {
    final colors = currentColors;
    final bool isDarkBg = _currentThemeColor == 'midnight' ||
        _currentThemeColor == 'neon' ||
        _currentThemeColor == 'gold';
    return ThemeData(
      brightness: isDarkBg ? Brightness.dark : Brightness.light,
      primaryColor: colors['primary'],
      scaffoldBackgroundColor:
          isDarkBg ? colors['background'] : Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: colors['primary'],
        foregroundColor: Colors.white,
        elevation: 2,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: _currentThemeColor == 'neon' ? 2.0 : 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: isDarkBg ? Colors.grey[850] : Colors.white,
        elevation: _currentThemeColor == 'japanese' ? 1 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            _currentThemeColor == 'japanese' ? 16 : 12,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors['primary'],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              _currentThemeColor == 'japanese' ? 24 : 8,
            ),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors['primary'],
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors['primary'],
      ),
      colorScheme: ColorScheme(
        brightness: isDarkBg ? Brightness.dark : Brightness.light,
        primary: colors['primary']!,
        onPrimary: Colors.white,
        secondary: colors['accent']!,
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
        surface:
            isDarkBg ? (colors['background'] ?? Colors.black) : Colors.white,
        onSurface: isDarkBg ? Colors.white : Colors.black,
      ),
    );
  }

  ThemeData get darkTheme => lightTheme;
  ThemeData get currentTheme => lightTheme;

  Future<void> changeThemeColor(String colorName) async {
    if (themeColors.containsKey(colorName)) {
      _currentThemeColor = colorName;
      await _saveThemeSettings();
      notifyListeners();
    }
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemeSettings();
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
    await _saveThemeSettings();
    notifyListeners();
  }

  Future<void> loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentThemeColor = prefs.getString('theme_color') ?? 'purple';
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 載入主題設定失敗: $e');
    }
  }

  Future<void> _saveThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_color', _currentThemeColor);
      await prefs.setBool('is_dark_mode', _isDarkMode);
    } catch (e) {
      debugPrint('❌ 儲存主題設定失敗: $e');
    }
  }

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

  static String getThemeDisplayName(String colorName) {
    const Map<String, String> displayNames = {
      'purple': '💜 浪漫紫',
      'pink': '🩷 玫瑰粉',
      'blue': '🌊 深海藍',
      'green': '🍃 自然綠',
      'midnight': '🌙 午夜黑',
      'neon': '🤖 科技霓虹',
      'japanese': '🌸 日系手帳',
      'gold': '🔥 橘金商務',
    };
    return displayNames[colorName] ?? colorName;
  }

  static List<String> get availableThemes => themeColors.keys.toList();
}
