import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'tide_models.dart';
import 'tide_services.dart';
import '../../app_bottom_nav.dart';


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
    "jowi1":"03:36 (6.4) ▼ -66.0","jowi2":"09:33 (11.7) ▲ +76.0",
    "jowi3":"15:56 (6.0) ▼ -68.0","jowi4":"21:58 (11.9) ▲ +78.0",
    "pSun":"05:35/19:11","pMoon":"09:20/21:56"
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

class TidePage extends StatefulWidget {
  const TidePage({super.key});
  @override
  State<TidePage> createState() => _TidePageState();
}

class _TidePageState extends State<TidePage> {
  late final BadaTimeApi api;
  List<TideDay> days = [];
  DateTime selectedDate = DateTime.now(); // ← 선택한 날짜 (기본: 오늘)
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    api = BadaTimeApi(
      serviceKey: const String.fromEnvironment('BADATIME_SERVICE_KEY'),
      lat: 35.10, lon: 129.03,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    const useMock = bool.fromEnvironment('USE_TIDE_MOCK', defaultValue: false);
    try {
      final parsed = useMock ? _parseMock(_mockJson) : await api.fetch7Days();
      if (parsed.isEmpty) throw Exception('결과 없음');
      parsed.sort((a, b) => a.date.compareTo(b.date));
      setState(() { days = parsed; });
    } catch (e) {
      setState(() { error = e.toString(); });
    } finally {
      setState(() { loading = false; });
    }
  }

  // Mock → 모델
  List<TideDay> _parseMock(List<Map<String, dynamic>> arr) {
    final out = <TideDay>[];
    for (final item in arr) {
      final e1 = TideEvent.parse((item['jowi1'] ?? '').toString(), label: '간조 1/만조 1');
      final e2 = TideEvent.parse((item['jowi2'] ?? '').toString(), label: '간조 2/만조 2');
      final e3 = TideEvent.parse((item['jowi3'] ?? '').toString(), label: '간조 3/만조 3');
      final e4 = TideEvent.parse((item['jowi4'] ?? '').toString(), label: '간조 4/만조 4');

      final events = <TideEvent>[];
      int hi = 0, lo = 0;
      for (final e in [e1, e2, e3, e4]) {
        if (e == null) continue;
        if (e.type == '만조') {
          hi += 1;
          events.add(TideEvent(
            label: '만조 $hi',
            hhmm: e.hhmm,
            heightCm: e.heightCm,
            type: e.type,
            delta: e.delta,
          ));
        } else {
          lo += 1;
          events.add(TideEvent(
            label: '간조 $lo',
            hhmm: e.hhmm,
            heightCm: e.heightCm,
            type: e.type,
            delta: e.delta,
          ));
        }
      }


      out.add(TideDay(
        dateRaw: (item['pThisDate'] ?? '').toString(),
        regionName: (item['pName'] ?? '').toString(),
        areaId: (item['pArea'] ?? '').toString(),
        mul: (item['pMul'] ?? '').toString(),
        sun: (item['pSun'] ?? '').toString(),
        moon: (item['pMoon'] ?? '').toString(),
        events: events,
      ));
    }
    return out;
  }

  // 선택한 날짜와 정확히 일치하는 TideDay 찾기
  TideDay? get _selectedDay {
    final idx = days.indexWhere((e) => DateUtils.isSameDay(e.date, selectedDate));
    return idx == -1 ? null : days[idx];
  }

  // 이전/다음 데이터가 있는 날짜 찾기
  DateTime? _prevAvailableDate() {
    DateTime? best;
    for (final d in days) {
      if (d.date.isBefore(selectedDate)) {
        if (best == null || d.date.isAfter(best)) best = d.date;
      }
    }
    return best;
  }

  DateTime? _nextAvailableDate() {
    DateTime? best;
    for (final d in days) {
      if (d.date.isAfter(selectedDate)) {
        if (best == null || d.date.isBefore(best)) best = d.date;
      }
    }
    return best;
  }

  // 휠 피커 공통
  Future<int?> _showWheelPicker({
    required String titleSuffix,
    required List<int> values,
    required int currentValue,
  }) async {
    int selVal = currentValue;
    final ctrl = FixedExtentScrollController(
      initialItem: values.indexOf(currentValue).clamp(0, values.length - 1),
    );

    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
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
                      child: Text('$selVal$titleSuffix',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx, selVal),
                        child: const Text('완료')),
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
                  onSelectedItemChanged: (i) => selVal = values[i],
                  children: [for (final v in values) Center(child: Text('$v$titleSuffix', style: const TextStyle(fontSize: 22)))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _lastDayOfMonth(int y, int m) => DateTime(y, m + 1, 0).day;
  int _safeDay(int y, int m, int d) => d.clamp(1, _lastDayOfMonth(y, m));

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final minY = days.isNotEmpty ? days.first.date.year - 10 : now.year - 10;
    final maxY = days.isNotEmpty ? days.last.date.year + 10  : now.year + 10;
    final years = [for (int y = minY; y <= maxY; y++) y];

    final picked = await _showWheelPicker(
        titleSuffix: '년', values: years, currentValue: selectedDate.year);
    if (picked == null) return;

    final y = picked, m = selectedDate.month, d = _safeDay(y, m, selectedDate.day);
    setState(() => selectedDate = DateTime(y, m, d)); // ← 근접 이동 없음
  }

  Future<void> _pickMonth() async {
    final months = [for (int m = 1; m <= 12; m++) m];
    final picked = await _showWheelPicker(
        titleSuffix: '월', values: months, currentValue: selectedDate.month);
    if (picked == null) return;

    final y = selectedDate.year, m = picked, d = _safeDay(y, m, selectedDate.day);
    setState(() => selectedDate = DateTime(y, m, d));
  }

  Future<void> _pickDay() async {
    final y = selectedDate.year, m = selectedDate.month;
    final daysVals = [for (int d = 1; d <= _lastDayOfMonth(y, m); d++) d];
    final picked = await _showWheelPicker(
        titleSuffix: '일', values: daysVals, currentValue: selectedDate.day);
    if (picked == null) return;
    setState(() => selectedDate = DateTime(y, m, picked));
  }

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
        DateTime displayedMonth = DateTime(selectedDate.year, selectedDate.month);
        final h = MediaQuery.of(ctx).size.height;
        return SafeArea(
          top: false,
          child: SizedBox(
            height: h * 0.65,
            child: StatefulBuilder(builder: (ctx, setSheetState) {
              final canGoPrev = !DateTime(displayedMonth.year, displayedMonth.month - 1, 1)
                  .isBefore(DateTime(first.year, first.month, 1));
              final canGoNext = !DateTime(displayedMonth.year, displayedMonth.month + 1, 1)
                  .isAfter(DateTime(last.year, last.month, 1));

              DateTime safeInitial = DateTime(displayedMonth.year, displayedMonth.month, 15);
              if (safeInitial.isBefore(first)) safeInitial = first;
              if (safeInitial.isAfter(last))  safeInitial = last;

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: canGoPrev
                              ? () => setSheetState(() => displayedMonth =
                              DateTime(displayedMonth.year, displayedMonth.month - 1))
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const SizedBox(width: 6),
                        Text('${displayedMonth.year}년 ${displayedMonth.month}월',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: canGoNext
                              ? () => setSheetState(() => displayedMonth =
                              DateTime(displayedMonth.year, displayedMonth.month + 1))
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: CalendarDatePicker(
                        key: ValueKey('${displayedMonth.year}-${displayedMonth.month}'),
                        initialDate: safeInitial,
                        firstDate: first,
                        lastDate: last,
                        currentDate: selectedDate,
                        onDisplayedMonthChanged: (d) =>
                            setSheetState(() => displayedMonth = DateTime(d.year, d.month)),
                        onDateChanged: (d) => Navigator.pop(ctx, d),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked); // ← 근접 이동 없음
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (loading || error != null || days.isEmpty)
        ? '물때'
        : (_selectedDay?.regionName ?? '물때');

    return Scaffold(
      backgroundColor: const Color(0xFFEDF6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.chevron_left, size: 32),
            onPressed: () => Navigator.pop(context))
            : null,
        actions: [
          IconButton(tooltip: '새로고침', icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildError(error!)
          : _buildContent(),
    bottomNavigationBar: const AppBottomNav(currentIndex: 2)
    );
  }

  Widget _buildError(String msg) => Center(
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

  Widget _buildContent() {
    final date = selectedDate;
    final y = date.year;
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final wk = ['월','화','수','목','금','토','일'][date.weekday-1];

    final prevDate = _prevAvailableDate();
    final nextDate = _nextAvailableDate();
    final day = _selectedDay; // null이면 '정보 없음' 표시

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          // 상단 날짜 바
          Row(
            children: [
              IconButton(
                tooltip: '이전날짜',
                onPressed: prevDate == null ? null : () => setState(() => selectedDate = prevDate),
                icon: const Icon(Icons.chevron_left),
              ),
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
                        IconButton(
                          onPressed: _openCalendar,
                          icon: const Icon(Icons.calendar_month, size: 18, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF1E5A7A),
                            minimumSize: const Size(40, 40),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '다음날짜',
                onPressed: nextDate == null ? null : () => setState(() => selectedDate = nextDate),
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
              boxShadow: [BoxShadow(color: const Color(0xFF3B5BDB).withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 6))],
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('$y년 $m월 $d일 $wk요일',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (day != null) _mulPill(day.mul),
                  ],
                ),
                const SizedBox(height: 12),

                if (day == null) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('물때 정보가 없습니다.',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black54)),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(child: _sunMoonBox(
                        icon: Icons.wb_sunny_outlined,
                        title: '일출', subtitle: '일몰',
                        first: _toAmPm(day.sunrise), second: _toAmPm(day.sunset),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _sunMoonBox(
                        icon: Icons.nights_stay_outlined,
                        title: '월출', subtitle: '월몰',
                        first: _toAmPm(day.moonrise), second: _toAmPm(day.moonset),
                      )),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: const [Icon(Icons.waves, size: 18), SizedBox(width: 6), Text('간만조시각', style: TextStyle(fontWeight: FontWeight.w700))],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    itemCount: day.events.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, mainAxisExtent: 124,
                    ),
                    itemBuilder: (context, i) => _tideCard(day.events[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _datePill(String text, {VoidCallback? onTap}) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2E5BFF).withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E40AF))),
        const SizedBox(width: 6),
        const Icon(Icons.expand_more, size: 16, color: Color(0xFF1E40AF)),
      ]),
    ),
  );

  Widget _mulPill(String mul) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF9E6),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFFFE8A3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: const [
      Icon(Icons.nightlight_outlined, size: 16),
      SizedBox(width: 6),
    ]).apply((row) => Row(mainAxisSize: MainAxisSize.min, children: [row, Text(mul, style: const TextStyle(fontWeight: FontWeight.w700))])),
  );

  Widget _sunMoonBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required String first,
    required String second,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFEDF6FB), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _kv(title, first),
        const SizedBox(height: 6),
        _kv(subtitle, second),
      ])),
    ]),
  );

  Widget _kv(String k, String v) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [Text(k, style: const TextStyle(color: Colors.black54)), Text(v, style: const TextStyle(fontWeight: FontWeight.w700))],
  );

  Widget _tideCard(TideEvent e) {
    final isHigh = e.type == '만조';
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFEDF6FB), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(e.type == '만조' ? '만조 ${_orderNumber(e.label)}' : '간조 ${_orderNumber(e.label)}',
            style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 4),
        Text(_toAmPm(e.hhmm), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: [
          Text('${e.heightCm.toStringAsFixed(1)}cm', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 10),
          Icon(Icons.change_history, size: 16, color: isHigh ? Colors.red : Colors.blue),
          const SizedBox(width: 4),
          Text(e.delta != null ? (e.delta! > 0 ? '+${e.delta}' : '${e.delta}') : '',
              style: TextStyle(fontWeight: FontWeight.w700, color: isHigh ? Colors.red : Colors.blue)),
        ]),
      ]),
    );
  }

  String _orderNumber(String label) => RegExp(r'(\d+)').firstMatch(label)?.group(1) ?? '';

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

// 작은 편의 확장
extension _Apply<T> on T {
  R apply<R>(R Function(T) f) => f(this);
}
