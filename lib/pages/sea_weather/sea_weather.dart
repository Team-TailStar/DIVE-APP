import 'package:flutter/material.dart';
import '../routes.dart';
import '../tide/tide_page.dart';

class SeaWeatherPage extends StatefulWidget {
  const SeaWeatherPage({super.key});

  @override
  State<SeaWeatherPage> createState() => _SeaWeatherPageState();
}

class _SeaWeatherPageState extends State<SeaWeatherPage> {
  int bottomIndex = 0;
  String tab = '파도';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          '바다 날씨',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            // 상단 위치 & 지역 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '경기 북부 앞바다',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.regionSelect),
                  child: const Text('지역 선택', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segmented tabs (파도 / 수온)
            Row(
              children: [
                _SelectableChip(
                  label: '파도',
                  selected: tab == '파도',
                  onTap: () => setState(() => tab = '파도'),
                ),
                const SizedBox(width: 8),
                _SelectableChip(
                  label: '수온',
                  selected: tab == '수온',
                  onTap: () => setState(() => tab = '수온'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 날짜
            const Center(
              child: Text(
                '2025.8.14 (목)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 16),

            // 카드 3개 (파주기/파고/파향)
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: '파주기',
                    icon: Icons.show_chart,
                    value: '0.5-1.5 s',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: '파고',
                    icon: Icons.tsunami, // requires Material Icons v (Flutter >=3.7)
                    value: '0.5 m',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: '파향',
                    icon: Icons.explore,
                    value: '서남-서',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            const Text(
              '파도 예측',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            _ForecastTable(
              rows: const [
                _ForecastRowData(date: '8.15 (금)', amPm: '오전', period: '0.5-1.5(s)', height: '0.8(m)', dir: '서남-서'),
                _ForecastRowData(date: '8.15 (금)', amPm: '오후', period: '0.5-1.5(s)', height: '0.8(m)', dir: '서남-서'),
                _ForecastRowData(date: '8.16 (토)', amPm: '오전', period: '0.5-1.5(s)', height: '0.8(m)', dir: '서남-서'),
                _ForecastRowData(date: '8.16 (토)', amPm: '오후', period: '0.5-1.5(s)', height: '0.8(m)', dir: '서남-서'),
                _ForecastRowData(date: '8.17 (일)', amPm: '오전', period: '0.5-1.5(s)', height: '0.8(m)', dir: '서남-서'),
                _ForecastRowData(date: '8.17 (일)', amPm: '오후', period: '0.5-1.5(s)', height: '0.8(m)', dir: '서남-서'),
              ],
            ),

            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {},
                child: const Text('더보기'),
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomIndex,
        onTap: (i) {
          setState(() => bottomIndex = i);
          if (i == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TidePage()), // tide_page.dart의 TidePage
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 8,
      ),

    );
  }
}

/// ------------------------
/// Widgets
/// ------------------------

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? cs.primary : Colors.black12,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: cs.primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? cs.primary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String value;
  const _StatCard({required this.title, required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)),
            const SizedBox(height: 8),
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withOpacity(0.25)),
              ),
              child: Center(
                child: Icon(icon, size: 34, color: cs.primary),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1FAFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastRowData {
  final String date;
  final String amPm;
  final String period; // 파주기
  final String height; // 파고
  final String dir; // 파향
  const _ForecastRowData({
    required this.date,
    required this.amPm,
    required this.period,
    required this.height,
    required this.dir,
  });
}

class _ForecastTable extends StatelessWidget {
  final List<_ForecastRowData> rows;
  const _ForecastTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    final headerStyle =
    TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.6));

    return Column(
      children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _h('날짜', flex: 4, style: headerStyle),
              _h('파주기', flex: 4, style: headerStyle),
              _h('파고', flex: 3, style: headerStyle),
              _h('파향', flex: 4, style: headerStyle),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // body
        ..._buildGrouped(rows),
      ],
    );
  }

  List<Widget> _buildGrouped(List<_ForecastRowData> rows) {
    // group by date like the mock (date shown once, AM/PM rows inside a card)
    final List<Widget> cards = [];
    String? currentDate;
    List<_ForecastRowData> bucket = [];

    void flush() {
      if (bucket.isEmpty) return;
      cards.add(_ForecastCard(date: currentDate!, items: List.of(bucket)));
      bucket.clear();
    }

    for (final r in rows) {
      if (currentDate != r.date) {
        flush();
        currentDate = r.date;
      }
      bucket.add(r);
    }
    flush();
    return cards;
  }

  Widget _h(String t, {required int flex, TextStyle? style}) =>
      Expanded(flex: flex, child: Text(t, style: style));
}

class _ForecastCard extends StatelessWidget {
  final String date;
  final List<_ForecastRowData> items;
  const _ForecastCard({required this.date, required this.items});

  @override
  Widget build(BuildContext context) {
    final labelStyle =
    TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.85));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(date, style: labelStyle),
                ),
                const Expanded(flex: 11, child: SizedBox()),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        _AmPmChip(text: r.amPm, isAm: r.amPm == '오전'),
                      ],
                    ),
                  ),
                  Expanded(flex: 4, child: Text(r.period)),
                  Expanded(flex: 3, child: Text(r.height)),
                  Expanded(flex: 4, child: Text(r.dir)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _AmPmChip extends StatelessWidget {
  final String text;
  final bool isAm;
  const _AmPmChip({required this.text, required this.isAm});

  @override
  Widget build(BuildContext context) {
    final bg = isAm ? const Color(0xFFFFE6E6) : const Color(0xFFE7F0FF);
    final fg = isAm ? const Color(0xFFCC3A3A) : const Color(0xFF3056D3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
