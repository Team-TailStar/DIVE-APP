// lib/pages/weather/air_quality_card.dart
import 'package:flutter/material.dart';
import 'air_quality_service.dart';

class AirQualityCard extends StatelessWidget {
  final AirQualitySummary data;
  const AirQualityCard({super.key, required this.data});

  String _pmLabel(String? v) => (v == null) ? '—' : '$v ㎍/㎥';
  String _gasLabel(String? v) => (v == null) ? '—' : '$v ppm';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metaTop = _metaLine();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text('대기질 정보',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1D3557),
                  )),
              const Spacer(),
              const Icon(Icons.eco_outlined, size: 18, color: Color(0xFF1D3557)),
            ],
          ),
          const SizedBox(height: 6),
          if (metaTop.isNotEmpty)
            Text(metaTop, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF5C6B80))),
          const SizedBox(height: 12),


          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,        // 2열
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 120,
            ),
            children: [
              _tile(
                title: '미세먼지', sub: 'PM10',
                grade: data.pm10, valueLine: _pmLabel(data.pm10Value),
              ),
              _tile(
                title: '초미세먼지', sub: 'PM2.5',
                grade: data.pm25, valueLine: _pmLabel(data.pm25Value),
              ),
              _tile(
                title: '오존', sub: 'O₃',
                grade: data.o3, valueLine: _gasLabel(data.o3Value),
              ),
              _tile(
                title: '이산화질소', sub: 'NO₂',
                grade: data.no2 ?? '정보없음', valueLine: _gasLabel(data.no2Value),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              data.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF1D3557),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine() {
    final loc = data.regionLabel;
    final at = data.announcedAt;
    final when = (at == null) ? '' : '${at.month}월 ${at.day}일 ${at.hour}시 발표';
    if (loc.isNotEmpty && when.isNotEmpty) return '$loc · $when';
    if (loc.isNotEmpty) return loc;
    return when;
  }

  Widget _tile({
    required String title,
    required String sub,
    required String grade,
    required String valueLine,
  }) {
    final isUnavailable = grade.contains('정보없음');

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 92), // 카드 높이 안정화
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUnavailable ? const Color(0xFFE9EEF4) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnavailable ? const Color(0xFFE0E6ED) : const Color(0xFFDCE7F5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 타이틀 줄
            Row(
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF334B68), fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(sub, style: const TextStyle(color: Color(0xFF8DA2B5), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),

            // 등급 배지
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isUnavailable ? const Color(0xFFCFD8E3) : _gradeColor(grade).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isUnavailable ? const Color(0xFFCFD8E3) : _gradeColor(grade),
                  ),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isUnavailable ? const Color(0xFF607087) : _gradeColor(grade),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6),

            // 수치 라인
            Text(
              valueLine,
              style: TextStyle(
                color: isUnavailable ? const Color(0xFF9AA9B8) : const Color(0xFF4A6076),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    if (grade.contains('매우')) return const Color(0xFFE53935); // 매우나쁨
    if (grade.contains('나쁨')) return const Color(0xFFFF9800); // 나쁨
    if (grade.contains('보통')) return const Color(0xFFFBBC05); // 보통
    if (grade.contains('좋음')) return const Color(0xFF2E7D32); // 좋음
    return const Color(0xFF607087); // 정보없음
  }
}
