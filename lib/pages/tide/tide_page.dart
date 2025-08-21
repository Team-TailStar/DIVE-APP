import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../app_bottom_nav.dart';
import 'tide_models.dart';
import 'tide_services.dart';
import 'package:geolocator/geolocator.dart';
import '../sea_weather/region_picker.dart';
import 'package:dive_app/pages/ui/aq_theme.dart';
import 'package:dive_app/pages/ui/aq_widget.dart';

/// 물때 칩(물때명 표시) — Aq 테마 톤
class _MulChip extends StatelessWidget {
  final String mul;
  const _MulChip(this.mul);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Color(0x99FFF19B), // ← 노란색 배경
        borderRadius: BorderRadius.circular(999),
        // border: Border.all(color:Color(0xFFFFFF)), // 테두리도 살짝 강조
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nightlight_outlined, size: 16, color: Colors.black),
          const SizedBox(width: 6),
          Text(
            mul,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black, // 글씨는 검정색
            ),
          ),
        ],
      ),
    );
  }
}

class TidePage extends StatefulWidget {
  const TidePage({super.key});
  @override
  State<TidePage> createState() => _TidePageState();
}

class _Coord {
  final double lat;
  final double lon;
  const _Coord(this.lat, this.lon);
}

class _TidePageState extends State<TidePage> {
  BadaTimeApi? api; // ← nullable
  List<TideDay> days = [];
  DateTime selectedDate = DateTime.now();
  bool loading = true;
  String? error;

  static const _seoulLat = 37.5665;
  static const _seoulLon = 126.9780;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<_Coord> _resolveCurrentOrSeoul() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return const _Coord(_seoulLat, _seoulLon);

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return const _Coord(_seoulLat, _seoulLon);
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      final lat = pos.latitude;
      final lon = pos.longitude;
      if (lat.isNaN || lon.isNaN) return const _Coord(_seoulLat, _seoulLon);
      return _Coord(lat, lon);
    } catch (_) {
      return const _Coord(_seoulLat, _seoulLon);
    }
  }

  Future<void> _init() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final coord = await _resolveCurrentOrSeoul();
      api = await BadaTimeApi.fromEnv(
        lat: coord.lat,
        lon: coord.lon,
      );
      await _load();
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _load() async {
    if (api == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final parsed = await api!.fetch7Days();
      if (parsed.isEmpty) throw Exception('결과 없음');
      parsed.sort((a, b) => a.date.compareTo(b.date));
      setState(() {
        days = parsed;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  TideDay? get _selectedDay {
    final idx = days.indexWhere((e) => DateUtils.isSameDay(e.date, selectedDate));
    return idx == -1 ? null : days[idx];
  }

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

  Future<int?> _showWheelPicker({
    required String titleSuffix,
    required List<int> values,
    required int currentValue,
  }) async {
    int selVal = currentValue;
    final ctrl = FixedExtentScrollController(
      initialItem: values.indexOf(currentValue).clamp(0, values.length - 1).toInt(),
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
                      child: Text(
                        '$selVal$titleSuffix',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                    TextButton(onPressed: () => Navigator.pop(ctx, selVal), child: const Text('완료')),
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
  int _safeDay(int y, int m, int d) => (d.clamp(1, _lastDayOfMonth(y, m)) as int);

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final minY = days.isNotEmpty ? days.first.date.year - 10 : now.year - 10;
    final maxY = days.isNotEmpty ? days.last.date.year + 10 : now.year + 10;
    final years = [for (int y = minY; y <= maxY; y++) y];

    final picked = await _showWheelPicker(titleSuffix: '년', values: years, currentValue: selectedDate.year);
    if (picked == null) return;

    final y = picked, m = selectedDate.month, d = _safeDay(y, m, selectedDate.day);
    setState(() => selectedDate = DateTime(y, m, d));
  }

  Future<void> _pickMonth() async {
    final months = [for (int m = 1; m <= 12; m++) m];
    final picked = await _showWheelPicker(titleSuffix: '월', values: months, currentValue: selectedDate.month);
    if (picked == null) return;

    final y = selectedDate.year, m = picked, d = _safeDay(y, m, selectedDate.day);
    setState(() => selectedDate = DateTime(y, m, d));
  }

  Future<void> _pickDay() async {
    final y = selectedDate.year, m = selectedDate.month;
    final daysVals = [for (int d = 1; d <= _lastDayOfMonth(y, m); d++) d];
    final picked = await _showWheelPicker(titleSuffix: '일', values: daysVals, currentValue: selectedDate.day);
    if (picked == null) return;
    setState(() => selectedDate = DateTime(y, m, picked));
  }

  Future<void> _openCalendar() async {
    if (days.isEmpty) return;
    final first = days.first.date;
    final last = days.last.date;

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
              if (safeInitial.isAfter(last)) safeInitial = last;

              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: canGoPrev
                              ? () => setSheetState(
                                  () => displayedMonth = DateTime(displayedMonth.year, displayedMonth.month - 1))
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const SizedBox(width: 6),
                        Text('${displayedMonth.year}년 ${displayedMonth.month}월',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: canGoNext
                              ? () => setSheetState(
                                  () => displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + 1))
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
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (loading || error != null || days.isEmpty) ? '물때' : (_selectedDay?.regionName ?? '물때');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
          overflow: TextOverflow.ellipsis, // 길면 말줄임
        ),
        centerTitle: true,
        leadingWidth: 80,
        leading: SizedBox(
          width: 100,
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final picked = await showRegionPicker(
                  context,
                  initialName: _selectedDay?.regionName,
                );
                if (picked != null) {
                  api = await BadaTimeApi.fromEnv(lat: picked.lat, lon: picked.lon);
                  await _load();
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 15),
                child: Icon(
                  Icons.location_on_sharp,
                  size: 24,
                  color: Color(0xD2FF3C3C),
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _init,
          ),
        ],
      ),

      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7BB8FF), Color(0xFFA8D3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? _buildError(error!)
              : _buildContent(),
        ),
      ),

      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildError(String msg) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(height: 8),
        Text('불러오기 실패\n$msg', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
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
    final wk = ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1];

    final prevDate = _prevAvailableDate();
    final nextDate = _nextAvailableDate();
    final day = _selectedDay;

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
                onPressed: prevDate == null ? null : () => setState(() => selectedDate = prevDate!),
                icon: const Icon(Icons.chevron_left, color: Colors.white),
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
                onPressed: nextDate == null ? null : () => setState(() => selectedDate = nextDate!),
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 메인 카드 (Aq 스타일)
          AqCard(
            // title/subtitle 직접 Row로 감싸서 칩과 같이 배치
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '물때 정보',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '$y년 $m월 $d일 ${wk}요일',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (day != null) _MulChip(day.mul),
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                if (day == null) ...[
                  const SizedBox(height: 8),
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        '물때 정보가 없습니다.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: _sunMoonBox(
                          icon: Icons.wb_sunny_outlined,
                          title: '일출',
                          subtitle: '일몰',
                          first: _fmt24(day.sunrise),
                          second: _fmt24(day.sunset),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _sunMoonBox(
                          icon: Icons.nights_stay_outlined,
                          title: '월출',
                          subtitle: '월몰',
                          first: _fmt24(day.moonrise),
                          second: _fmt24(day.moonset),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 섹션 헤더
                  Row(
                    children: const [
                      Icon(Icons.waves, size: 18),
                      SizedBox(width: 6),
                      Text('간만조시각', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 미니 타일들 (Aq 타일 톤)
                  GridView.builder(
                    itemCount: day.events.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent:140,
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 2),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00509F))),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 16, color: Color(0xFF1E40AF)),
        ],
      ),
    ),
  );

  // 타일(작은 카드) 공통
  Widget _miniTileBox(BuildContext context, Widget child) {
    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.tileBorder),
        boxShadow: th.tileShadows,
      ),
      child: child,
    );
  }

  Widget _sunMoonBox({
    required IconData icon,
    required String title,
    required String subtitle,
    required String first,
    required String second,
  }) =>
      _miniTileBox(
        context,
        Row(
          children: [
            Builder(
              builder: (context) {
                final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
                return Icon(icon, color: th.titleStyle.color);
              },
            ),
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

  Widget _kv(String k, String v) => Builder(
    builder: (context) {
      final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: th.labelStyle),
          Text(v, style: th.metricStyle),
        ],
      );
    },
  );
  Widget _tideCard(TideEvent e) {
    final isHigh = e.type == '만조';
    final arrowColor = isHigh ? const Color(0xFFE53935) : const Color(0xFF1E88E5);

    return _miniTileBox(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 첫 줄: 라벨(좌) + 증감(우)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${e.type} ${_orderNumber(e.label)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (e.delta != null && e.delta!.toString().isNotEmpty)
              // 변화량 (▲ / ▼, 색상 변경)
                if (e.delta != null && e.delta!.toString().isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Icon(
                    e.delta! > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      size: 28,
                      color: e.delta! > 0 ? Colors.red : Colors.blue,
                    ),


                        const SizedBox(width: 2),
                        Text(
                          e.delta! > 0 ? '+${e.delta}' : '${e.delta}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: e.delta! > 0 ? Colors.red : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),

            ],
          ),
          const SizedBox(height: 6),

          // 시각 (좌측)
          Builder(
            builder: (context) {
              final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
              return Text(
                _fmt24(e.hhmm),
                style: th.metricStyle.copyWith(fontSize: 22),
              );
            },
          ),
          const SizedBox(height: 6),

          // 수위 cm (좌측)
          Text(
            '${e.heightCm.toStringAsFixed(1)}cm',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  String _orderNumber(String label) => RegExp(r'(\d+)').firstMatch(label)?.group(1) ?? '';

  String _fmt24(String hhmm) {
    final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(hhmm);
    if (m == null) return hhmm;
    final h = int.tryParse(m.group(1)!) ?? 0;
    final mi = int.tryParse(m.group(2)!) ?? 0;
    final hh = h.clamp(0, 23).toString().padLeft(2, '0');
    final mm = mi.clamp(0, 59).toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
