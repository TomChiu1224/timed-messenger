import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class TimeZoneInfo {
  final String id;
  final String displayName;
  final String shortName;
  final String utcOffset;

  const TimeZoneInfo({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.utcOffset,
  });
}

class AppTimeZones {
  static const List<TimeZoneInfo> supportedZones = [
    TimeZoneInfo(
      id: 'Asia/Taipei',
      displayName: '台灣時間',
      shortName: 'CST',
      utcOffset: '+08:00',
    ),
    TimeZoneInfo(
      id: 'Asia/Tokyo',
      displayName: '日本時間',
      shortName: 'JST',
      utcOffset: '+09:00',
    ),
    TimeZoneInfo(
      id: 'Asia/Seoul',
      displayName: '韓國時間',
      shortName: 'KST',
      utcOffset: '+09:00',
    ),
    TimeZoneInfo(
      id: 'Asia/Shanghai',
      displayName: '中國時間',
      shortName: 'CST',
      utcOffset: '+08:00',
    ),
    TimeZoneInfo(
      id: 'Asia/Hong_Kong',
      displayName: '香港時間',
      shortName: 'HKT',
      utcOffset: '+08:00',
    ),
    TimeZoneInfo(
      id: 'Asia/Singapore',
      displayName: '新加坡時間',
      shortName: 'SGT',
      utcOffset: '+08:00',
    ),
    TimeZoneInfo(
      id: 'Asia/Bangkok',
      displayName: '泰國時間',
      shortName: 'ICT',
      utcOffset: '+07:00',
    ),
    TimeZoneInfo(
      id: 'America/New_York',
      displayName: '美東時間',
      shortName: 'EST',
      utcOffset: '-05:00',
    ),
    TimeZoneInfo(
      id: 'America/Los_Angeles',
      displayName: '美西時間',
      shortName: 'PST',
      utcOffset: '-08:00',
    ),
    TimeZoneInfo(
      id: 'Europe/London',
      displayName: '英國時間',
      shortName: 'GMT',
      utcOffset: '+00:00',
    ),
    TimeZoneInfo(
      id: 'Europe/Paris',
      displayName: '法國時間',
      shortName: 'CET',
      utcOffset: '+01:00',
    ),
  ];

  static TimeZoneInfo? getTimeZoneById(String id) {
    try {
      return supportedZones.firstWhere((zone) => zone.id == id);
    } catch (e) {
      return null;
    }
  }

  static TimeZoneInfo get defaultZone => supportedZones.first;
}

class TimeZoneUtils {
  static void initTimeZones() {
    try {
      tz.initializeTimeZones();
      print('✅ 時區資料初始化完成');
    } catch (e) {
      print('❌ 時區初始化失敗: $e');
    }
  }

  static DateTime convertToTargetTimeZone(DateTime localTime, String targetTimeZoneId) {
    try {
      final location = tz.getLocation(targetTimeZoneId);
      final tzDateTime = tz.TZDateTime.from(localTime, location);
      return tzDateTime;
    } catch (e) {
      print('❌ 時區轉換失敗: $e');
      return localTime;
    }
  }

  static DateTime convertToLocalTime(DateTime targetTime, String targetTimeZoneId) {
    try {
      final targetLocation = tz.getLocation(targetTimeZoneId);
      final localLocation = tz.local;

      final targetTzTime = tz.TZDateTime(
        targetLocation,
        targetTime.year,
        targetTime.month,
        targetTime.day,
        targetTime.hour,
        targetTime.minute,
        targetTime.second,
      );

      final localTzTime = tz.TZDateTime.from(targetTzTime, localLocation);
      return localTzTime;
    } catch (e) {
      print('❌ 時區轉換失敗: $e');
      return targetTime;
    }
  }

  static String formatDualTimeZone(DateTime localTime, String targetTimeZoneId, String targetTimeZoneName) {
    try {
      final targetTime = convertToTargetTimeZone(localTime, targetTimeZoneId);
      final localZoneName = _getLocalTimeZoneName();

      final targetFormat = DateFormat('HH:mm');
      final targetPeriod = _getPeriodText(targetTime.hour);
      final localPeriod = _getPeriodText(localTime.hour);

      return '$targetTimeZoneName：${targetFormat.format(targetTime)}（$targetPeriod）/ $localZoneName：${targetFormat.format(localTime)}（$localPeriod）';
    } catch (e) {
      print('❌ 雙時區格式化失敗: $e');
      return DateFormat('yyyy-MM-dd HH:mm').format(localTime);
    }
  }

  static String formatFullDualTimeZone(DateTime localTime, String targetTimeZoneId, String targetTimeZoneName) {
    try {
      final targetTime = convertToTargetTimeZone(localTime, targetTimeZoneId);
      final localZoneName = _getLocalTimeZoneName();

      final dateFormat = DateFormat('yyyy/MM/dd');
      final timeFormat = DateFormat('HH:mm');

      final sameDateAsLocal = dateFormat.format(targetTime) == dateFormat.format(localTime);

      if (sameDateAsLocal) {
        return '${dateFormat.format(localTime)} $targetTimeZoneName：${timeFormat.format(targetTime)} / $localZoneName：${timeFormat.format(localTime)}';
      } else {
        return '$targetTimeZoneName：${dateFormat.format(targetTime)} ${timeFormat.format(targetTime)} / $localZoneName：${dateFormat.format(localTime)} ${timeFormat.format(localTime)}';
      }
    } catch (e) {
      print('❌ 完整時區格式化失敗: $e');
      return DateFormat('yyyy-MM-dd HH:mm').format(localTime);
    }
  }

  static String _getLocalTimeZoneName() {
    return '台灣時間';
  }

  static String _getPeriodText(int hour) {
    if (hour >= 6 && hour < 12) {
      return '早上';
    } else if (hour >= 12 && hour < 18) {
      return '下午';
    } else if (hour >= 18 && hour < 24) {
      return '晚上';
    } else {
      return '凌晨';
    }
  }

  static String getTimeDifference(String fromZoneId, String toZoneId) {
    try {
      final now = DateTime.now();
      final fromLocation = tz.getLocation(fromZoneId);
      final toLocation = tz.getLocation(toZoneId);

      final fromTime = tz.TZDateTime.from(now, fromLocation);
      final toTime = tz.TZDateTime.from(now, toLocation);

      final diff = toTime.difference(fromTime).inHours;

      if (diff > 0) {
        return '+$diff 小時';
      } else if (diff < 0) {
        return '$diff 小時';
      } else {
        return '相同時區';
      }
    } catch (e) {
      print('❌ 時差計算失敗: $e');
      return '未知';
    }
  }

  static bool isValidTimeZone(String timeZoneId) {
    try {
      tz.getLocation(timeZoneId);
      return true;
    } catch (e) {
      return false;
    }
  }

  static List<Map<String, String>> getTimeZoneDropdownItems() {
    return AppTimeZones.supportedZones.map((zone) {
      final timeDiff = getTimeDifference('Asia/Taipei', zone.id);
      return {
        'id': zone.id,
        'display': '${zone.displayName} ($timeDiff)',
        'name': zone.displayName,
      };
    }).toList();
  }
}