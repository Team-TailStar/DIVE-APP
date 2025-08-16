// lib/pages/weather/weather_page.dart
import 'package:flutter/material.dart';

import '../../app_bottom_nav.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('날씨'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),

      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // 위치 + 새로고침
            Row(
              children: [
                const Icon(Icons.place, size: 20, color: Colors.redAccent),
                const SizedBox(width: 6),
                const Text('부산광역시 남구', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.refresh),
                  tooltip: '새로고침',
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 오늘 카드
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary.withOpacity(0.18), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8EEF4)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('오늘 • 맑음', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('29°', style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('최고 31° / 최저 24°', style: TextStyle(color: Colors.black54)),
                          SizedBox(height: 4),
                          Text('체감 30°, 자외선 보통', style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.wb_sunny_outlined, size: 48, color: Colors.orange),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),
            const Text('시간대별 예보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),

            // 시간대별 슬라이더
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(10, (i) {
                  final hour = (10 + i) % 24;
                  final temp = 26 + (i % 4);
                  final sunny = i.isEven;
                  return Padding(
                    padding: EdgeInsets.only(right: i == 9 ? 0 : 10),
                    child: _HourTile(
                      hour: '$hour시',
                      icon: sunny ? Icons.wb_sunny_outlined : Icons.cloud_outlined,
                      temp: '$temp°',
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 18),
            const Text('지금 상태', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),

            // 지표들 2x2
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _MetricCard(icon: Icons.air, title: '바람', value: '4.1 m/s', hint: '서남서'),
                _MetricCard(icon: Icons.water_drop_outlined, title: '습도', value: '64%', hint: '보통'),
                _MetricCard(icon: Icons.compress, title: '기압', value: '1008 hPa', hint: '안정'),
                _MetricCard(icon: Icons.remove_red_eye_outlined, title: '가시거리', value: '10 km', hint: '양호'),
              ],
            ),

            const SizedBox(height: 18),
            const Text('5일 예보', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  children: const [
                    _DailyRow(day: '오늘', icon: Icons.wb_sunny_outlined, min: '24°', max: '31°'),
                    _DailyRow(day: '목', icon: Icons.cloud_outlined, min: '24°', max: '30°'),
                    _DailyRow(day: '금', icon: Icons.wb_twilight_outlined, min: '23°', max: '30°'),
                    _DailyRow(day: '토', icon: Icons.thunderstorm_outlined, min: '22°', max: '28°'),
                    _DailyRow(day: '일', icon: Icons.wb_cloudy_outlined, min: '23°', max: '29°'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // 하단 네비게이션 (현재 탭 = 0)
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

/* ====== 작은 위젯들 ====== */

class _HourTile extends StatelessWidget {
  final String hour;
  final IconData icon;
  final String temp;
  const _HourTile({required this.hour, required this.icon, required this.temp});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE8EEF4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hour, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Icon(icon, size: 28, color: Colors.orange),
          const SizedBox(height: 6),
          Text(temp, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String hint;
  const _MetricCard({required this.icon, required this.title, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 20 - 20 - 10) / 2, // 좌/우 패딩, 카드 간격 고려
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8EEF4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blueAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(hint, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  final String day;
  final IconData icon;
  final String min;
  final String max;
  const _DailyRow({required this.day, required this.icon, required this.min, required this.max});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 46, child: Text(day, style: const TextStyle(fontWeight: FontWeight.w700))),
          Icon(icon, color: Colors.orange),
          const Spacer(),
          Text(min, style: const TextStyle(color: Colors.blue)),
          const SizedBox(width: 10),
          Text(max, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
