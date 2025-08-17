// lib/pages/weather/air_quality_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'air_quality_service.dart';

class AirQualityCard extends StatelessWidget {
  final AirQualitySummary data;
  const AirQualityCard({super.key, required this.data});

  Color _gradeColor(String grade) {
    if (grade.contains('매우')) return const Color(0xFFFF6B6B);
    if (grade.contains('나쁨')) return const Color(0xFFFFA94D);
    if (grade.contains('보통')) return const Color(0xFF6BCB77);
    if (grade.contains('좋음')) return const Color(0xFF4D96FF);
    return Colors.grey;
  }

  String _metaLine(AirQualitySummary d) {
    final b = StringBuffer();
    b.write(d.regionLabel); // 서울, 경기남부 등
    // 발표시각
    if (d.announcedAt != null) {
      b.write(' · ');
      b.write(DateFormat('M월 d일 H시 발표', 'ko_KR').format(d.announcedAt!));
    }
    // 적용일
    if (d.appliesOn != null) {
      b.write(' · ');
      b.write(DateFormat('M월 d일 적용', 'ko_KR').format(d.appliesOn!));
    }
    return b.toString();
  }

  Widget _tile(String title, String sub, String grade) {
    final gc = _gradeColor(grade);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(sub, style: const TextStyle(color: Colors.black45, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: gc.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              grade,
              style: TextStyle(fontWeight: FontWeight.w800, color: gc),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E9FB)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Text('대기질 정보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const Spacer(),
              Icon(Icons.eco_rounded, size: 18, color: cs.primary),
            ],
          ),
          const SizedBox(height: 4),
          // 메타정보 라인(지역 · 발표 · 적용)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _metaLine(data),
              style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 12),
          GridView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55,
            ),
            children: [
              _tile('미세먼지', 'PM10', data.pm10),
              _tile('초미세먼지', 'PM2.5', data.pm25),
              _tile('오존', 'O\u2083', data.o3),
              _tile('이산화질소', 'NO\u2082', data.no2 ?? '정보없음'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFF5C7CFA)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.message,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
