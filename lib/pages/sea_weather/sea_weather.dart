import 'package:flutter/material.dart';
import '../../routes.dart';

class SeaWeatherPage extends StatefulWidget {
  const SeaWeatherPage({super.key});

  @override
  State<SeaWeatherPage> createState() => _SeaWeatherPageState();
}

class _SeaWeatherPageState extends State<SeaWeatherPage> {
  int bottomIndex = 0;
  String tab = '파도'; // '파도' / '수온'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text('바다 날씨',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            // 상단 위치 & 지역 선택
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('경기 북부 앞바다',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, Routes.regionSelect),
                  child: const Text('지역 선택',
                      style: TextStyle(fontSize: 16, color: Colors.black45)),
                )
              ],
            ),
            const SizedBox(height: 12),

            // 탭
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
            const SizedBox(height: 20),

            // 컨텐츠
            if (tab == '파도') const _WaveSection() else const _TempSection(),
          ],
        ),
      ),

      // 하단 탭
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomIndex,
        onTap: (i) => setState(() => bottomIndex = i),
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

/* -----------------------
 *  파도 섹션
 * ----------------------*/
class _WaveSection extends StatelessWidget {
  const _WaveSection();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text('2025.8.14 (목)',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 16),

        // 상단 3개 카드
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9EEF3)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(child: Center(child: Text('파주기', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)))),
                  Expanded(child: Center(child: Text('파고', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)))),
                  Expanded(child: Center(child: Text('파향', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black54)))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _IconBox(cs: cs, icon: Icons.ssid_chart)),
                  const SizedBox(width: 10),
                  Expanded(child: _IconBox(cs: cs, icon: Icons.tsunami)),
                  const SizedBox(width: 10),
                  Expanded(child: _IconBox(cs: cs, icon: Icons.explore)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(child: _ValuePill(text: '0.5-1.5 s')),
                  SizedBox(width: 10),
                  Expanded(child: _ValuePill(text: '0.5 m')),
                  SizedBox(width: 10),
                  Expanded(child: _ValuePill(text: '서남-서')),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
        const Text('파도 예측', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        _ForecastBlock(
          rows: const [
            _ForecastRowData(date: '8.15 (금)', amPm: '오전', period: '0.5–1.5 s', height: '0.8 m', dir: '서남–서'),
            _ForecastRowData(date: '8.15 (금)', amPm: '오후', period: '0.6–1.4 s', height: '0.7 m', dir: '서'),
            _ForecastRowData(date: '8.16 (토)', amPm: '오전', period: '0.5–1.6 s', height: '0.9 m', dir: '서남'),
            _ForecastRowData(date: '8.16 (토)', amPm: '오후', period: '0.7–1.8 s', height: '1.0 m', dir: '서북–서'),
            _ForecastRowData(date: '8.17 (일)', amPm: '오전', period: '0.4–1.2 s', height: '0.6 m', dir: '서'),
            _ForecastRowData(date: '8.17 (일)', amPm: '오후', period: '0.6–1.3 s', height: '0.7 m', dir: '서남'),
          ],
        ),
        const SizedBox(height: 6),

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: null,
            child: const Text('더보기',
                style: TextStyle(color: Colors.black26, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  final ColorScheme cs;
  final IconData icon;
  const _IconBox({required this.cs, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(0.35)),
      ),
      child: Center(child: Icon(icon, size: 34, color: cs.primary)),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String text;
  const _ValuePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FAFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/* -----------------------
 *  수온 섹션 (기존)
 * ----------------------*/
class _TempSection extends StatefulWidget {
  const _TempSection();

  @override
  State<_TempSection> createState() => _TempSectionState();
}

class _TempSectionState extends State<_TempSection> {
  String mode = '그래프'; // '그래프' / '표'

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text('2025.8.14 (목)',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 16),

        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1FAFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        child: Text('경기 북부 앞바다\n현재 수온 :',
                            style: TextStyle(fontWeight: FontWeight.w700, height: 1.2)),
                      ),
                      Text('26.9°C',
                          style: TextStyle(
                              color: Colors.red, fontWeight: FontWeight.w900, fontSize: 18)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6FBFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const _MiniLineChart(),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('최근 업데이트 : 2025.8.14 11:00 A.M.',
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, Routes.tempCompare),
                    child: const Text(
                      '인근 바다와 수온 비교해보기',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),
        const Text('최근 경기 북부 앞바다 수온',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),

        Row(
          children: [
            _SelectableChip(
              label: '그래프',
              selected: mode == '그래프',
              onTap: () => setState(() => mode = '그래프'),
            ),
            const SizedBox(width: 8),
            _SelectableChip(
              label: '표',
              selected: mode == '표',
              onTap: () => setState(() => mode = '표'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (mode == '그래프')
          SizedBox(
            height: 180,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFE9F5FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: _MiniLineChart(secondary: true),
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: const [
                  _TempRow(date: '8.13 (수)', obs: '23:00', minT: '26.9°C', maxT: '12:00', rec: '26.9°C'),
                  _TempRow(date: '8.12 (화)', obs: '23:00', minT: '26.9°C', maxT: '12:00', rec: '26.9°C'),
                  _TempRow(date: '8.11 (월)', obs: '23:00', minT: '26.7°C', maxT: '12:00', rec: '26.8°C'),
                  _TempRow(date: '8.10 (일)', obs: '23:00', minT: '26.5°C', maxT: '12:00', rec: '26.6°C'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/* -----------------------
 *  인근 바다 수온 비교 페이지 (기존)
 * ----------------------*/
class TempComparePage extends StatelessWidget {
  const TempComparePage({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = List.generate(
      8,
          (i) => const _CompareRow(
        place: '인천',
        trendUp: true,
        temp: '26.9°C',
        dist: '0.8㎞',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('바다 날씨'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const Center(
            child: Text('2025.8.14 (목)',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('인근 바다와 수온 비교',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _CompareHeader(),
                ),
                const SizedBox(height: 8),
                ...rows.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: e,
                )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (_) {},
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_heart_outlined), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: ''),
        ],
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

/* -----------------------
 *  공용 위젯들
 * ----------------------*/
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
        duration: const Duration(milliseconds: 160),
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

/// 헤더 + 날짜별 카드 리스트
class _ForecastBlock extends StatelessWidget {
  final List<_ForecastRowData> rows;
  const _ForecastBlock({required this.rows});

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.w800, color: Colors.black54,
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            // 헤더: flex 합을 본문과 동일하게 맞춤 (8/4/3/4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F5FF),
                borderRadius: BorderRadius.circular(12),
              ),
              // 기존 Row(...) 를 아래로 교체
              child: Row(
                children: const [
                  Expanded(flex: 8, child: Text('날짜', style: headerStyle)),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: EdgeInsets.only(left: 10),
                      child: Text('파주기', style: headerStyle),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: Text('파고', style: headerStyle),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: EdgeInsets.only(left: 14),
                      child: Text('파향', style: headerStyle),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            ..._buildGrouped(rows),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGrouped(List<_ForecastRowData> rows) {
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

  const _ForecastCard({
    super.key,
    required this.date,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.85),
    );

    Widget _colTexts(List<String> v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        v.length,
            (i) => Padding(
          padding: EdgeInsets.only(bottom: i == v.length - 1 ? 0 : 12),
          child: Text(
            v[i],
            overflow: TextOverflow.ellipsis, // 안전장치
            softWrap: false,
          ),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E9FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 날짜 + 오전/오후 칩
          Expanded(
            flex: 8, // ← 넓혀서 오버플로우 여지 감소
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72, // ← 폭 축소
                  child: Center(child: Text(date, style: labelStyle)),
                ),
                const SizedBox(width: 12),
                // 칩 열
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    items.length,
                        (i) => Padding(
                      padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
                      child: _AmPmChip(
                        text: items[i].amPm,
                        isAm: items[i].amPm == '오전',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 파주기 / 파고 / 파향
          // _ForecastCard.build() 안의 Row에서 (2) 파주기 / 파고 / 파향 부분 교체
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 10), // ← 여백 추가
              child: _colTexts(items.map((e) => e.period).toList()),
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 14), // ← 여백 추가
              child: _colTexts(items.map((e) => e.height).toList()),
            ),
          ),
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(left: 14), // ← 여백 추가
              child: _colTexts(items.map((e) => e.dir).toList()),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // ← 살짝 줄임
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/* ---- 수온 표/비교용 컴포넌트 ---- */

class _TempRow extends StatelessWidget {
  final String date;
  final String obs;   // 관측시간
  final String minT;  // 현재(대신 사용)
  final String maxT;  // 최고시간
  final String rec;   // 최고온도
  const _TempRow({
    required this.date,
    required this.obs,
    required this.minT,
    required this.maxT,
    required this.rec,
  });

  @override
  Widget build(BuildContext context) {
    final chip = (String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(t,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 86, child: Text(date, style: const TextStyle(fontWeight: FontWeight.w700))),
          SizedBox(width: 60, child: Text(obs, textAlign: TextAlign.center)),
          SizedBox(width: 70, child: Center(child: chip(minT))),
          SizedBox(width: 60, child: Text(maxT, textAlign: TextAlign.center)),
          SizedBox(width: 74, child: Center(child: chip(rec))),
        ],
      ),
    );
  }
}

class _CompareHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 5, child: Text('위치', style: TextStyle(fontWeight: FontWeight.w800))),
        Expanded(flex: 3, child: Text('변화', textAlign: TextAlign.center)),
        Expanded(flex: 4, child: Text('수온', textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Text('거리', textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Text('이동', textAlign: TextAlign.center)),
      ],
    );
  }
}

class _CompareRow extends StatelessWidget {
  final String place;
  final bool trendUp;
  final String temp;
  final String dist;

  const _CompareRow({
    required this.place,
    required this.trendUp,
    required this.temp,
    required this.dist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EEF3)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(place, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(
            flex: 3,
            child: Center(
              child: Icon(trendUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: trendUp ? Colors.red : Colors.blue),
            ),
          ),
          Expanded(flex: 4, child: Center(child: _tempPill(text: temp))),
          Expanded(flex: 3, child: Center(child: Text(dist))),
          Expanded(
            flex: 3,
            child: Center(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('이동'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tempPill({required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
    );
  }
}

/* ---- 아주 가벼운 더미 라인차트 (패키지 없이) ---- */
class _MiniLineChart extends StatelessWidget {
  final bool secondary;
  const _MiniLineChart({this.secondary = false});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniLinePainter(secondary: secondary),
      size: Size.infinite,
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final bool secondary;
  _MiniLinePainter({required this.secondary});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFDAE7F2)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final p1 = Paint()
      ..color = const Color(0xFF5A7DFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    final path1 = Path();
    for (int i = 0; i <= 20; i++) {
      final wave = (i % 4 < 2 ? 1 - (i % 2) * 0.5 : 0.5);
      final x = size.width * (i / 20);
      final y = size.height * (0.7 - 0.2 * wave);
      if (i == 0) path1.moveTo(x, y); else path1.lineTo(x, y);
    }
    canvas.drawPath(path1, p1);

    if (secondary) {
      final p2 = Paint()
        ..color = const Color(0xFFB35DFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final path2 = Path();
      for (int i = 0; i <= 20; i++) {
        final wave = (i % 4 < 2 ? 1 - (i % 2) * 0.4 : 0.4);
        final x = size.width * (i / 20);
        final y = size.height * (0.6 - 0.22 * wave);
        if (i == 0) path2.moveTo(x, y); else path2.lineTo(x, y);
      }
      canvas.drawPath(path2, p2);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLinePainter oldDelegate) =>
      oldDelegate.secondary != secondary;
}
