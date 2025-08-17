import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../env.dart';

class AirKoreaApi {
  static const _host = 'apis.data.go.kr';
  static const _path = '/B552584/ArpltnInforInqireSvc/getMinuDustFrcstDspth';

  static Future<List<DustForecast>> fetch({
    DateTime? searchDate,
    String informCode = 'PM10',
    int numOfRows = 10,
    int pageNo = 1,
  }) async {
    // await Env.ensureLoaded();
    final serviceKey = Env.AIRKOREA_SERVICE_KEY;
    if (serviceKey.isEmpty) {
      throw Exception('AIRKOREA_SERVICE_KEY 비어 있음 (env.json 확인)');
    }

    // 지금 날짜(로컬) 기준으로 호출
    final dateStr = DateFormat('yyyy-MM-dd').format(searchDate ?? DateTime.now());
    final query = {
      'serviceKey': serviceKey,
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

  /// 결과가 비어오면 하루 전/이틀 전까지 재시도
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

  /// 지금 시간 기준으로 가장 최근(미래 발표분 제외) 예보 한 건 선택
  static Future<DustForecast?> fetchLatestForNow({
    String informCode = 'PM10',
  }) async {
    final now = DateTime.now();
    final items = await fetchWithFallback(informCode: informCode);
    if (items.isEmpty) return null;

    // dataTime 파싱해서 now 이전/동일인 것만 필터
    final parsed = <({DustForecast item, DateTime when})>[];
    for (final it in items) {
      final dt = _parseDataTime(it.dataTime);
      if (dt != null) {
        parsed.add((item: it, when: dt));
      }
    }
    if (parsed.isEmpty) {
      // 파싱 실패 시 그냥 최신 정렬 반환
      return items.first;
    }

    // now 이전/동일 발표 중 최댓값 우선
    final pastOrNow = parsed.where((e) => !e.when.isAfter(now)).toList();
    if (pastOrNow.isNotEmpty) {
      pastOrNow.sort((a, b) => b.when.compareTo(a.when));
      return pastOrNow.first.item;
    }

    // 전부 미래면(드물지만) 가장 가까운 미래 발표로 대체
    parsed.sort((a, b) => a.when.compareTo(b.when));
    return parsed.first.item;
  }

  /// "2025-08-16 11시 발표" → DateTime(2025,8,16,11)
  static DateTime? _parseDataTime(String? s) {
    if (s == null) return null;
    final re = RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{1,2})');
    final m = re.firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final h = int.parse(m.group(4)!);
    return DateTime(y, mo, d, h);
  }

}

class DustForecast {
  final String dataTime;                 // "YYYY-MM-DD HH시 발표"
  final String informCode;               // "PM10" | "PM25" | "O3"
  final String informOverall;            // 총괄
  final String informCause;              // 원인
  final Map<String, String> informGradeByRegion; // 지역별 등급
  final String? actionKnack;             // 행동 요령
  final List<String> imageUrls;          // imageUrl1~9
  final String informData;               // 적용일(YYYY-MM-DD)

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
