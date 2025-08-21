import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../env.dart';
import 'tide_models.dart';

/// 바다타임 API 호출 전용 (tide_api.dart 없이 이 파일에서 처리)
class BadaTimeApi {
  final String baseUrl;   // 예: https://www.badatime.com/DIVE
  final String serviceKey;
  final double? lat;
  final double? lon;
  final String? areaId;

  BadaTimeApi({
    required this.baseUrl,
    required this.serviceKey,
    this.lat,
    this.lon,
    this.areaId,
  });

  Uri _buildUri() {
    final tideUrl = '$baseUrl/tide';
    return Uri.parse(tideUrl).replace(queryParameters: {
      'key': serviceKey,
      if (areaId != null) 'area': areaId!,
      if (lat != null) 'lat': lat!.toStringAsFixed(6),
      if (lon != null) 'lon': lon!.toStringAsFixed(6),
    });
  }

  Future<List<TideDay>> fetch7Days() async {
    final res = await http.get(_buildUri());
    if (res.statusCode != 200) {
      throw Exception('Badatime API error: ${res.statusCode}');
    }
    final body = res.body.trim();
    final decoded = json.decode(body);
    if (decoded is! List) {
      throw Exception('Unexpected response format');
    }

    final List<TideDay> days = [];
    for (final item in decoded) {
      // 날짜/물때/일월출몰
      final pThisDate = (item['pThisDate'] ?? '').toString();
      final pMul      = (item['pMul'] ?? '').toString();
      final pSun      = (item['pSun'] ?? '').toString();
      final pMoon     = (item['pMoon'] ?? '').toString();

      // 지역명/ID 폴백
      String regionName = (item['pName'] ?? '').toString().trim();
      String area       = (item['pArea'] ?? '').toString().trim();
      if (regionName.isEmpty) {
        final sel = (item['pSelArea'] ?? '').toString();
        regionName = sel.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      }

      // 간만조 시각: jowi1~4 우선, 없으면 pTime1~4
      String pick(String a, String b) {
        final va = (item[a] ?? '').toString();
        return va.trim().isNotEmpty ? va : (item[b] ?? '').toString();
      }
      final j1 = pick('jowi1', 'pTime1');
      final j2 = pick('jowi2', 'pTime2');
      final j3 = pick('jowi3', 'pTime3');
      final j4 = pick('jowi4', 'pTime4');

      final parsed = [
        TideEvent.parse(j1, label: '간조 1/만조 1'),
        TideEvent.parse(j2, label: '간조 2/만조 2'),
        TideEvent.parse(j3, label: '간조 3/만조 3'),
        TideEvent.parse(j4, label: '간조 4/만조 4'),
      ];

      int hi = 0, lo = 0;
      final events = <TideEvent>[];
      for (final e in parsed) {
        if (e == null) continue;
        if (e.type == '만조') {
          hi++;
          events.add(TideEvent(label: '만조 $hi', hhmm: e.hhmm, heightCm: e.heightCm, type: e.type, delta: e.delta));
        } else {
          lo++;
          events.add(TideEvent(label: '간조 $lo', hhmm: e.hhmm, heightCm: e.heightCm, type: e.type, delta: e.delta));
        }
      }

      days.add(TideDay(
        dateRaw: pThisDate,
        regionName: regionName,
        areaId: area,
        mul: pMul,
        sun: pSun,
        moon: pMoon,
        events: events,
      ));
    }

    days.sort((a, b) => a.date.compareTo(b.date));
    return days;
  }

  /// Env 기반 팩토리 (키/베이스URL 자동 주입)
  static Future<BadaTimeApi> fromEnv({
    double? lat,
    double? lon,
    String? areaId,
  }) async {
    await Env.ensureLoaded();
    return BadaTimeApi(
      baseUrl: Env.API_BASE_URL.trim().replaceAll(RegExp(r'/*$'), ''),
      serviceKey: Env.BADA_SERVICE_KEY,
      lat: lat,
      lon: lon,
      areaId: areaId,
    );
  }
}
