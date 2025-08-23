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
  static const _seoulLat = 37.5665;
  static const _seoulLon = 126.9780;

  late double _lat;
  late double _lon;

  late Future<NowResponse> _nowF;
  late Future<List<Day7Item>> _day7F;
  late Future<String> _cityF;
  late Future<AirQualitySummary> _airF;

  WeatherTab _tab = WeatherTab.today;

  @override
  void initState() {
    super.initState();
    _lat = widget.lat;
    _lon = widget.lon;
    _bootstrap();
    _fixLocationIfNeeded();
  }

  // 모든 비동기 요청을 병렬로 시작
  void _bootstrap() {
    _nowF = WeatherApi.fetchNow(_lat, _lon);
    _day7F = WeatherApi.fetchDay7(_lat, _lon);
    _cityF = _resolveCityFast(_lat, _lon);
    _airF = _cityF.then(
          (city) => AirQualityService.fetchSummaryByLocation(cityFallback: city),
    );
  }

  bool _isOutOfKorea(double lat, double lon) {
    return !(lat >= 33 && lat <= 39 && lon >= 124 && lon <= 132);
  }

  Future<void> _fixLocationIfNeeded() async {
    try {
      if (!_isOutOfKorea(_lat, _lon)) return;

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (_isOutOfKorea(pos.latitude, pos.longitude)) {
        _useSeoulFallbackIfNeeded();
        return;
      }

      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _bootstrap();
      });
    } catch (_) {
      _useSeoulFallbackIfNeeded();
    }
  }

  void _useSeoulFallbackIfNeeded() {
    if (_lat == _seoulLat && _lon == _seoulLon) return;
    setState(() {
      _lat = _seoulLat;
      _lon = _seoulLon;
      _bootstrap();
    });
  }

  // 빠른 도시 해석: 역지오코딩만 시도, 실패 시 '서울'
  Future<String> _resolveCityFast(double lat, double lon) async {
    try {
      final ps = await geo.placemarkFromCoordinates(
        lat,
        lon,
        localeIdentifier: 'ko_KR',
      );
      if (ps.isNotEmpty) {
        final adminRaw = (ps.first.administrativeArea ?? '').trim();
        if (adminRaw.isNotEmpty) return _shortenAdm(adminRaw);
      }
    } catch (_) {}
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

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 위치(도시)
                        FutureBuilder<String>(
                          future: _cityF,
                          builder: (c, cs) => _location(cs.data ?? '...'),
                        ),
                        const SizedBox(height: 6),

                        // 현재 온도/하늘
                        FutureBuilder<NowResponse>(
                          future: _nowF,
                          builder: (context, nowSnap) {
                            final ready = nowSnap.connectionState == ConnectionState.done &&
                                nowSnap.hasData &&
                                nowSnap.data!.items.isNotEmpty;
                            if (!ready) return _bigTempSkeleton();
                            final current = nowSnap.data!.items.first;
                            return _bigTemp(current.tempC, current.sky, current.skyCode, null);
                          },
                        ),

                        const SizedBox(height: 12),

                        // 메트릭 카드
                        FutureBuilder<NowResponse>(
                          future: _nowF,
                          builder: (context, snap) {
                            if (snap.connectionState != ConnectionState.done ||
                                !snap.hasData ||
                                snap.data!.items.isEmpty) {
                              return _metricsSkeleton();
                            }
                            return WeatherMetricsCard(current: snap.data!.items.first);
                          },
                        ),

                        const SizedBox(height: 14),

                        // 시/주간 예보
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
                              // (Today/날짜 타이틀은 WeatherHourlyList 내부에서 관리)
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

                        const SizedBox(height: 14),

                        // ✅ 대기질 카드: 화면의 맨 아래로 이동
                        FutureBuilder<AirQualitySummary>(
                          future: _airF,
                          builder: (context, aq) {
                            if (aq.connectionState != ConnectionState.done) {
                              return _cardSkeleton(height: 160);
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

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _location(String city) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
        const SizedBox(width: 4),
        Text(
          city,
          style: const TextStyle(
            color: Colors.red,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _bigTemp(double tempC, String sky, String skyCode, AirQualitySummary? air) {
    final t = tempC.round();
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
            Text(
              sky,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(skyCodeToIcon(skyCode), size: 28, color: Colors.white),
          ],
        ),
      ],
    );
  }

  // 로딩 스켈레톤들
  Widget _bigTempSkeleton() {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 160,
          height: 92,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.white),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _metricsSkeleton() => _cardSkeleton(height: 110);

  Widget _cardSkeleton({double height = 110}) => Container(
    height: height,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.28),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
  );

  Widget _emptyBox(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.28),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(msg, style: const TextStyle(color: Colors.white)),
  );

  Widget _skeleton() => Container(
    height: 110,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.28),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
  );
}
