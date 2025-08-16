import 'package:flutter/material.dart';
import 'air_quality_service.dart';

class AirQualityCard extends StatelessWidget {
  final AirQualitySummary data;
  const AirQualityCard({super.key, required this.data});

  Color _gradeColor(String grade) {
    if (grade.contains('매우')) return const Color(0xFFFF6B6B); // 매우나쁨: 레드
    if (grade.contains('나쁨')) return const Color(0xFFFFA94D); // 나쁨: 오렌지
    if (grade.contains('보통')) return const Color(0xFF6BCB77); // 보통: 그린
    if (grade.contains('좋음')) return const Color(0xFF4D96FF); // 좋음: 블루
    return Colors.grey;
  }

  Widget _tile(String title, String sub, String grade) {
    final gc = _gradeColor(grade); // ← 여기서 등급별 색 계산
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
          const SizedBox(height: 12),
          GridView(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.55, // ← 1.9 → 1.55 로 낮춰 타일 높이 ↑
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
