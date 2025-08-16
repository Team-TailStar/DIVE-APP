// lib/pages/weather/weather_weekly_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'weather_models.dart';
import 'sky_icon_mapper.dart';
import 'air_quality_service.dart'; // AirQualitySummary

class WeatherWeeklyList extends StatelessWidget {
  final List<Day7Item> all;
  final AirQualitySummary? air; // ← 주간 카드에 붙일 대기질 요약(옵션)
  const WeatherWeeklyList({super.key, required this.all, this.air});

  @override
  Widget build(BuildContext context) {
    final days = _aggregate(all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6),
          child: Row(
            children: [
              const Text('This Week',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(
                DateFormat('M월 d일 (E)', 'ko_KR').format(DateTime.now()),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...days.map((d) => _DayCard(d: d, air: air)).toList(),
      ],
    );
  }

  // 3시간 간격 데이터를 날짜별로 묶어서 일일 요약 만들기
  List<_DailyAgg> _aggregate(List<Day7Item> src) {
    final map = <String, List<Day7Item>>{};
    for (final it in src) {
      final t = it.time;
      final key = DateFormat('yyyy-MM-dd').format(t);
      (map[key] ??= []).add(it);
    }

    final result = <_DailyAgg>[];
    final keys = map.keys.toList()..sort();
    for (final k in keys.take(7)) {
      final list = map[k]!;
      double minT = double.infinity, maxT = -double.infinity, wind = 0, hum = 0;
      int rainProb = 0;
      final skyCount = <String, int>{};
      String sky = '맑음', skyCode = '1';

      for (final e in list) {
        final t = e.tempC;
        if (t < minT) minT = t;
        if (t > maxT) maxT = t;
        wind += e.windSpd ?? 0;
        hum += e.humidity ?? 0;

        // 가장 큰 강수확률 채택
        final rp = e.rainProb ?? 0;
        if (rp > rainProb) rainProb = rp;

        skyCount[e.sky] = (skyCount[e.sky] ?? 0) + 1;
      }
      final top = skyCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (top.isNotEmpty) sky = top.first.key;
      skyCode = list.first.skyCode;

      final d = DateFormat('yyyy-MM-dd').parse(k);
      result.add(_DailyAgg(
        date: d,
        minT: minT.isFinite ? minT : 0,
        maxT: maxT.isFinite ? maxT : 0,
        sky: sky,
        skyCode: skyCode,
        rainProb: rainProb,
        wind: wind / list.length,
        humidity: (hum / list.length).round(),
      ));
    }
    return result;
  }
}

class _DailyAgg {
  final DateTime date;
  final double minT, maxT;
  final String sky, skyCode;
  final int rainProb, humidity;
  final double wind;
  _DailyAgg({
    required this.date,
    required this.minT,
    required this.maxT,
    required this.sky,
    required this.skyCode,
    required this.rainProb,
    required this.wind,
    required this.humidity,
  });
}

class _DayCard extends StatelessWidget {
  final _DailyAgg d;
  final AirQualitySummary? air;
  const _DayCard({required this.d, this.air});

  Color _gradeColor(String g) {
    if (g.contains('매우')) return const Color(0xFFFF6B6B);
    if (g.contains('나쁨')) return const Color(0xFFFFA94D);
    if (g.contains('보통')) return const Color(0xFF6BCB77);
    if (g.contains('좋음')) return const Color(0xFF4D96FF);
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 상단: 요일/날짜 + 최고/최저
          Row(
            children: [
              Expanded(
                child: Text(
                  '${DateFormat('EEEE', 'en').format(d.date)}\n'
                      '${DateFormat('MMM d', 'en').format(d.date)}',
                  style:
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${d.maxT.round()}°',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${d.minT.round()}°',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 중간: 아이콘 + 상태 + 강수확률 + (우측 대기질 요약뱃지 대신 아래 chips 표시)
          Row(
            children: [
              Icon(skyCodeToIcon(d.skyCode), color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.sky,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('${d.rainProb}% chance of rain',
                        style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              // 우측 “정보없음” 뱃지 (상세 칩은 아래 Wrap에서 노출)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  air == null ? '정보없음' : '대기질',
                  style: const TextStyle(
                      color: Color(0xFF4D96FF),
                      fontWeight: FontWeight.w800,
                      fontSize: 12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 대기질 칩들 (요약 없으면 생략)
          if (air != null) _airChipsRow(air!),

          const SizedBox(height: 8),

          // 하단: 지표들
          Row(
            children: [
              _metric(Icons.air_rounded, 'Wind', '${d.wind.toStringAsFixed(1)}m/s'),
              _metric(Icons.water_drop_outlined, 'Humidity', '${d.humidity}%'),
              _metric(Icons.grain_outlined, 'Rain', '${d.rainProb}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text('$label $value',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // 대기질 칩 Row (미세먼지/초미세먼지)
  // _airChipsRow 교체
  Widget _airChipsRow(AirQualitySummary a) {
    Widget pair(String name, String? grade) {
      final g = grade ?? '정보없음';
      final c = _gradeColor(g);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Text(g,
                style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          pair('미세먼지', a.pm10),
          pair('초미세먼지', a.pm25),
          // pair('오존', a.o3),
          // pair('이산화질소', a.no2),
        ],
      ),
    );
  }
}