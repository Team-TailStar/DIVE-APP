import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'weather_models.dart';
import 'weather_tabs.dart';
import 'sky_icon_mapper.dart';

class WeatherHourlyList extends StatelessWidget {
  final List<Day7Item> all;
  final WeatherTab tab;
  const WeatherHourlyList({super.key, required this.all, required this.tab});

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) return _emptyBox('예보 정보가 없습니다.');

    final dfHour = DateFormat('HH:mm');
    final dfDay = DateFormat('M월 d일 (E)', 'ko_KR');
    final items = _filterByTab(all, tab);
    if (items.isEmpty) return _emptyBox('예보 정보가 없습니다.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Today', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(dfDay.format(items.first.time), style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.28),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final it = items[i];
                final highlight = i == 2;
                return _hourCard(
                  time: dfHour.format(it.time),
                  temp: '${it.tempC.round()}°C',
                  icon: skyCodeToIcon(it.skyCode),
                  highlight: highlight,
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _hourCard({required String time, required String temp, required IconData icon, bool highlight = false}) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(highlight ? 0.9 : 0.75),
        borderRadius: BorderRadius.circular(14),
        boxShadow: highlight
            ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(temp, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black.withOpacity(0.85))),
          Icon(icon, size: 22, color: Colors.black87),
          Text(time, style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.6))),
        ],
      ),
    );
  }

  List<Day7Item> _filterByTab(List<Day7Item> all, WeatherTab tab) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (tab) {
      case WeatherTab.today:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case WeatherTab.tomorrow:
        start = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        end = start.add(const Duration(days: 1));
        break;
      case WeatherTab.week:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 7));
        break;
    }

    final list = all.where((e) => e.time.isAfter(start.subtract(const Duration(seconds: 1))) && e.time.isBefore(end)).toList();
    if (tab == WeatherTab.week) {
      final sampled = <Day7Item>[];
      for (int i = 0; i < list.length; i += 2) {
        sampled.add(list[i]);
      }
      return sampled;
    }
    return list;
  }

  Widget _emptyBox(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(msg, style: const TextStyle(color: Colors.white)),
    );
  }
}
