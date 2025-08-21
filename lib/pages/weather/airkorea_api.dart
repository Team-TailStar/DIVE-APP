// lib/pages/air/airkorea_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../env.dart';

/// 실시간 시/도별 측정소 대기질 데이터
class AirKoreaApi {
  static const _host = 'apis.data.go.kr';
  // 시도별 실시간 측정 정보
  static const _path = '/B552584/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty';

  static Future<List<AirQuality>> fetchStationData({
    String sidoName = '서울',
    int numOfRows = 100,
    int pageNo = 1,
  }) async {
    final serviceKey = Env.AIRKOREA_SERVICE_KEY;
    if (serviceKey.isEmpty) {
      throw Exception('api key 발급 필요');
    }

    final query = {
      'serviceKey': serviceKey,
      'returnType': 'json',
      'sidoName': sidoName,
      'numOfRows': '$numOfRows',
      'pageNo': '$pageNo',
      'ver': '1.3',
    };

    final uri = Uri.https(_host, _path, query);
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('AirKorea HTTP ${res.statusCode}: ${res.body}');
    }

    final Map<String, dynamic> j = json.decode(res.body);
    final body = j['response']?['body'];
    if (body == null) return [];

    final List items = body['items'] ?? [];
    return items
        .map((e) => AirQuality.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

class AirQuality {
  final String dataTime;

  final String? o3Value;
  final String? no2Value;
  final String? pm10Value;
  final String? pm25Value;

  final String? o3Grade;
  final String? no2Grade;
  final String? pm10Grade;
  final String? pm25Grade;

  final String? pm10Grade1h;
  final String? pm25Grade1h;

  final String? o3Flag;
  final String? no2Flag;
  final String? pm10Flag;
  final String? pm25Flag;

  // 선택: UI 표시에 유용
  final String? stationName;
  final String? sidoName;

  AirQuality({
    required this.dataTime,
    this.o3Value,
    this.no2Value,
    this.pm10Value,
    this.pm25Value,
    this.o3Grade,
    this.no2Grade,
    this.pm10Grade,
    this.pm25Grade,
    this.pm10Grade1h,
    this.pm25Grade1h,
    this.o3Flag,
    this.no2Flag,
    this.pm10Flag,
    this.pm25Flag,
    this.stationName,
    this.sidoName,
  });

  factory AirQuality.fromJson(Map<String, dynamic> j) {
    String? _str(dynamic v) =>
        (v == null || (v is String && v.trim().isEmpty)) ? null : v.toString();

    return AirQuality(
      dataTime: j['dataTime']?.toString() ?? '',
      o3Value: _str(j['o3Value']),
      no2Value: _str(j['no2Value']),
      pm10Value: _str(j['pm10Value']),
      pm25Value: _str(j['pm25Value']),
      o3Grade: _str(j['o3Grade']),
      no2Grade: _str(j['no2Grade']),
      pm10Grade: _str(j['pm10Grade']),
      pm25Grade: _str(j['pm25Grade']),
      pm10Grade1h: _str(j['pm10Grade1h']),
      pm25Grade1h: _str(j['pm25Grade1h']),
      o3Flag: _str(j['o3Flag']),
      no2Flag: _str(j['no2Flag']),
      pm10Flag: _str(j['pm10Flag']),
      pm25Flag: _str(j['pm25Flag']),
      stationName: _str(j['stationName']),
      sidoName: _str(j['sidoName']),
    );
  }
}
