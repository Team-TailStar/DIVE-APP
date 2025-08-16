import 'airkorea_api.dart'; // 앞서 만든 AirKoreaApi 사용

class AirQualitySummary {
  final String pm10;  // 미세먼지
  final String pm25;  // 초미세먼지
  final String o3;    // 오존
  final String? no2;  // (선택) 이산화질소 - 이 API엔 없음, 다른 실시간API로 합성 가능
  final String message; // 안내 문구

  AirQualitySummary({
    required this.pm10,
    required this.pm25,
    required this.o3,
    this.no2,
    required this.message,
  });
}

class AirQualityService {
  /// Weather Now 응답의 city(예: "서울특별시 중구")에서 지역 키 추정
  static String _guessRegionKey(String? city) {
    final s = (city ?? '').replaceAll(' ', '');
    if (s.contains('서울')) return '서울';
    if (s.contains('인천')) return '인천';
    if (s.contains('부산')) return '부산';
    if (s.contains('대구')) return '대구';
    if (s.contains('광주')) return '광주';
    if (s.contains('대전')) return '대전';
    if (s.contains('울산')) return '울산';
    if (s.contains('세종')) return '세종';
    if (s.contains('제주')) return '제주';
    if (s.contains('경기')) return '경기남부'; // 북/남 구분 정보 없으니 기본 남부
    if (s.contains('강원')) return '강원영서'; // 간이 매핑
    if (s.contains('충북')) return '충북';
    if (s.contains('충남')) return '충남';
    if (s.contains('전북')) return '전북';
    if (s.contains('전남')) return '전남';
    if (s.contains('경북')) return '경북';
    if (s.contains('경남')) return '경남';
    return '서울';
  }

  static String _pickGrade(List<DustForecast> list, String regionKey) {
    for (final f in list) {
      final g = f.informGradeByRegion[regionKey];
      if (g != null && g.isNotEmpty) return g;
    }
    if (list.isNotEmpty && list.first.informGradeByRegion.isNotEmpty) {
      return list.first.informGradeByRegion.values.first;
    }
    return '정보없음';
  }

  static String _summaryMessage(List<String> grades) {
    // 최악 등급 기준으로 간단 메시지
    int worst = 0;
    for (final g in grades) {
      final rank = _gradeRank(g);
      if (rank > worst) worst = rank;
    }
    switch (worst) {
      case 0: // 좋음
        return '오늘은 외출하기 좋은 날씨입니다!';
      case 1: // 보통
        return '야외활동 무난하지만 민감군은 주의하세요.';
      case 2: // 나쁨
        return '마스크 착용하고 외출을 줄여주세요.';
      default: // 매우나쁨
        return '가능하면 실내에 머무르고 환기를 최소화하세요.';
    }
  }

  static int _gradeRank(String grade) {
    if (grade.contains('매우')) return 3;
    if (grade.contains('나쁨')) return 2;
    if (grade.contains('보통')) return 1;
    if (grade.contains('좋음')) return 0;
    return 1; // 모름 → 보통 취급
  }

  /// 핵심: 한 번에 PM10/PM25/O3 예보를 가져와 해당 지역 등급만 뽑아 카드 요약으로 만들어줌
  static Future<AirQualitySummary> fetchSummary({String? city}) async {
    final region = _guessRegionKey(city);

    final pm10L = await AirKoreaApi.fetchWithFallback(informCode: 'PM10');
    final pm25L = await AirKoreaApi.fetchWithFallback(informCode: 'PM25');
    final o3L   = await AirKoreaApi.fetchWithFallback(informCode: 'O3');

    final pm10 = _pickGrade(pm10L, region);
    final pm25 = _pickGrade(pm25L, region);
    final o3   = _pickGrade(o3L, region);

    final msg  = _summaryMessage([pm10, pm25, o3]);
    return AirQualitySummary(pm10: pm10, pm25: pm25, o3: o3, message: msg);
  }
}
