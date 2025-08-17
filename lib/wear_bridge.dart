// lib/wear_bridge.dart
import 'package:flutter/services.dart';

/// Wear OS(안드로이드 네이티브)와의 메서드 채널 브리지.
/// MainActivity.kt 의 CHANNEL = "app.dive/wear" 과 반드시 동일해야 합니다.
class WearBridge {
  static const MethodChannel _ch = MethodChannel('app.dive/wear');

  // ---------------------------------------------------------------------------
  // 기본 유틸: 값들을 Wear DataLayer에서 허용하는 프리미티브로 정제
  // (String/num/bool/List<String>) 외 타입은 String으로 변환
  // ---------------------------------------------------------------------------
  static Map<String, Object?> _sanitizeMap(Map<String, dynamic> m) {
    Object? coerce(dynamic v) {
      if (v == null) return null;
      if (v is String || v is bool) return v;
      if (v is num) return v; // int/double/num OK
      if (v is List) {
        // 문자열 리스트만 통과
        if (v.every((e) => e is String)) return List<String>.from(v);
        return v.map((e) => e?.toString() ?? '').toList();
      }
      // 그 외는 문자열로
      return v.toString();
    }

    return m.map<String, Object?>((k, v) => MapEntry(k, coerce(v)));
  }

  // ---------------------------------------------------------------------------
  // 1) 현재 날씨 전송 -> MainActivity.sendWeatherToWatch() 매칭
  // path: "/weather" (네이티브에서 설정)
  // ---------------------------------------------------------------------------
  static Future<void> sendWeather(Map<String, dynamic> weather) async {
    try {
      await _ch.invokeMethod('sendWeather', _sanitizeMap(weather));
    } on MissingPluginException catch (e) {
      // 네이티브 미구현 시 디버그에만 표시 (앱은 계속 동작)
      // ignore: avoid_print
      print('sendWeather MissingPluginException: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 2) 조석/물때 전송 -> MainActivity.sendTideToWatch()
  // path: "/tide"
  // ---------------------------------------------------------------------------
  static Future<void> sendTide(Map<String, dynamic> tide) async {
    try {
      await _ch.invokeMethod('sendTide', _sanitizeMap(tide));
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendTide MissingPluginException: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 3) 수온 등 온도 전송 -> MainActivity.sendTempToWatch()
  // path: "/temp"
  // ---------------------------------------------------------------------------
  static Future<void> sendTemp(Map<String, dynamic> temp) async {
    try {
      await _ch.invokeMethod('sendTemp', _sanitizeMap(temp));
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendTemp MissingPluginException: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 4) 낚시포인트 리스트 전송 -> MainActivity.sendFishingPointsToWatch()
  // path: "/fishing_points" , 키: "points" (DataMapArrayList)
  //
  // items 각 요소의 권장 키:
  //   name, point_nm, addr, dpwt, material, tide_time, target, point_dt, photo,
  //   lat(double), lon(double), distance_km(double)
  // ---------------------------------------------------------------------------
  static Future<void> sendFishingPoints(
      List<Map<String, dynamic>> items) async {
    // 각 요소를 프리미티브로 정제 + lat/lon/distance_km 는 반드시 double 보장
    final payload = items.map<Map<String, Object?>>((p) {
      double toDouble(dynamic v) {
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '') ?? 0.0;
      }
      final m = Map<String, Object?>.from(_sanitizeMap(p));
      m['lat'] = toDouble(p['lat']);
      m['lon'] = toDouble(p['lon']);
      if (p.containsKey('distance_km')) {
        m['distance_km'] = toDouble(p['distance_km']);
      }
      return m;
    }).toList();

    try {
      await _ch.invokeMethod('sendFishingPoints', {'points': payload});
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendFishingPoints MissingPluginException: $e');
    }
  }
  static Future<void> sendTempStations(List<Map<String, dynamic>> stations) async {
    // 각 스테이션 맵을 프리미티브 타입으로 정제
    final payload = stations.map<Map<String, Object?>>((m) {
      final mm = Map<String, Object?>.from(_sanitizeMap(m));
      // key 표준화(없으면 빈 문자열)
      mm['name']        = (mm['name'] ?? '').toString();
      mm['temp']        = (mm['temp'] ?? '').toString();        // "26.9" 형태 권장
      mm['obs_time']    = (mm['obs_time'] ?? '').toString();    // "2025.8.17 01:00 A.M." 등
      mm['distance_km'] = (mm['distance_km'] ?? '').toString(); // "3.2" 형태 권장
      return mm;
    }).toList();

    try {
      await _ch.invokeMethod('sendTempStations', {'stations': payload});
    } on MissingPluginException catch (e) {
      // ignore: avoid_print
      print('sendTempStations MissingPluginException: $e');
    }
  }
}
