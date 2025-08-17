// lib/pages/weather/air_quality_service.dart
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'airkorea_api.dart';
import 'weather_models.dart';

class AirQualitySummary {
  final String pm10;  // 미세먼지
  final String pm25;  // 초미세먼지
  final String o3;    // 오존
  final String? no2;  // 선택
  final String message;

  // 추가: 메타정보
  final DateTime? announcedAt; // dataTime 파싱값(발표 시각)
  final DateTime? appliesOn;   // informData 파싱값(적용 날짜, 00시)
  final String regionLabel;    // '서울', '경기남부' 등 UI 표시용

  AirQualitySummary({
    required this.pm10,
    required this.pm25,
    required this.o3,
    this.no2,
    required this.message,
    this.announcedAt,
    this.appliesOn,
    required this.regionLabel,
  });
}

class AirQualityService {
  // ====== 공개 API ======
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

  // ====== 내부 구현 ======

  // 지금 시간 기준 최신 발표분만 사용
  static Future<AirQualitySummary> _fetchSummaryForRegion(String regionKey) async {
    final pm10F = await AirKoreaApi.fetchLatestForNow(informCode: 'PM10');
    final pm25F = await AirKoreaApi.fetchLatestForNow(informCode: 'PM25');
    final o3F   = await AirKoreaApi.fetchLatestForNow(informCode: 'O3');

    // 등급 선택 로직 (해당 지역 → 없으면 아무 지역 첫 값 → 정보없음)
    String _pick(DustForecast? f) {
      if (f == null) return '정보없음';
      final g = f.informGradeByRegion[regionKey];
      if (g != null && g.isNotEmpty) return g;
      if (f.informGradeByRegion.isNotEmpty) return f.informGradeByRegion.values.first;
      return '정보없음';
    }

    final pm10 = _pick(pm10F);
    final pm25 = _pick(pm25F);
    final o3   = _pick(o3F);

    // 메타: 발표/적용(가능하면 PM10 기준, 없으면 PM25→O3 순)
    final base = pm10F ?? pm25F ?? o3F;
    final announcedAt = _parseDataTime(base?.dataTime);      // "YYYY-MM-DD HH시 발표"
    final appliesOn   = _parseInformDate(base?.informData);  // "YYYY-MM-DD"

    final msg  = _summaryMessage([pm10, pm25, o3]);

    return AirQualitySummary(
      pm10: pm10,
      pm25: pm25,
      o3: o3,
      message: msg,
      announcedAt: announcedAt,
      appliesOn: appliesOn,
      regionLabel: regionKey,
    );
  }

  // "2025-08-16 11시 발표" → DateTime(2025,8,16,11)
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

  // "2025-08-17" → DateTime(2025,8,17)
  static DateTime? _parseInformDate(String? s) {
    if (s == null) return null;
    try {
      final parts = s.split('-');
      if (parts.length != 3) return null;
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch (_) {
      return null;
    }
  }

  // ----- 위치 → regionKey 이하 동일 -----
  static Future<String?> _regionKeyFromCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      return _regionKeyFromLatLon(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _regionKeyFromLatLon(double lat, double lon) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, lon, localeIdentifier: 'ko_KR');
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final admin = (p.administrativeArea ?? '').replaceAll(' ', '');
      final sub   = (p.subAdministrativeArea ?? '').replaceAll(' ', '');

      final byAdm = _guessRegionKey(admin);
      if (byAdm != null) {
        if (byAdm.startsWith('경기')) return (lat >= 37.5) ? '경기북부' : '경기남부';
        if (byAdm.startsWith('강원')) return (lon >= 128.3) ? '강원영동' : '강원영서';
        return byAdm;
      }
      final regionFromSub = _guessRegionKey(sub);
      if (regionFromSub != null) return regionFromSub;
      if (admin.contains('강원')) return (lon >= 128.3) ? '강원영동' : '강원영서';
      return null;
    } catch (_) {
      return null;
    }
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
    if (s.contains('경기')) return '경기남부';
    if (s.contains('강원')) return '강원영서';
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
      final rank = _gradeRank(g);
      if (rank > worst) worst = rank;
    }
    switch (worst) {
      case 0: return '오늘은 외출하기 좋은 날씨입니다!';
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
