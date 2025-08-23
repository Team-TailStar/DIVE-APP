// lib/pages/tide/tide_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../app_bottom_nav.dart';
import 'tide_models.dart';
import 'tide_services.dart';
import 'package:dive_app/pages/ui/aq_theme.dart';
import 'package:dive_app/pages/ui/aq_widget.dart';

// ▼ 낚시 포인트(가까운 지점 계산에 사용)
import '../fishing_point/fishing_point_region.dart';

// ─────────────────────────────── 빠른 위치 캐시 ───────────────────────────────
class _FastLocCache {
  static DateTime? at;
  static _Coord? coord;

  static bool get isFresh {
    if (at == null || coord == null) return false;
    return DateTime.now().difference(at!) < const Duration(minutes: 3);
  }
}

class _Coord {
  final double lat;
  final double lon;
  const _Coord(this.lat, this.lon);
}

class _LocException implements Exception {
  final String code;   // SERVICE_OFF | PERM_DENIED | PERM_FOREVER | NO_POSITION
  final String message;
  const _LocException(this.code, this.message);
}

/// 물때 칩(물때명 표시)
class _MulChip extends StatelessWidget {
  final String mul;
  const _MulChip(this.mul);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x99FFF19B),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nightlight_outlined, size: 16, color: Colors.black),
          const SizedBox(width: 6),
          Text(mul, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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

class _TidePageState extends State<TidePage> {
  BadaTimeApi? api;
  List<TideDay> days = [];
  DateTime selectedDate = DateTime.now();
  bool loading = true;

  String? error;          // 사용자에게 보여줄 에러 메시지
  String? _errorCode;     // SERVICE_OFF / PERM_DENIED / PERM_FOREVER / NO_POSITION / OTHER

  // 내 위치 + 선택 지점 상태
  double? _myLat;
  double? _myLon;
  SeaSpot? _selectedSpot;
  SeaSpot? _nearestSpot;

  @override
  void initState() {
    super.initState();
    _init();
  }

  // ──────────────────────── 내 위치만 사용(서울 fallback 없음) ────────────────────────
  Future<_Coord> _resolveCurrentStrict() async {
    // 캐시가 신선하면 즉시
    if (_FastLocCache.isFresh && _FastLocCache.coord != null) {
      return _FastLocCache.coord!;
    }

    // 위치 서비스 체크
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      throw const _LocException('SERVICE_OFF', '위치 서비스가 꺼져 있어요.');
    }

    // 권한 체크/요청
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const _LocException('PERM_DENIED', '위치 권한이 필요해요.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw const _LocException('PERM_FOREVER', '앱의 위치 권한이 영구히 거부되었어요.');
    }

    // 1) lastKnown: 거의 즉시
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      final quick = _Coord(lastKnown.latitude, lastKnown.longitude);
      if (_validCoord(quick)) {
        _FastLocCache.coord = quick;
        _FastLocCache.at = DateTime.now();
        return quick;
      }
    }

    // 2) 현재 위치(짧은 타임아웃) + 스트림 백업 (구버전 시그니처 호환)
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 3),
      );
    }  on TimeoutException {
  // 구버전 호환: 매개변수 없이 기본 스트림 사용
  final stream = Geolocator.getPositionStream();
  pos = await stream.first.timeout(const Duration(seconds: 2));
}


final coord = _Coord(pos.latitude, pos.longitude);
    if (_validCoord(coord)) {
      _FastLocCache.coord = coord;
      _FastLocCache.at = DateTime.now();
      return coord;
    }

    throw const _LocException('NO_POSITION', '현재 위치를 가져오지 못했어요.');
  }

  bool _validCoord(_Coord c) {
    if (c.lat.isNaN || c.lon.isNaN) return false;
    if (c.lat == 0.0 && c.lon == 0.0) return false;
    if (c.lat.abs() > 90 || c.lon.abs() > 180) return false;
    return true;
  }

  Future<void> _init() async {
    setState(() {
      loading = true;
      error = null;
      _errorCode = null;
    });

    try {
      // 내 위치만 사용해서 초기화
      final quick = await _resolveCurrentStrict();
      _myLat = quick.lat;
      _myLon = quick.lon;

      // 가까운 지점 계산
      _nearestSpot = _findNearestSpot(_myLat!, _myLon!);

      final baseLat = _selectedSpot?.lat ?? _nearestSpot?.lat ?? _myLat!;
      final baseLon = _selectedSpot?.lon ?? _nearestSpot?.lon ?? _myLon!;

      api = await BadaTimeApi.fromEnv(lat: baseLat, lon: baseLon);
      await _load(); // 먼저 보여주기

      // 정밀 위치로 의미 있는 변화(>1km)면 부드럽게 갱신
      _refreshPreciseIfBetter();
    } on _LocException catch (e) {
      setState(() {
        error = e.message;
        _errorCode = e.code;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        _errorCode = 'OTHER';
        loading = false;
      });
    }
  }

  // 정밀 업데이트: 1km 이상 차이나면만 리로드
  Future<void> _refreshPreciseIfBetter() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      final precise = _Coord(pos.latitude, pos.longitude);
      if (!_validCoord(precise)) return;

      final prev = _Coord(_myLat ?? precise.lat, _myLon ?? precise.lon);
      final distKm = _haversineKm(prev.lat, prev.lon, precise.lat, precise.lon);
      if (distKm < 1.0) return;

      _FastLocCache.coord = precise;
      _FastLocCache.at = DateTime.now();

      final near = _findNearestSpot(precise.lat, precise.lon);
      final lat = _selectedSpot?.lat ?? near?.lat ?? precise.lat;
      final lon = _selectedSpot?.lon ?? near?.lon ?? precise.lon;

      final newApi = await BadaTimeApi.fromEnv(lat: lat, lon: lon);
      final parsed = await newApi.fetch7Days()..sort((a, b) => a.date.compareTo(b.date));

      if (!mounted) return;
      setState(() {
        _myLat = precise.lat;
        _myLon = precise.lon;
        _nearestSpot = near;
        api = newApi;
        days = parsed;
      });
    } catch (_) {
      // 조용히 무시(정밀 실패)
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
      setState(() => days = parsed);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
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
                      child: Text('$selVal$titleSuffix',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
  int _safeDay(int y, int m, int d) => d.clamp(1, _lastDayOfMonth(y, m));

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

  /// 새 페이지로 이동하여 7일 요약 표시
  void _openWeekPage() {
    if (days.isEmpty) return;

    final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final end = start.add(const Duration(days: 6));

    final week = days.where((d) {
      final dd = DateTime(d.date.year, d.date.month, d.date.day);
      return (dd.isAtSameMomentAs(start) || dd.isAfter(start)) &&
          (dd.isAtSameMomentAs(end) || dd.isBefore(end));
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TideWeekPage(
        week: week,
        regionName: _selectedDay?.regionName ?? '물때',
      ),
    ));
  }

  // =========================
  // = 지역 선택 Top Sheet UI =
  // =========================

  void _openRegionTopSheet() async {
    final selected = await showGeneralDialog<SeaSpot>(
      context: context,
      barrierLabel: '지역 선택',
      barrierDismissible: true,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        final media = MediaQuery.of(context);
        final topMargin = media.padding.top + kToolbarHeight + 8;

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: EdgeInsets.fromLTRB(16, topMargin, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                constraints: BoxConstraints(
                  maxWidth: 640,
                  maxHeight: media.size.height * 0.65,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _RegionSelectorBody(
                  initialSelected: _selectedSpot ?? _nearestSpot,
                  nearestSpot: _nearestSpot,
                  onSubmit: (spot) => Navigator.of(context).pop(spot),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, sec, child) {
        final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero).animate(a),
          child: FadeTransition(opacity: a, child: child),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedSpot = selected;
        _nearestSpot = null;
      });
      if (selected.lat != null && selected.lon != null) {
        api = await BadaTimeApi.fromEnv(lat: selected.lat!, lon: selected.lon!);
        await _load();
      }
    }
  }

  SeaSpot? _findNearestSpot(double lat, double lon) {
    SeaSpot? best;
    var bestDist = double.infinity;
    for (final s in kWestSeaSpots) {
      final slat = s.lat;
      final slon = s.lon;
      if (slat == null || slon == null) continue;
      final d = _haversineKm(lat, lon, slat, slon);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

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
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        leadingWidth: 80,
        leading: SizedBox(
          width: 100,
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _openRegionTopSheet,
              child: const Padding(
                padding: EdgeInsets.only(left: 15),
                child: Icon(Icons.location_on_sharp, size: 24, color: Color(0xD2FF3C3C)),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(tooltip: '새로고침', icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _init),
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
        const Icon(Icons.location_off, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        if (_errorCode == 'SERVICE_OFF')
          FilledButton(
            onPressed: () async {
              await Geolocator.openLocationSettings();
            },
            child: const Text('위치 설정 열기'),
          ),
        if (_errorCode == 'PERM_DENIED')
          FilledButton(
            onPressed: () async {
              await Geolocator.requestPermission();
              _init();
            },
            child: const Text('위치 권한 요청'),
          ),
        if (_errorCode == 'PERM_FOREVER')
          FilledButton(
            onPressed: () async {
              await Geolocator.openAppSettings();
            },
            child: const Text('앱 권한 설정 열기'),
          ),
        if (_errorCode == 'NO_POSITION' || _errorCode == 'OTHER')
          FilledButton(
            onPressed: _init,
            child: const Text('다시 시도'),
          ),
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
                onPressed: prevDate == null ? null : () => setState(() => selectedDate = prevDate),
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
                        // 달력 아이콘 → 새 페이지로 이동
                        IconButton(
                          onPressed: _openWeekPage,
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
                icon: const Icon(Icons.chevron_right, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 메인 카드
          AqCard(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('물때 정보', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text('$y년 $m월 $d일 $wk요일', style: const TextStyle(fontSize: 13, color: Colors.grey)),
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
                      child: Text('물때 정보가 없습니다.', textAlign: TextAlign.center),
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
                  Row(
                    children: const [
                      Icon(Icons.waves, size: 18),
                      SizedBox(width: 6),
                      Text('간만조시각', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    itemCount: day.events.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 140,
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
    return _miniTileBox(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${e.type} ${_orderNumber(e.label)}', style: const TextStyle(fontWeight: FontWeight.w600)),
              if (e.delta != null && e.delta!.toString().isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(e.delta! > 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        size: 28, color: e.delta! > 0 ? Colors.red : Colors.blue),
                    const SizedBox(width: 2),
                    Text(
                      e.delta! > 0 ? '+${e.delta}' : '${e.delta}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: e.delta! > 0 ? Colors.red : Colors.blue),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Builder(
            builder: (context) {
              final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
              return Text(_fmt24(e.hhmm), style: th.metricStyle.copyWith(fontSize: 22));
            },
          ),
          const SizedBox(height: 6),
          Text('${e.heightCm.toStringAsFixed(1)}cm', style: const TextStyle(fontWeight: FontWeight.w700)),
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

/// =========================
/// =  새 페이지: TideWeek  =
/// =========================
class TideWeekPage extends StatelessWidget {
  final List<TideDay> week;
  final String regionName;
  const TideWeekPage({super.key, required this.week, required this.regionName});

  String _fmt24(String hhmm) {
    final m = RegExp(r'^\s*(\d{1,2}):(\d{2})\s*$').firstMatch(hhmm);
    if (m == null) return hhmm;
    final h = int.tryParse(m.group(1)!) ?? 0;
    final mi = int.tryParse(m.group(2)!) ?? 0;
    final hh = h.clamp(0, 23).toString().padLeft(2, '0');
    final mm = mi.clamp(0, 59).toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // 최대 2개까지만 표기 + 심플 심볼 접두사
  Widget _pairText(List<TideEvent> list, {required String symbol}) {
    if (list.isEmpty) {
      return const Text('-', style: TextStyle(color: Colors.grey));
    }
    final children = <Widget>[];
    for (var i = 0; i < list.length && i < 2; i++) {
      final e = list[i];
      children.add(
        Text(
          '$symbol ${_fmt24(e.hhmm)} (${e.heightCm.toStringAsFixed(0)})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = [...week]..sort((a, b) => a.date.compareTo(b.date));
    const hdrBg = Color(0xFFEDEFF2);
    const gridBorder = Color(0xFFDEE3EA);

    return Scaffold(
      appBar: AppBar(
        title: Text('일주일 물때 • $regionName'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          children: [
            // 헤더(회색 바)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: hdrBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: gridBorder),
              ),
              child: Row(
                children: const [
                  Expanded(flex: 23, child: Text('날짜', style: TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(flex: 22, child: Text('물때/월령', style: TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(flex: 28, child: Text('만조 ↑', style: TextStyle(fontWeight: FontWeight.w700))),
                  Expanded(flex: 27, child: Text('간조 ↓', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 리스트
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final d = items[i];
                  final wd = ['월','화','수','목','금','토','일'][d.date.weekday-1];
                  final dateLabel = '${d.date.month}.${d.date.day} ($wd)';

                  final highs = d.events.where((e) => e.type == '만조').toList();
                  final lows  = d.events.where((e) => e.type == '간조').toList();

                  return Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: gridBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 23, child: Text(dateLabel, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 22, child: Text(d.mul, style: const TextStyle(fontWeight: FontWeight.w600))),
                        Expanded(flex: 28, child: _pairText(highs, symbol: '↑')),
                        Expanded(flex: 27, child: _pairText(lows, symbol: '↓')),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================
// = 공용: 리스트 다이얼로그/필드 =
// ===============================
Future<T?> _showListDialog<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required String Function(T) labelOf,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              Center(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              const SizedBox(height: 6),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final v = items[i];
                    return ListTile(
                      title: Text(labelOf(v)),
                      onTap: () => Navigator.of(ctx).pop(v),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE9ECF1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      valueText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================
// = Top Sheet 내부 본문 위젯 =
// ============================
class _RegionSelectorBody extends StatefulWidget {
  const _RegionSelectorBody({
    required this.onSubmit,
    this.initialSelected,
    this.nearestSpot,
  });

  final ValueChanged<SeaSpot> onSubmit;
  final SeaSpot? initialSelected;
  final SeaSpot? nearestSpot;

  @override
  State<_RegionSelectorBody> createState() => _RegionSelectorBodyState();
}

class _RegionSelectorBodyState extends State<_RegionSelectorBody> {
  late final List<SeaSpot> _all;
  late final List<String> _regions;

  late String _region;      // 현재 표시 지역(시/도)
  late List<SeaSpot> _names; // 현재 지역의 지점 목록
  SeaSpot? _nameSel;        // 현재 선택 지점

  @override
  void initState() {
    super.initState();
    _all = kWestSeaSpots.where((s) => s.lat != null && s.lon != null).toList();
    _regions = {for (final s in _all) s.region.trim()}.toList()..sort();

    final init = widget.initialSelected ?? widget.nearestSpot;
    if (init != null) {
      _region  = init.region;
      _names   = _namesSource(_region);
      _nameSel = init;
    } else {
      _region  = (_regions.isNotEmpty ? _regions.first : '');
      _names   = _namesSource(_region);
      _nameSel = (_names.isNotEmpty ? _names.first : null);
    }
  }

  List<SeaSpot> _namesSource(String r) =>
      _all.where((s) => s.region == r).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  Future<void> _openRegionPicker() async {
    final picked = await _showListDialog<String>(
      context: context,
      title: '지역 (시/도)',
      items: _regions,
      labelOf: (e) => e,
    );
    if (picked != null) {
      setState(() {
        _region  = picked;
        _names   = _namesSource(_region);
        _nameSel = (_names.isNotEmpty ? _names.first : null);
      });
    }
  }

  Future<void> _openNamePicker() async {
    final picked = await _showListDialog<SeaSpot>(
      context: context,
      title: '지점',
      items: _names,
      labelOf: (e) => e.name,
    );
    if (picked != null) {
      setState(() => _nameSel = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54, height: 5, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
          ),
          const Text('지역 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _PickerField(label: '지역 (시/도)', valueText: _region.isEmpty ? '선택' : _region, onTap: _openRegionPicker),
          const SizedBox(height: 12),
          _PickerField(label: '지점', valueText: _nameSel?.name ?? '선택', onTap: _openNamePicker),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _nameSel == null ? null : () => widget.onSubmit(_nameSel!),
              child: const Text('적용'),
            ),
          ),
        ],
      ),
    );
  }
}
