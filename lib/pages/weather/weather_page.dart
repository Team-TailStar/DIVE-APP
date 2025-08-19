// lib/pages/weather/weather_page.dart
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

import '../../app_bottom_nav.dart';
import 'weather_api.dart';
import 'weather_tabs.dart';
import 'weather_hourly_list.dart';
import 'weather_metrics_card.dart';
import 'weather_models.dart';
import 'air_quality_card.dart';
import 'air_quality_service.dart';
import 'sky_icon_mapper.dart';
import 'weather_weekly_list.dart';

class WeatherPage extends StatefulWidget {
  final double lat;
  final double lon;
  const WeatherPage({super.key, required this.lat, required this.lon});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  // ---- 내부 좌표 상태: 현재 위치 성공 시 교체, 실패면 서울 폴백 ----
  static const _seoulLat = 37.5665;
  static const _seoulLon = 126.9780;

  late double _lat;
  late double _lon;

  late Future<NowResponse> _nowF;
  late Future<List<Day7Item>> _day7F;

  // 시/도 텍스트(대기질 API에도 사용) — 현재 위치 기준, 실패 시 “서울”
  late Future<String> _cityF;

  // 공기질은 한 번만 받아서 공유
  late Future<AirQualitySummary> _airF;

  WeatherTab _tab = WeatherTab.today;

  @override
  void initState() {
    super.initState();

    // 1) 위젯에서 온 좌표로 시작 (에뮬 기본좌표일 수 있음)
    _lat = widget.lat;
    _lon = widget.lon;

    // 2) 일단 부트스트랩 (UI가 빨리 그려지도록)
    _bootstrap();

    // 3) 현재 위치 시도 → 성공하면 좌표/도시 갱신, 실패하면 서울 폴백
    _fixLocationIfNeeded();
  }

  // ----- Futures 세팅 공통 함수 -----
  void _bootstrap() {
    _nowF = WeatherApi.fetchNow(_lat, _lon);
    _day7F = WeatherApi.fetchDay7(_lat, _lon);
    _cityF = _resolveCity(_lat, _lon); // 시/도 텍스트
    _airF = _cityF.then(
          (city) => AirQualityService.fetchSummaryByLocation(cityFallback: city),
    );
  }

  // ----- 현재 위치 교정 -----
  bool _isOutOfKorea(double lat, double lon) {
    // 대략적인 한반도 바운딩박스
    return !(lat >= 33 && lat <= 39 && lon >= 124 && lon <= 132);
  }

  Future<void> _fixLocationIfNeeded() async {
    try {
      // 위젯 좌표가 한국이면 그대로 사용
      if (!_isOutOfKorea(_lat, _lon)) return;

      // 권한/서비스 체크
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        // 서비스 꺼져있으면 바로 서울 폴백
        _useSeoulFallbackIfNeeded();
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _useSeoulFallbackIfNeeded();
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _useSeoulFallbackIfNeeded();
        return;
      }

      // 현재 위치 취득
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 좌표가 한국 밖이면 서울로 폴백
      if (_isOutOfKorea(pos.latitude, pos.longitude)) {
        _useSeoulFallbackIfNeeded();
        return;
      }

      // 정상 좌표로 갱신
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _bootstrap();
      });
    } catch (_) {
      // 오류 시 폴백
      _useSeoulFallbackIfNeeded();
    }
  }

  void _useSeoulFallbackIfNeeded() {
    if (_lat == _seoulLat && _lon == _seoulLon) return; // 이미 서울이면 패스
    setState(() {
      _lat = _seoulLat;
      _lon = _seoulLon;
      _bootstrap();
    });
  }

  // ----- 역지오코딩: 시/도 라벨 (UI + 대기질 API용) -----
  Future<String> _resolveCity(double lat, double lon) async {
    try {
      // 날씨 API가 city를 주는 경우 우선 사용
      final now = await _nowF;
      if ((now.city ?? '').trim().isNotEmpty) {
        return _shortenAdm(now.city!);
      }
    } catch (_) {/* ignore */}

    try {
      final ps = await geo.placemarkFromCoordinates(
        lat,
        lon,
        localeIdentifier: 'ko_KR', // 한글 행정명 강제
      );
      if (ps.isNotEmpty) {
        final adminRaw = (ps.first.administrativeArea ?? '').trim();
        if (adminRaw.isNotEmpty) {
          return _shortenAdm(adminRaw); // 서울특별시 → 서울, 경기도 → 경기
        }
      }
    } catch (_) {/* ignore */}
    return '서울';
  }

  String _shortenAdm(String admin) => admin
      .replaceAll('특별시', '')
      .replaceAll('광역시', '')
      .replaceAll('특별자치시', '')
      .replaceAll('특별자치도', '')
      .replaceAll('자치시', '')
      .replaceAll('자치도', '')
      .replaceAll('도', '')
      .replaceAll(' ', '');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7BB8FF), Color(0xFFA8D3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WeatherTabs(current: _tab, onChanged: (t) => setState(() => _tab = t)),
                const SizedBox(height: 8),

                FutureBuilder<NowResponse>(
                  future: _nowF,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Expanded(child: Center(child: CircularProgressIndicator()));
                    }
                    if (snap.hasError || snap.data == null || snap.data!.items.isEmpty) {
                      return _emptyState('날씨 정보가 없습니다.');
                    }
                    final now = snap.data!;
                    final current = now.items.first;

                    return Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 위치 라벨: 현재 위치 기반(실패 시 서울)
                            FutureBuilder<String>(
                              future: _cityF,
                              builder: (c, cs) => _location(cs.data ?? '서울'),
                            ),
                            const SizedBox(height: 6),

                            // 상단 온도 + 공기질 한 줄
                            FutureBuilder<AirQualitySummary>(
                              future: _airF,
                              builder: (context, aq) {
                                return _bigTemp(
                                  current.tempC, current.sky, current.skyCode, aq.data,
                                );
                              },
                            ),

                            const SizedBox(height: 12),
                            WeatherMetricsCard(current: current),

                            if (_tab == WeatherTab.today) ...[
                              const SizedBox(height: 14),
                              // 대기질 카드
                              FutureBuilder<AirQualitySummary>(
                                future: _airF,
                                builder: (context, aq) {
                                  if (aq.connectionState != ConnectionState.done) {
                                    return Container(
                                      height: 160,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.28),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(color: Colors.white),
                                      ),
                                    );
                                  }

                                  final data = aq.data ??
                                      AirQualitySummary(
                                        pm10: '정보없음',
                                        pm25: '정보없음',
                                        o3: '정보없음',
                                        message: '대기질 정보를 불러오지 못했습니다.',
                                        regionLabel: '서울',
                                        announcedAt: null,
                                        appliesOn: null,
                                        no2: null,
                                        pm10Value: null,
                                        pm25Value: null,
                                        o3Value: null,
                                        no2Value: null,
                                        stationName: null,
                                      );

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: AirQualityCard(data: data),
                                  );
                                },
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 예보 섹션
                            FutureBuilder<List<Day7Item>>(
                              future: _day7F,
                              builder: (context, ds) {
                                if (ds.connectionState != ConnectionState.done) {
                                  return _skeleton();
                                }
                                if (ds.hasError || ds.data == null || ds.data!.isEmpty) {
                                  return _emptyBox('예보 정보가 없습니다.');
                                }
                                final list = ds.data!;

                                if (_tab == WeatherTab.today) {
                                  return WeatherHourlyList(all: list, tab: _tab);
                                }

                                final nowDt = DateTime.now();
                                final today0 = DateTime(nowDt.year, nowDt.month, nowDt.day);
                                final rangeStart = today0.subtract(const Duration(days: 3));

                                return FutureBuilder<AirQualitySummary>(
                                  future: _airF,
                                  builder: (context, aq) {
                                    return WeatherWeeklyList(
                                      all: list,
                                      air: aq.data,
                                      title: 'This Week',
                                      startDate: rangeStart,
                                      highlightDate: today0,
                                    );
                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  // ---- UI bits ----
  Widget _location(String city) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
        const SizedBox(width: 4),
        Text(city, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // 공기질 한 줄(등급+농도)
  String _pmLabel(String? val) => (val == null) ? '-' : '$val㎍/㎥';
  String _gasLabel(String? val) => (val == null) ? '-' : '$val ppm';

  Widget _bigTemp(double tempC, String sky, String skyCode, AirQualitySummary? air) {
    final t = tempC.round();

    String? line1, line2;
    if (air != null) {
      final pm10 = '미세먼지 ${air.pm10}${air.pm10Value != null ? ' (${_pmLabel(air.pm10Value)})' : ''}';
      final pm25 = '초미세먼지 ${air.pm25}${air.pm25Value != null ? ' (${_pmLabel(air.pm25Value)})' : ''}';
      line1 = '$pm10 · $pm25';

      final o3 = '오존 ${air.o3}${air.o3Value != null ? ' (${_gasLabel(air.o3Value)})' : ''}';
      final no2 = (air.no2 == null && air.no2Value == null)
          ? null
          : '이산화질소 ${air.no2 ?? '정보없음'}${air.no2Value != null ? ' (${_gasLabel(air.no2Value)})' : ''}';
      line2 = (no2 == null) ? o3 : '$o3 · $no2';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: Text(
            '$t°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 84,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(sky, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Icon(skyCodeToIcon(skyCode), size: 28, color: Colors.white),
          ],
        ),
        // if (line1 != null) ...[
        //   const SizedBox(height: 6),
        //   Text(
        //     line1!,
        //     textAlign: TextAlign.center,
        //     style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        //   ),
        // ],
        // if (line2 != null) ...[
        //   const SizedBox(height: 2),
        //   Text(
        //     line2!,
        //     textAlign: TextAlign.center,
        //     style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
        //   ),
        // ],
      ],
    );
  }

  String _fmtK(DateTime dt) =>
      '${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _emptyState(String msg) => Expanded(
    child: Center(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 16))),
  );

  Widget _emptyBox(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.28), borderRadius: BorderRadius.circular(16)),
    child: Text(msg, style: const TextStyle(color: Colors.white)),
  );

  Widget _skeleton() => Container(
    height: 110,
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.28), borderRadius: BorderRadius.circular(16)),
    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
  );
}
