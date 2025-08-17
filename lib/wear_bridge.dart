import 'package:flutter/services.dart';

/// Wear OS(안드로이드 네이티브)와의 메서드 채널 브리지.
/// MainActivity.kt 의 CHANNEL 과 반드시 동일해야 합니다.
class WearBridge {
  static const MethodChannel _ch = MethodChannel('app.dive/wear');

  // DataLayer가 받아줄 수 있는 프리미티브로 변환
  static Map<String, Object?> _sanitizeMap(Map<String, dynamic> m) {
    Object? coerce(dynamic v) {
      if (v == null) return null;
      if (v is String || v is bool || v is num) return v;
      if (v is List) {
        if (v.every((e) => e is String)) return List<String>.from(v);
        return v.map((e) => e?.toString() ?? '').toList();
      }
      return v.toString();
    }
    return m.map<String, Object?>((k, v) => MapEntry(k, coerce(v)));
  }

  /// 1) 파도/날씨 단건 전송
  static Future<void> sendWeather(Map<String, dynamic> weather) async {
    try {
      await _ch.invokeMethod('sendWeather', _sanitizeMap(weather));
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendWeather MissingPluginException: $e');
    }
  }

  /// 2) 물때/조석 전송
  static Future<void> sendTide(Map<String, dynamic> tide) async {
    try {
      await _ch.invokeMethod('sendTide', _sanitizeMap(tide));
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendTide MissingPluginException: $e');
    }
  }

  /// 3) 수온 단건 전송 (필요 시)
  static Future<void> sendTemp(Map<String, dynamic> temp) async {
    try {
      await _ch.invokeMethod('sendTemp', _sanitizeMap(temp));
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendTemp MissingPluginException: $e');
    }
  }

  /// 4) 주변 관측소 수온 여러 건 전송
  /// 네이티브: sendTempStations(points: List<Map>)
  static Future<void> sendTempStations(List<Map<String, dynamic>> stations) async {
    // 각 요소를 문자열/숫자 등 프리미티브로 보정
    final payload = stations.map<Map<String, Object?>>((p) {
      final m = Map<String, Object?>.from(_sanitizeMap(p));
      return m;
    }).toList();
    try {
      await _ch.invokeMethod('sendTempStations', {'points': payload});
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendTempStations MissingPluginException: $e');
    }
  }

  /// 5) 낚시 포인트 리스트 전송(선택)
  static Future<void> sendFishingPoints(List<Map<String, dynamic>> items) async {
    final payload = items.map<Map<String, Object?>>((p) {
      double toDouble(dynamic v) {
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '') ?? 0.0;
      }
      final m = Map<String, Object?>.from(_sanitizeMap(p));
      if (p.containsKey('lat')) m['lat'] = toDouble(p['lat']);
      if (p.containsKey('lon')) m['lon'] = toDouble(p['lon']);
      if (p.containsKey('distance_km')) m['distance_km'] = toDouble(p['distance_km']);
      return m;
    }).toList();
    try {
      await _ch.invokeMethod('sendFishingPoints', {'points': payload});
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendFishingPoints MissingPluginException: $e');
    }
  }
}
