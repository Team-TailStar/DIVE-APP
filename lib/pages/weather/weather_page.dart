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
  WeatherTab _tab = WeatherTab.today;

  @override
  void initState() {
    super.initState();
    _nowF = WeatherApi.fetchNow(widget.lat, widget.lon);
    _day7F = WeatherApi.fetchDay7(widget.lat, widget.lon);
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
                            _bigTemp(current.tempC, current.sky, current.skyCode),
                            const SizedBox(height: 12),
                            WeatherMetricsCard(current: current),
                            const SizedBox(height: 14),

                            FutureBuilder<List<Day7Item>>(
                              future: _day7F,
                              builder: (context, ds) {
                                if (ds.connectionState != ConnectionState.done) {
                                  return _skeleton();
                                }
                                if (ds.hasError || ds.data == null || ds.data!.isEmpty) {
                                  return _emptyBox('예보 정보가 없습니다.');
                                }
                                return WeatherHourlyList(all: ds.data!, tab: _tab);
                              },
                            ),
                            const SizedBox(height: 14),
                            FutureBuilder<AirQualitySummary>(
                              future: AirQualityService.fetchSummary(city: now.city),
                              builder: (context, snap) {
                                if (snap.connectionState != ConnectionState.done) {
                                  return Container(
                                    height: 160,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.28),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                                  );
                                }
                                if (!snap.hasData) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: AirQualityCard(data: snap.data!),
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
        bottomNavigationBar: const AppBottomNav(currentIndex: 0)
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

  Widget _bigTemp(double tempC, String sky, String skyCode) {
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
      ],
    );
  }


  Widget _emptyState(String msg) => Expanded(child: Center(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 16))));
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
