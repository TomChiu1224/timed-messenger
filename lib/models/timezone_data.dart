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
