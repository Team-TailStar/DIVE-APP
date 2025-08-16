import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// 공공데이터포털 디코딩(serviceKey) 사용 권장
const String _serviceKey = String.fromEnvironment('AIRKOREA_SERVICE_KEY', defaultValue: '');
const bool _useMock = false; // ← 임시로 가짜 데이터 쓰고 싶으면 true

class AirKoreaApi {
  static const _host = 'apis.data.go.kr';
  static const _path = '/B552584/ArpltnInforInqireSvc/getMinuDustFrcstDspth';

  /// searchDate: 통보서 발송일(YYYY-MM-DD). null이면 오늘.
  /// informCode: PM10 | PM25 | O3
  static Future<List<DustForecast>> fetch({
    DateTime? searchDate,
    String informCode = 'PM10',
    int numOfRows = 10,
    int pageNo = 1,
  }) async {
    if (_useMock) return _mock();

    final dateStr = DateFormat('yyyy-MM-dd').format(searchDate ?? DateTime.now());
    final query = {
      'serviceKey': _serviceKey,
      'returnType': 'json',
      'numOfRows': '$numOfRows',
      'pageNo': '$pageNo',
      'searchDate': dateStr,
      'informCode': informCode,
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
    return items.map((e) => DustForecast.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// 결과가 비어오면 하루 전/이틀 전도 재시도하고 싶을 때
  static Future<List<DustForecast>> fetchWithFallback({
    String informCode = 'PM10',
  }) async {
    for (int d = 0; d <= 2; d++) {
      final date = DateTime.now().subtract(Duration(days: d));
      final items = await fetch(searchDate: date, informCode: informCode);
      if (items.isNotEmpty) return items;
    }
    return [];
  }

  static List<DustForecast> _mock() {
    return [
      DustForecast(
        dataTime: '2025-08-16 11시 발표',
        informCode: 'PM10',
        informOverall: '중서부 중심 국외 미세먼지 유입과 대기정체로 농도 높음.',
        informCause: '국외 영향 + 대기 정체',
        informGradeByRegion: {
          '서울': '나쁨',
          '인천': '나쁨',
          '경기남부': '보통',
          '경기북부': '나쁨',
          '부산': '보통',
        },
        actionKnack: '기침/호흡기 질환자는 외출 시 마스크 착용 권고',
        imageUrls: const [],
        informData: '2025-08-17',
      ),
    ];
  }
}

class DustForecast {
  final String dataTime;
  final String informCode;
  final String informOverall;
  final String informCause;
  final Map<String, String> informGradeByRegion; // 지역 -> 등급
  final String? actionKnack;
  final List<String> imageUrls; // imageUrl1~9
  final String informData;

  DustForecast({
    required this.dataTime,
    required this.informCode,
    required this.informOverall,
    required this.informCause,
    required this.informGradeByRegion,
    required this.actionKnack,
    required this.imageUrls,
    required this.informData,
  });

  factory DustForecast.fromJson(Map<String, dynamic> j) {
    // "서울 : 나쁨, 경기남부 : 보통, ..." -> Map 파싱
    Map<String, String> parseGrades(String? s) {
      final map = <String, String>{};
      if (s == null || s.trim().isEmpty) return map;
      for (final part in s.split(',')) {
        final kv = part.split(':');
        if (kv.isEmpty) continue;
        final region = kv.first.trim();
        final grade = kv.length >= 2 ? kv.sublist(1).join(':').trim() : '';
        if (region.isNotEmpty) map[region] = grade;
      }
      return map;
    }

    List<String> collectImages(Map<String, dynamic> jj) {
      final acc = <String>[];
      for (int i = 1; i <= 9; i++) {
        final v = jj['imageUrl$i'];
        if (v is String && v.isNotEmpty) acc.add(v);
      }
      return acc;
    }

    return DustForecast(
      dataTime: j['dataTime']?.toString() ?? '',
      informCode: j['informCode']?.toString() ?? '',
      informOverall: j['informOverall']?.toString() ?? '',
      informCause: j['informCause']?.toString() ?? '',
      informGradeByRegion: parseGrades(j['informGrade']?.toString()),
      actionKnack: j['actionKnack']?.toString(),
      imageUrls: collectImages(j),
      informData: j['informData']?.toString() ?? '',
    );
  }
}
