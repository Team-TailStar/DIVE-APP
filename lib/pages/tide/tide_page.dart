import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'tide_models.dart';
import 'tide_services.dart';

// ── Mock ─────────────────────────
const _mockJson = [
  {
    "pThisDate":"2025-8-14-목-7-11",
    "pName":"부산광역시","pArea":"1","pMul":"12물",
    "pSun":"05:32/19:15","pMoon":"07:01/20:10",
    "jowi1":"01:55 (6.1) ▼ -81.3","jowi2":"07:51 (6.1) ▲ +83.5",
    "jowi3":"14:16 (6.1) ▼ -81.3","jowi4":"20:17 (6.1) ▲ +83.5"
  },
  {
    "pThisDate":"2024-8-14-목-7-11",
    "pName":"부산광역시","pArea":"1","pMul":"12물",
    "pSun":"05:32/19:15","pMoon":"07:01/20:10",
    "jowi1":"01:55 (6.1) ▼ -81.3","jowi2":"07:51 (6.1) ▲ +83.5",
    "jowi3":"14:16 (6.1) ▼ -81.3","jowi4":"20:17 (6.1) ▲ +83.5"
  },
  {
    "pThisDate":"2025-8-15-금-7-12",
    "pName":"부산광역시","pArea":"1","pMul":"13물",
    "pSun":"05:33/19:14","pMoon":"07:50/20:42",
    "jowi1":"02:28 (8.0) ▼ -76.0","jowi2":"08:22 (12.8) ▲ +88.0",
    "jowi3":"14:49 (7.2) ▼ -78.0","jowi4":"20:51 (12.9) ▲ +90.0"
  },
  {
    "pThisDate":"2025-8-16-토-7-13",
    "pName":"부산광역시","pArea":"1","pMul":"조금",
    "pSun":"05:34/19:12","pMoon":"08:35/21:18",
    "jowi1":"03:01 (7.0) ▼ -70.0","jowi2":"08:58 (12.2) ▲ +82.0",
    "jowi3":"15:22 (6.5) ▼ -72.0","jowi4":"21:23 (12.4) ▲ +84.0"
  },
  {
    "pThisDate":"2025-8-17-일-7-14",
    "pName":"부산광역시","pArea":"1","pMul":"1물",
    "pSun":"05:35/19:11","pMoon":"09:20/21:56",
    "jowi1":"03:36 (6.4) ▼ -66.0","jowi2":"09:33 (11.7) ▲ +76.0",
    "jowi3":"15:56 (6.0) ▼ -68.0","jowi4":"21:58 (11.9) ▲ +78.0"
  },
  {
    "pThisDate":"2025-8-18-월-7-15",
    "pName":"부산광역시","pArea":"1","pMul":"2물",
    "pSun":"05:36/19:10","pMoon":"10:05/22:36",
    "jowi1":"04:10 (6.0) ▼ -62.0","jowi2":"10:09 (11.3) ▲ +72.0",
    "jowi3":"16:31 (5.7) ▼ -64.0","jowi4":"22:33 (11.5) ▲ +74.0"
  },
  {
    "pThisDate":"2025-8-19-화-7-16",
    "pName":"부산광역시","pArea":"1","pMul":"3물",
    "pSun":"05:37/19:08","pMoon":"10:52/23:19",
    "jowi1":"04:45 (5.8) ▼ -58.0","jowi2":"10:46 (11.0) ▲ +68.0",
    "jowi3":"17:06 (5.5) ▼ -60.0","jowi4":"23:09 (11.2) ▲ +70.0"
  },
  {
    "pThisDate":"2025-8-20-수-7-17",
    "pName":"부산광역시","pArea":"1","pMul":"4물",
    "pSun":"05:38/19:07","pMoon":"11:41/24:00",
    "jowi1":"05:21 (5.6) ▼ -55.0","jowi2":"11:23 (10.8) ▲ +65.0",
    "jowi3":"17:42 (5.3) ▼ -57.0","jowi4":"23:46 (11.0) ▲ +67.0"
  },
];
// ─────────────────────────────────────────────────────────────

class TidePage extends StatefulWidget {
  const TidePage({super.key});

  @override
  State<TidePage> createState() => _TidePageState();
}

class _TidePageState extends State<TidePage> {
  late final BadaTimeApi api;
  List<TideDay> days = [];
  int selectedIndex = 0;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    api = BadaTimeApi(
      serviceKey: const String.fromEnvironment('BADATIME_SERVICE_KEY'),
      lat: 35.10, lon: 129.03,
      // areaId: '1',
    );
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });

    const useMock = bool.fromEnvironment('USE_TIDE_MOCK', defaultValue: false);

    try {
      List<TideDay> parsed = useMock ? _parseMock(_mockJson) : await api.fetch7Days();
      if (parsed.isEmpty) throw Exception('결과 없음');
      parsed.sort((a, b) => a.date.compareTo(b.date));

      // 처음 진입: 오늘이 있으면 오늘, 없으면 가장 가까운 날짜
      final today = DateTime.now();
      final exact = parsed.indexWhere((e) => DateUtils.isSameDay(e.date, today));
      final idx = (exact != -1) ? exact : _closestDateIndex(parsed, today);

      setState(() {
        days = parsed;
        selectedIndex = idx;
      });
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  int _closestDateIndex(List<TideDay> list, DateTime target) {
    int best = 0;
    Duration bestDiff = list.first.date.difference(target).abs();
    for (int i = 1; i < list.length; i++) {
      final diff = list[i].date.difference(target).abs();
      if (diff < bestDiff) { best = i; bestDiff = diff; }
    }
    return best;
  }

  // 모의 JSON → TideDay 로 변환
  List<TideDay> _parseMock(List<Map<String, dynamic>> arr) {
    final out = <TideDay>[];

    for (final item in arr) {
      final pThisDate = (item['pThisDate'] ?? '').toString();
      final pName     = (item['pName'] ?? '').toString();
      final pArea     = (item['pArea'] ?? '').toString();
      final pMul      = (item['pMul'] ?? '').toString();
      final pSun      = (item['pSun'] ?? '').toString();
      final pMoon     = (item['pMoon'] ?? '').toString();

      final TideEvent? e1 = TideEvent.parse((item['jowi1'] ?? '').toString(), label: '간조 1/만조 1');
      final TideEvent? e2 = TideEvent.parse((item['jowi2'] ?? '').toString(), label: '간조 2/만조 2');
      final TideEvent? e3 = TideEvent.parse((item['jowi3'] ?? '').toString(), label: '간조 3/만조 3');
      final TideEvent? e4 = TideEvent.parse((item['jowi4'] ?? '').toString(), label: '간조 4/만조 4');

      final events = <TideEvent>[];
      final raw = [e1, e2, e3, e4];
      int highCnt = 0, lowCnt = 0;

      for (final e in raw) {
        if (e == null) continue;
        if (e.type == '만조') {
          highCnt += 1;
          events.add(TideEvent(
            label: '만조 $highCnt',
            hhmm: e.hhmm,
            heightCm: e.heightCm,
            type: e.type,
            delta: e.delta,
          ));
        } else {
          lowCnt += 1;
          events.add(TideEvent(
            label: '간조 $lowCnt',
            hhmm: e.hhmm,
            heightCm: e.heightCm,
            type: e.type,
            delta: e.delta,
          ));
        }
      }

      out.add(TideDay(
        dateRaw: pThisDate,
        regionName: pName,
        areaId: pArea,
        mul: pMul,
        sun: pSun,
        moon: pMoon,
        events: events,
      ));
    }

    return out;
  }

  // ── 말일/안전일/가까운 날짜 유틸 ─────────────────────────────
  int _lastDayOfMonth(int y, int m) => DateTime(y, m + 1, 0).day;
  int _safeDay(int y, int m, int d) => d.clamp(1, _lastDayOfMonth(y, m));
  void _jumpToClosest(DateTime target) {
    if (days.isEmpty) return;
    int best = 0;
    var bestDiff = days.first.date.difference(target).abs();
    for (int i = 1; i < days.length; i++) {
      final diff = days[i].date.difference(target).abs();
      if (diff < bestDiff) { best = i; bestDiff = diff; }
    }
    setState(() => selectedIndex = best);
  }

  // ── 휠(피커) 시트: 연/월/일 공용 ─────────────────────────────
  Future<int?> _showWheelPicker({
    required String titleSuffix, // '년' / '월' / '일'
    required List<int> values,   // 예: [2020..2030], [1..12], [1..31]
    required int currentValue,
  }) async {
    int selVal = currentValue;
    final initial = values.indexOf(currentValue).clamp(0, values.length - 1);
    final ctrl = FixedExtentScrollController(initialItem: initial);

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return SafeArea(
            top: false,
            child: SizedBox(
              height: 320,
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$selVal$titleSuffix',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, selVal),
                          child: const Text('완료'),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: ctrl,
                      magnification: 1.05,
                      squeeze: 1.15,
                      useMagnifier: true,
                      itemExtent: 44,
                      onSelectedItemChanged: (i) => setSheetState(() => selVal = values[i]),
                      children: [
                        for (final v in values)
                          Center(child: Text('$v$titleSuffix', style: const TextStyle(fontSize: 22))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ── 연/월/일 Pill 동작 ─────────────────────────────────────
  Future<void> _pickYear() async {
    final now = DateTime.now();
    final minY = days.isNotEmpty ? days.first.date.year - 10 : now.year - 10;
    final maxY = days.isNotEmpty ? days.last.date.year + 10  : now.year + 10;
    final years = [for (int y = minY; y <= maxY; y++) y];

    final picked = await _showWheelPicker(
      titleSuffix: '년',
      values: years,
      currentValue: sel.date.year,
    );
    if (picked == null) return;

    final y = picked;
    final m = sel.date.month;
    final d = _safeDay(y, m, sel.date.day);
    _jumpToClosest(DateTime(y, m, d));
  }

  Future<void> _pickMonth() async {
    final months = [for (int m = 1; m <= 12; m++) m];

    final picked = await _showWheelPicker(
      titleSuffix: '월',
      values: months,
      currentValue: sel.date.month,
    );
    if (picked == null) return;

    final y = sel.date.year;
    final m = picked;
    final d = _safeDay(y, m, sel.date.day);
    _jumpToClosest(DateTime(y, m, d));
  }

  Future<void> _pickDay() async {
    final y = sel.date.year;
    final m = sel.date.month;
    final maxD = _lastDayOfMonth(y, m);
    final daysVals = [for (int d = 1; d <= maxD; d++) d];

    final picked = await _showWheelPicker(
      titleSuffix: '일',
      values: daysVals,
      currentValue: sel.date.day,
    );
    if (picked == null) return;

    _jumpToClosest(DateTime(y, m, picked));
  }

  // ── 달력 바텀시트 (아이콘용) ─────────────────────────────────
  Future<void> _openCalendar() async {
    if (days.isEmpty) return;
    final first = days.first.date;
    final last  = days.last.date;

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        DateTime displayedMonth = DateTime(sel.date.year, sel.date.month);
        final h = MediaQuery.of(ctx).size.height;

        return SafeArea(
          top: false,
          child: SizedBox(
            height: h * 0.65,
            child: StatefulBuilder(
              builder: (ctx, setSheetState) {
                final canGoPrev = !DateTime(displayedMonth.year, displayedMonth.month - 1, 1)
                    .isBefore(DateTime(first.year, first.month, 1));
                final canGoNext = !DateTime(displayedMonth.year, displayedMonth.month + 1, 1)
                    .isAfter(DateTime(last.year, last.month, 1));

                // initialDate 범위를 안전하게
                DateTime safeInitial = DateTime(displayedMonth.year, displayedMonth.month, 15);
                if (safeInitial.isBefore(first)) safeInitial = first;
                if (safeInitial.isAfter(last))  safeInitial = last;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    children: [
                      // 헤더
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: '이전 달',
                            onPressed: canGoPrev
                                ? () => setSheetState(() => displayedMonth =
                                DateTime(displayedMonth.year, displayedMonth.month - 1))
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${displayedMonth.year}년 ${displayedMonth.month}월',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(width: 6),
                          IconButton(
                            tooltip: '다음 달',
                            onPressed: canGoNext
                                ? () => setSheetState(() => displayedMonth =
                                DateTime(displayedMonth.year, displayedMonth.month + 1))
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // 본문: 남는 높이에 맞추기
                      Expanded(
                        child: CalendarDatePicker(
                          key: ValueKey('${displayedMonth.year}-${displayedMonth.month}'),
                          initialDate: safeInitial,
                          firstDate: first,
                          lastDate: last,
                          currentDate: sel.date,
                          onDisplayedMonthChanged: (d) =>
                              setSheetState(() => displayedMonth = DateTime(d.year, d.month)),
                          onDateChanged: (date) => Navigator.pop(ctx, date),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    if (picked != null) {
      final idx = days.indexWhere((t) => DateUtils.isSameDay(t.date, picked));
      if (idx != -1) setState(() => selectedIndex = idx);
    }
  }

  // ────────────────────────────────────────────────────────────

  TideDay get sel => days[selectedIndex];
  void _prev() { if (selectedIndex > 0) setState(() => selectedIndex--); }
  void _next() { if (selectedIndex < days.length - 1) setState(() => selectedIndex++); }

  @override
  Widget build(BuildContext context) {
    final title = (loading || error != null || days.isEmpty) ? '물때' : sel.regionName;

    return Scaffold(
      backgroundColor: const Color(0xFFEDF6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
          icon: const Icon(Icons.chevron_left, size: 32),
          onPressed: () => Navigator.pop(context),
        )
            : null,
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildError(error!)
          : _buildContent(),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline),
          const SizedBox(height: 8),
          Text('불러오기 실패\n$msg', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('다시 시도')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final date = sel.date;
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final weekdayKr = ['월','화','수','목','금','토','일'][date.weekday-1];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          // 상단 날짜바: 가운데 Pill(휠 선택), 아이콘은 달력
          Row(
            children: [
              IconButton(
                tooltip: '이전날짜',
                onPressed: selectedIndex > 0 ? _prev : null,
                icon: const Icon(Icons.chevron_left),
              ),

              // ⬇ 가운데 묶음: 화면 폭을 넘기면 자동으로 살짝 축소되게 FittedBox 적용
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _datePill('$y', onTap: _pickYear),
                        const SizedBox(width: 8),
                        _datePill(m, onTap: _pickMonth),
                        const SizedBox(width: 8),
                        _datePill(d, onTap: _pickDay),
                        const SizedBox(width: 8),

                        // ⬇ 달력 버튼: 크기 고정(40x40), 패딩 0
                        IconButton(
                          onPressed: _openCalendar,
                          icon: const Icon(Icons.calendar_month, size: 18, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF1E5A7A), // 원하는 색
                            minimumSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              IconButton(
                tooltip: '다음날짜',
                onPressed: selectedIndex < days.length - 1 ? _next : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 메인 카드
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B5BDB).withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                )
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$y년 $m월 $d일 $weekdayKr요일',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _mulPill(sel.mul), // → 오른쪽 끝으로 밀림
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: _sunMoonBox(
                      icon: Icons.wb_sunny_outlined,
                      title: '일출', subtitle: '일몰',
                      first: _toAmPm(sel.sunrise), second: _toAmPm(sel.sunset),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _sunMoonBox(
                      icon: Icons.nights_stay_outlined,
                      title: '월출', subtitle: '월몰',
                      first: _toAmPm(sel.moonrise), second: _toAmPm(sel.moonset),
                    )),
                  ],
                ),
                const SizedBox(height: 14),

                Row(
                  children: const [
                    Icon(Icons.waves, size: 18),
                    SizedBox(width: 6),
                    Text('간만조시각', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 10),

                GridView.builder(
                  itemCount: sel.events.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    mainAxisExtent: 124, // ← 기기/폰트에 따라 120~140로 조절
                  ),
                  itemBuilder: (context, i) => _tideCard(sel.events[i]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _datePill(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2E5BFF).withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, style: const TextStyle(
                fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more, size: 16, color: Color(0xFF1E40AF)),
          ],
        ),
      ),
    );
  }

  Widget _mulPill(String mul) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE8A3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nightlight_outlined, size: 16),
          const SizedBox(width: 6),
          Text(mul, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }


  Widget _sunMoonBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required String first,
    required String second,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF6FB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(title, first),
                const SizedBox(height: 6),
                _kv(subtitle, second),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _tideCard(TideEvent e) {
    final isHigh = e.type == '만조';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEDF6FB),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.type == '만조' ? '만조 ${_orderNumber(e.label)}' : '간조 ${_orderNumber(e.label)}',
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            _toAmPm(e.hhmm),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${e.heightCm.toStringAsFixed(1)}cm',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Icon(Icons.change_history, size: 16, color: isHigh ? Colors.red : Colors.blue),
              const SizedBox(width: 4),
              Text(
                e.delta != null ? (e.delta! > 0 ? '+${e.delta}' : '${e.delta}') : '',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isHigh ? Colors.red : Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _orderNumber(String label) {
    final m = RegExp(r'(\d+)').firstMatch(label);
    return m?.group(1) ?? '';
  }

  String _toAmPm(String hhmm) {
    try {
      final now = DateTime.now();
      final h = int.parse(hhmm.substring(0, 2));
      final m = int.parse(hhmm.substring(3, 5));
      return DateFormat('hh:mm a').format(DateTime(now.year, now.month, now.day, h, m));
    } catch (_) {
      return hhmm;
    }
  }
}
