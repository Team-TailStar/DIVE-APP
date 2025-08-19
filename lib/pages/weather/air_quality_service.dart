// lib/pages/weather/air_quality_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import '../../env.dart';

class AirQualitySummary {
  final String pm10;      // 등급 라벨
  final String pm25;
  final String o3;
  final String? no2;
  final String message;

  // 농도(정상일 때만 채움)
  final String? pm10Value; // ㎍/㎥
  final String? pm25Value; // ㎍/㎥
  final String? o3Value;   // ppm
  final String? no2Value;  // ppm

  // 메타
  final DateTime? announcedAt; // dataTime 파싱
  final DateTime? appliesOn;   // 실시간: null
  final String regionLabel;    // '서울' 등
  final String? stationName;   // 선택된 측정소

  AirQualitySummary({
    required this.pm10,
    required this.pm25,
    required this.o3,
    this.no2,
    required this.message,
    this.pm10Value,
    this.pm25Value,
    this.o3Value,
    this.no2Value,
    this.announcedAt,
    this.appliesOn,
    required this.regionLabel,
    this.stationName,
  });
}

/// 실시간(시/도) 측정 값 호출 → 베스트 측정소 하나를 뽑아 요약
class AirQualityService {
  // ===== 공개 API =====
  static Future<AirQualitySummary> fetchSummaryByLocation({String? cityFallback}) async {
    final region = await _regionKeyFromCurrentLocation()
        ?? _guessRegionKey(cityFallback)
        ?? '서울';
    return _fetchSummaryForRegion(region);
  }

  static Future<AirQualitySummary> fetchSummary({String? city}) async {
    final region = _guessRegionKey(city) ?? '서울';
    return _fetchSummaryForRegion(region);
  }

  // ===== 구현 =====

  static Future<AirQualitySummary> _fetchSummaryForRegion(String regionKey) async {
    final stations = await _fetchStations(regionKey);
    if (stations.isEmpty) {
      return AirQualitySummary(
        pm10: '정보없음', pm25: '정보없음', o3: '정보없음', no2: null,
        message: '대기질 정보를 불러오지 못했습니다.',
        announcedAt: null, appliesOn: null,
        regionLabel: regionKey, stationName: null,
      );
    }

    final picked = _pickBestStation(stations);

    String _labelFromGrade(String? code) {
      switch ((code ?? '').trim()) {
        case '1': return '좋음';
        case '2': return '보통';
        case '3': return '나쁨';
        case '4': return '매우나쁨';
        default:  return '정보없음';
      }
    }

    bool _isOkFlag(String? f) {
      final t = (f ?? '').trim();
      if (t.isEmpty) return true;                   // 빈 값은 정상 취급(실무에서 자주 비움)
      if (t == '1') return true;
      if (t == '0') return false;
      if (t == '-' || t.contains('통신장애')) return false;
      return true;
    }

    ({String label, String? value}) _compute({
      required String? flag,
      required String? grade,
      String? grade1h,
      String? value,
      required bool isDust,
    }) {
      if (!_isOkFlag(flag)) return (label: '정보없음', value: null);
      final g = isDust ? (grade ?? grade1h) : grade;
      return (label: _labelFromGrade(g), value: _cleanVal(value));
    }

    final pm10C = _compute(
      flag: picked.pm10Flag, grade: picked.pm10Grade, grade1h: picked.pm10Grade1h,
      value: picked.pm10Value, isDust: true,
    );
    final pm25C = _compute(
      flag: picked.pm25Flag, grade: picked.pm25Grade, grade1h: picked.pm25Grade1h,
      value: picked.pm25Value, isDust: true,
    );
    final o3C = _compute(
      flag: picked.o3Flag, grade: picked.o3Grade, grade1h: null,
      value: picked.o3Value, isDust: false,
    );
    final no2C = _compute(
      flag: picked.no2Flag, grade: picked.no2Grade, grade1h: null,
      value: picked.no2Value, isDust: false,
    );

    final announcedAt = _parseDataTime(picked.dataTime);
    final msg = _summaryMessage([pm10C.label, pm25C.label, o3C.label]);

    return AirQualitySummary(
      pm10: pm10C.label, pm25: pm25C.label, o3: o3C.label,
      no2: (no2C.label == '정보없음') ? null : no2C.label,
      message: msg,
      pm10Value: pm10C.value, pm25Value: pm25C.value, o3Value: o3C.value, no2Value: no2C.value,
      announcedAt: announcedAt, appliesOn: null,
      regionLabel: regionKey, stationName: picked.stationName,
    );
  }

  // ---- HTTP 호출(서비스 내부에 내장) ----
  static Future<List<_Station>> _fetchStations(String sidoName) async {
    await Env.load();
    if (Env.AIRKOREA_SERVICE_KEY.isEmpty) return [];

    final uri = Uri.https(
      'apis.data.go.kr',
      '/B552584/ArpltnInforInqireSvc/getCtprvnRltmMesureDnsty',
      {
        'serviceKey': Env.AIRKOREA_SERVICE_KEY,
        'returnType': 'json',
        'sidoName': sidoName,
        'numOfRows': '100',
        'pageNo': '1',
        'ver': '1.0',
      },
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return [];
      final Map<String, dynamic> j = json.decode(res.body);
      final List items = j['response']?['body']?['items'] ?? [];
      return items.map((e) => _Station.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ---- 스코어로 최적 측정소 선택 ----
  static _Station _pickBestStation(List<_Station> list) {
    bool ok(String? v) => v != null && v.trim().isNotEmpty && v.trim() != '-';
    bool f1(String? f) => _isOkFlag(f);

    int score(_Station a) {
      int s = 0;
      if (f1(a.pm10Flag)) s += 6;
      if (f1(a.pm25Flag)) s += 6;
      if (f1(a.o3Flag))   s += 3;
      if (f1(a.no2Flag))  s += 3;

      if (ok(a.pm10Grade) || ok(a.pm10Grade1h)) s += 3;
      if (ok(a.pm25Grade) || ok(a.pm25Grade1h)) s += 3;
      if (ok(a.o3Grade)) s += 2;
      if (ok(a.no2Grade)) s += 2;

      if (ok(a.pm10Value)) s += 2;
      if (ok(a.pm25Value)) s += 2;
      if (ok(a.o3Value))   s += 1;
      if (ok(a.no2Value))  s += 1;

      return s;
    }

    list.sort((b, a) => score(a).compareTo(score(b)));
    return list.first;
  }

  // ---- helpers ----
  static bool _isOkFlag(String? f) {
    final t = (f ?? '').trim();
    if (t.isEmpty) return true;
    if (t == '1') return true;
    if (t == '0') return false;
    if (t == '-' || t.contains('통신장애')) return false;
    return true;
  }

  static DateTime? _parseDataTime(String? s) {
    if (s == null) return null;
    final m = RegExp(r'^\s*(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})').firstMatch(s);
    if (m == null) return null;
    try {
      return DateTime(
        int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!),
        int.parse(m.group(4)!), int.parse(m.group(5)!),
      );
    } catch (_) { return null; }
  }

  static String? _cleanVal(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty || t == '-') return null;
    return t;
  }

  // 위치 → 시/도
  static Future<String?> _regionKeyFromCurrentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return _regionKeyFromLatLon(pos.latitude, pos.longitude);
    } catch (_) { return null; }
  }

  static Future<String?> _regionKeyFromLatLon(double lat, double lon) async {
    try {
      final ps = await geo.placemarkFromCoordinates(lat, lon, localeIdentifier: 'ko_KR');
      if (ps.isEmpty) return null;
      final admin = (ps.first.administrativeArea ?? '').replaceAll(' ', '');
      return _guessRegionKey(admin);
    } catch (_) { return null; }
  }

  static String? _guessRegionKey(String? city) {
    if (city == null) return null;
    final s = city.replaceAll(' ', '');
    if (s.isEmpty) return null;
    if (s.contains('서울')) return '서울';
    if (s.contains('인천')) return '인천';
    if (s.contains('부산')) return '부산';
    if (s.contains('대구')) return '대구';
    if (s.contains('광주')) return '광주';
    if (s.contains('대전')) return '대전';
    if (s.contains('울산')) return '울산';
    if (s.contains('세종')) return '세종';
    if (s.contains('제주')) return '제주';
    if (s.contains('경기')) return '경기';
    if (s.contains('강원')) return '강원';
    if (s.contains('충북')) return '충북';
    if (s.contains('충남')) return '충남';
    if (s.contains('전북')) return '전북';
    if (s.contains('전남')) return '전남';
    if (s.contains('경북')) return '경북';
    if (s.contains('경남')) return '경남';
    return null;
  }

  static String _summaryMessage(List<String> grades) {
    int worst = 0;
    for (final g in grades) {
      final r = _gradeRank(g);
      if (r > worst) worst = r;
    }
    switch (worst) {
      case 0: return '오늘은 외출하기 좋은 공기입니다.';
      case 1: return '야외활동 무난하지만 민감군은 주의하세요.';
      case 2: return '마스크 착용하고 외출을 줄여주세요.';
      default: return '가능하면 실내에 머무르고 환기를 최소화하세요.';
    }
  }

  static int _gradeRank(String grade) {
    if (grade.contains('매우')) return 3;
    if (grade.contains('나쁨')) return 2;
    if (grade.contains('보통')) return 1;
    if (grade.contains('좋음')) return 0;
    return 1;
  }
}

// --- 내부 모델 ---
class _Station {
  final String? stationName;
  final String? dataTime;

  final String? pm10Value;
  final String? pm25Value;
  final String? o3Value;
  final String? no2Value;

  final String? pm10Grade;
  final String? pm25Grade;
  final String? o3Grade;
  final String? no2Grade;

  final String? pm10Grade1h;
  final String? pm25Grade1h;

  final String? pm10Flag;
  final String? pm25Flag;
  final String? o3Flag;
  final String? no2Flag;

  _Station({
    required this.stationName,
    required this.dataTime,
    required this.pm10Value,
    required this.pm25Value,
    required this.o3Value,
    required this.no2Value,
    required this.pm10Grade,
    required this.pm25Grade,
    required this.o3Grade,
    required this.no2Grade,
    required this.pm10Grade1h,
    required this.pm25Grade1h,
    required this.pm10Flag,
    required this.pm25Flag,
    required this.o3Flag,
    required this.no2Flag,
  });

  factory _Station.fromJson(Map<String, dynamic> j) => _Station(
    stationName  : j['stationName']?.toString(),
    dataTime     : j['dataTime']?.toString(),
    pm10Value    : j['pm10Value']?.toString(),
    pm25Value    : j['pm25Value']?.toString(),
    o3Value      : j['o3Value']?.toString(),
    no2Value     : j['no2Value']?.toString(),
    pm10Grade    : j['pm10Grade']?.toString(),
    pm25Grade    : j['pm25Grade']?.toString(),
    o3Grade      : j['o3Grade']?.toString(),
    no2Grade     : j['no2Grade']?.toString(),
    pm10Grade1h  : j['pm10Grade1h']?.toString(),
    pm25Grade1h  : j['pm25Grade1h']?.toString(),
    pm10Flag     : j['pm10Flag']?.toString(),
    pm25Flag     : j['pm25Flag']?.toString(),
    o3Flag       : j['o3Flag']?.toString(),
    no2Flag      : j['no2Flag']?.toString(),
  );
}
