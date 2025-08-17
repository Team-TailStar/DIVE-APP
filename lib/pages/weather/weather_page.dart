// lib/pages/weather/weather_page.dart
import 'package:flutter/material.dart';
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
  late Future<NowResponse> _nowF;
  late Future<List<Day7Item>> _day7F;

  // 공기질은 한 번만 받아서 공유
  late Future<AirQualitySummary> _airF;

  WeatherTab _tab = WeatherTab.today;

  @override
  void initState() {
    super.initState();
    _nowF = WeatherApi.fetchNow(widget.lat, widget.lon);
    _day7F = WeatherApi.fetchDay7(widget.lat, widget.lon);

    // now.city를 폴백으로 사용해 공기질 요청. (위치 권한 지연 방지)
    _airF = _nowF.then(
          (now) => AirQualityService.fetchSummaryByLocation(cityFallback: now.city),
    );
  }

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
                            _location(now.city ?? '위치 정보 없음'),
                            const SizedBox(height: 6),

                            // 온도 + 하단 미세먼지 한 줄 (같은 _airF 사용)
                            FutureBuilder<AirQualitySummary>(
                              future: _airF,
                              builder: (context, aq) {
                                return _bigTemp(
                                  current.tempC,
                                  current.sky,
                                  current.skyCode,
                                  aq.data, // 있으면 '미세먼지 · 초미세먼지' 한 줄 표시
                                );
                              },
                            ),

                            const SizedBox(height: 12),
                            WeatherMetricsCard(current: current),

                            if (_tab == WeatherTab.today) ...[
                              const SizedBox(height: 14),
                              // 대기질 정보 카드 (같은 _airF 재사용)
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
                                        regionLabel: now.city ?? '서울',
                                        announcedAt: null,
                                        appliesOn: null,
                                        no2: null,
                                      );

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: AirQualityCard(data: data),
                                  );
                                },
                              ),
                            ],

                            const SizedBox(height: 14),

                            // 예보(오늘=시간대 리스트 / 이번 주=주간 리스트+대기질 배지)
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

                                // 주간 리스트에서도 동일 _airF 사용
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

  Widget _location(String city) {
    return Row(
      children: [
        const Icon(Icons.location_on, color: Colors.redAccent, size: 18),
        const SizedBox(width: 4),
        Text(city, style: const TextStyle(color: Colors.red, fontSize: 13)),
      ],
    );
  }

  // 공기질 한 줄 표시를 위해 AirQualitySummary? 추가
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
            Text(sky, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Icon(skyCodeToIcon(skyCode), size: 28, color: Colors.white),
          ],
        ),
        if (air != null) ...[
          const SizedBox(height: 6),
          Text(
            '미세먼지 ${air.pm10} · 초미세먼지 ${air.pm25}',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

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
