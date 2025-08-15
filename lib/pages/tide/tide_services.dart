import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tide_models.dart';

class BadaTimeApi {
  static const String _base = 'https://www.badatime.com/DIVE/tide.jsp';

  final String serviceKey; // --dart-define 로 주입 권장
  final double? lat;
  final double? lon;
  final String? areaId;

  BadaTimeApi({
    required this.serviceKey,
    this.lat,
    this.lon,
    this.areaId,
  });

  Future<List<TideDay>> fetch7Days() async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'ServiceKey': serviceKey,
      if (areaId != null) 'area': areaId!,
      if (lat != null) 'lat': lat!.toStringAsFixed(6),
      if (lon != null) 'lon': lon!.toStringAsFixed(6),
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Badatime API error: ${res.statusCode}');
    }

    // API 예시가 배열 형태라고 가정
    final decoded = json.decode(res.body);
    if (decoded is! List) {
      throw Exception('Unexpected response format');
    }

    final List<TideDay> days = [];
    for (final item in decoded) {
      final pThisDate = (item['pThisDate'] ?? '').toString();
      final pName     = (item['pName'] ?? '').toString();
      final pArea     = (item['pArea'] ?? '').toString();
      final pMul      = (item['pMul'] ?? '').toString();
      final pSun      = (item['pSun'] ?? '').toString();
      final pMoon     = (item['pMoon'] ?? '').toString();

      final evs = <TideEvent>[];
      final e1 = TideEvent.parse((item['jowi1'] ?? '').toString(), label: '간조 1/만조 1');
      final e2 = TideEvent.parse((item['jowi2'] ?? '').toString(), label: '간조 2/만조 2');
      final e3 = TideEvent.parse((item['jowi3'] ?? '').toString(), label: '간조 3/만조 3');
      final e4 = TideEvent.parse((item['jowi4'] ?? '').toString(), label: '간조 4/만조 4');

      // 라벨을 만조/간조 + 번호 형태로 깔끔히 재라벨링
      final List<TideEvent?> rawList = [e1, e2, e3, e4];
      int h=0, l=0; // 만조/간조 카운트
      for (final e in rawList) {
        if (e == null) continue;
        if (e.type == '만조') {
          h += 1;
          evs.add(TideEvent(
            label: '만조 $h',
            hhmm: e.hhmm,
            heightCm: e.heightCm,
            type: e.type,
            delta: e.delta,
          ));
        } else {
          l += 1;
          evs.add(TideEvent(
            label: '간조 $l',
            hhmm: e.hhmm,
            heightCm: e.heightCm,
            type: e.type,
            delta: e.delta,
          ));
        }
      }

      days.add(TideDay(
        dateRaw: pThisDate,
        regionName: pName,
        areaId: pArea,
        mul: pMul,
        sun: pSun,
        moon: pMoon,
        events: evs,
      ));
    }

    // 날짜순 소팅(보통 API가 이미 정렬되어오겠지만 안전장치)
    days.sort((a,b)=> a.date.compareTo(b.date));
    return days;
  }
}
