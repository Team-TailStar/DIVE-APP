// lib/pages/sea_weather/sea_weather_page.dart

import 'dart:convert';
import 'dart:isolate';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_bottom_nav.dart';
import '../../env.dart';
import '../../wear_bridge.dart';
import 'package:dive_app/pages/ui/aq_theme.dart';
import 'package:dive_app/pages/ui/aq_widget.dart';

import 'region_picker.dart' as rp;

// ─────────────────────────────── 앱 컬러 ───────────────────────────────
// 앱 컬러
const _appBlue = Color(0xFF7BB8FF);
const _appBlueLight = Color(0xFFA8D3FF);
const _appAccent = Color(0xFFFF4151);

// 날짜/시간 텍스트에 사용할 살짝 파란 톤
const _dateHeaderBlue = Color(0xFF2F6FED); // 좀 더 진하게: 0xFFD7EBFF


// ─────────────────────────────── 공통: 메모리 캐시 & JSON Isolate ───────────────────────────────

class _MemCacheItem {
  final DateTime at;
  final String body;
  _MemCacheItem(this.at, this.body);
}

final Map<String, _MemCacheItem> _memCache = {};
const _cacheTtl = Duration(minutes: 10);

String _bucketKey(String base, double lat, double lon) {
  double r(double v) => double.parse(v.toStringAsFixed(2)); // 약 1km 버킷
  return '$base:${r(lat)},${r(lon)}';
}

Future<dynamic> _decodeJsonIsolate(String s) async {
  return await Isolate.run(() => json.decode(s));
}

// ─────────────────────────────── PAGE ───────────────────────────────

class SeaWeatherPage extends StatefulWidget {
  const SeaWeatherPage({super.key});

  @override
  State<SeaWeatherPage> createState() => _SeaWeatherPageState();
}

class _SeaWeatherPageState extends State<SeaWeatherPage> {
  String tab = '파도';
  rp.RegionItem? _region;

  static const _seoulLat = 37.5665;
  static const _seoulLon = 126.9780;

  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _pickRegion() async {
    final picked = await rp.showRegionPicker(
      context,
      initialName: _region?.name,
    );
    if (picked != null && mounted) {
      setState(() => _region = picked);
      _saveCachedRegion(picked);
    }
  }

  Future<void> _init() async {
    // 1) 캐시 즉시 적용해서 첫 페인트 가속
    final cached = await _loadCachedRegion();
    if (mounted && cached != null) {
      setState(() => _region = cached);
    }

    // 2) 실제 위치는 백그라운드에서 업데이트
    final picked = await _resolveCurrentOrSeoul();
    if (!mounted) return;
    setState(() => _region = picked);
    _saveCachedRegion(picked);
  }

  // ── 파일 캐시(JSON) 구현
  Future<File> _regionFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/region_cache.json');
  }

  Future<rp.RegionItem?> _loadCachedRegion() async {
    try {
      final file = await _regionFile();
      if (!await file.exists()) return null;
      final data = json.decode(await file.readAsString());
      final name = data['name'] as String?;
      final lat = (data['lat'] as num?)?.toDouble();
      final lon = (data['lon'] as num?)?.toDouble();
      if (name == null || lat == null || lon == null) return null;
      return rp.RegionItem(name, lat, lon);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveCachedRegion(rp.RegionItem item) async {
    try {
      final file = await _regionFile();
      final data = {'name': item.name, 'lat': item.lat, 'lon': item.lon};
      await file.writeAsString(json.encode(data));
    } catch (_) {
      // 캐시 실패는 무시
    }
  }

  void _forceReload() {
    setState(() => _refreshTick++);
  }

  Future<rp.RegionItem> _resolveCurrentOrSeoul() async {
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) return rp.RegionItem('서울', _seoulLat, _seoulLon);

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return rp.RegionItem('서울', _seoulLat, _seoulLon);
      }

      // 빠른 경로: 마지막 위치 → 없으면 짧은 타임아웃 현재 위치
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 4),
      );

      final lat = pos.latitude, lon = pos.longitude;
      if (lat.isNaN || lon.isNaN) {
        return rp.RegionItem('서울', _seoulLat, _seoulLon);
      }

      // 역지오코딩은 느릴 수 있으니 이름은 나중에 갱신
      final provisional = rp.RegionItem('현재 위치', lat, lon);
      _reverseRegionName(lat, lon).then((name) {
        if (!mounted) return;
        if (_region?.lat == lat && _region?.lon == lon && _region?.name != name) {
          setState(() => _region = rp.RegionItem(name, lat, lon));
          _saveCachedRegion(_region!);
        }
      });

      return provisional;
    } catch (_) {
      return rp.RegionItem('서울', _seoulLat, _seoulLon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bool loadingRegion = (_region == null);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _appBlue,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        surfaceTintColor: Colors.transparent,
        title: Text(
          loadingRegion ? '내 위치 불러오는 중…' : _region!.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leading: SizedBox(
          width: 100,
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pickRegion,
              child: const Padding(
                padding: EdgeInsets.only(left: 15),
                child: Icon(Icons.location_on_sharp, size: 24, color: _appAccent),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _forceReload,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_appBlue, _appBlueLight],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          // ⬇⬇ 여백 더 붙이기(좌우 10 / 상단 6 / 하단 16)
          padding: EdgeInsets.fromLTRB(10, topPad + kToolbarHeight + 6, 10, 16),
          children: [
            Row(
              children: [
                _GlassChip(
                  label: '파도',
                  selected: tab == '파도',
                  onTap: () => setState(() => tab = '파도'),
                ),
                const SizedBox(width: 8),
                _GlassChip(
                  label: '수온',
                  selected: tab == '수온',
                  onTap: () => setState(() => tab = '수온'),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 12),

            if (loadingRegion)
              const AqCard(
                child: SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (tab == '파도')
              _WaveSectionApi(
                key: ValueKey('wave-${_region!.lat},${_region!.lon}#$_refreshTick'),
                lat: _region!.lat,
                lon: _region!.lon,
              )
            else
              _TempSection(
                key: ValueKey('temp-${_region!.lat},${_region!.lon}#$_refreshTick'),
                lat: _region!.lat,
                lon: _region!.lon,
                regionLabel: _region!.name,
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

// ─────────────────────────────── 파도 섹션 (시간표 UI) ───────────────────────────────

class _WaveSectionApi extends StatefulWidget {
  const _WaveSectionApi({super.key, required this.lat, required this.lon});
  final double lat;
  final double lon;

  @override
  State<_WaveSectionApi> createState() => _WaveSectionApiState();
}

class _WaveSectionApiState extends State<_WaveSectionApi> {
  bool loading = true;
  bool _showAll = false;
  String? error;
  List<SeaWave> waves = [];
  bool _sentToWatch = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant _WaveSectionApi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lon != widget.lon) {
      setState(() {
        loading = true;
        error = null;
        waves = [];
        _sentToWatch = false;
      });
      _fetch();
    }
  }

  Future<void> _fetch() async {
    try {
      final key = _bucketKey('forecast', widget.lat, widget.lon);
      String rawBody;

      // 1) 메모리 캐시
      final cached = _memCache[key];
      if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
        rawBody = cached.body;
      } else {
        final uri = Uri.parse(
          '${Env.API_BASE_URL}/forecast?lat=${widget.lat}&lon=${widget.lon}&key=${Env.BADA_SERVICE_KEY}',
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 6));
        if (res.statusCode != 200) {
          throw Exception('HTTP ${res.statusCode}');
        }
        rawBody = utf8.decode(res.bodyBytes);
        _memCache[key] = _MemCacheItem(DateTime.now(), rawBody);
      }

      // 2) JSON 파싱을 Isolate에서
      final dynamic body = await _decodeJsonIsolate(rawBody);

      List raw;
      if (body is List) {
        raw = body;
      } else if (body is Map<String, dynamic>) {
        raw = (body['forecast'] ?? body['data'] ?? body['items'] ?? body['list'] ?? []) as List;
      } else {
        raw = const [];
      }

      // 3) 초기 렌더는 72시간 내로 제한 (없으면 전체 사용)
      final now = DateTime.now();
      final parsedAll = raw.map((e) => SeaWave.fromJson(e as Map<String, dynamic>));
      final parsed = parsedAll
          .where((w) =>
      w.time.isAfter(now.subtract(const Duration(hours: 1))) &&
          w.time.isBefore(now.add(const Duration(hours: 72))))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      setState(() {
        waves = parsed.isNotEmpty ? parsed : (parsedAll.toList()..sort((a, b) => a.time.compareTo(b.time)));
        loading = false;
      });

      _sendOnceToWatchIfPossible();
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _sendOnceToWatchIfPossible() async {
    if (_sentToWatch || waves.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todays = waves
        .where((w) =>
    w.time.year == today.year &&
        w.time.month == today.month &&
        w.time.day == today.day)
        .toList();

    final basis = todays.isNotEmpty
        ? todays
        : (() {
      final nearest = waves.reduce((a, b) =>
      (a.time.difference(now).abs() < b.time.difference(now).abs()) ? a : b);
      final d = DateTime(nearest.time.year, nearest.time.month, nearest.time.day);
      return waves
          .where((w) => w.time.year == d.year && w.time.month == d.month && w.time.day == d.day)
          .toList();
    })();

    if (basis.isEmpty) return;

    final avgHt = basis.map((e) => e.waveHt).reduce((a, b) => a + b) / basis.length;
    final dir = _modeOrLast(basis.map((e) => e.waveDir).toList());
    final obs = basis.last.time;

    try {
      await WearBridge.sendWeather({
        "windspd": "",
        "winddir": dir,
        "waveHt": avgHt.toStringAsFixed(1),
        "obs_wt": _fmtDate(obs),
      });
      _sentToWatch = true;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AqCard(
        child: SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (error != null) {
      return const AqCard(
        padding: EdgeInsets.all(16),
        child: Text('불러오기 실패'),
      );
    }
    if (waves.isEmpty) {
      return const AqCard(
        padding: EdgeInsets.all(16),
        child: Text('데이터가 없습니다.'),
      );
    }

    // 상단: 날짜만 (앱 톤에 맞춘 굵은 화이트)
    final now = DateTime.now();
    final dateStr = _formatKDate(now);
    final timeStr = DateFormat('HH:mm').format(now);

    // 가장 가까운 다음 시간 계산 (하이라이트 용)
    SeaWave? nearestFuture;
    final futures = waves.where((w) => !w.time.isBefore(now)).toList();
    if (futures.isNotEmpty) {
      futures.sort((a, b) => a.time.difference(now).abs().compareTo(b.time.difference(now).abs()));
      nearestFuture = futures.first;
    }

    final grouped = _groupByDateHours(
      waves,
      days: _showAll ? 60 : 3,
      highlightTime: nearestFuture?.time,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 앱 색감: 화이트 텍스트, 작은 그림자
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                 color: _dateHeaderBlue,
                  letterSpacing: 0.2,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                 color: _dateHeaderBlue,
                  fontFeatures: [FontFeature.tabularFigures()],
                  shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                ),
              ),
            ],
          ),
        ),

        // 파란 라운드 카드(outer) + 하얀 표(inner)
        _HourlyBlock(groups: grouped),

        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              foregroundColor: Colors.white,
            ),
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(_showAll ? '접기' : '더보기'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── 수온 섹션 ───────────────────────────────

class _TempSection extends StatefulWidget {
  const _TempSection({
    super.key,
    required this.lat,
    required this.lon,
    required this.regionLabel,
  });
  final double lat;
  final double lon;
  final String regionLabel;

  @override
  State<_TempSection> createState() => _TempSectionState();
}

class _TempSectionState extends State<_TempSection> {
  bool loading = true;
  String? error;
  List<SeaStationTemp> stations = [];
  bool _sentToWatch = false;

  String? _selectedStationName;

  @override
  void initState() {
    super.initState();
    _fetchTemp();
  }

  @override
  void didUpdateWidget(covariant _TempSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lon != widget.lon) {
      setState(() {
        loading = true;
        error = null;
        stations = [];
        _sentToWatch = false;
        _selectedStationName = null;
      });
      _fetchTemp();
    }
  }

  Future<void> _fetchTemp() async {
    try {
      final key = _bucketKey('temp', widget.lat, widget.lon);
      String rawBody;

      final cached = _memCache[key];
      if (cached != null && DateTime.now().difference(cached.at) < _cacheTtl) {
        rawBody = cached.body;
      } else {
        final uri = Uri.parse(
          '${Env.API_BASE_URL}/temp?lat=${widget.lat}&lon=${widget.lon}&key=${Env.BADA_SERVICE_KEY}',
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 6));
        if (res.statusCode != 200) {
          throw Exception('HTTP ${res.statusCode}');
        }
        rawBody = utf8.decode(res.bodyBytes);
        _memCache[key] = _MemCacheItem(DateTime.now(), rawBody);
      }

      final dynamic body = await _decodeJsonIsolate(rawBody);

      final list = (body is List) ? body : (body['data'] ?? body['items'] ?? []) as List;

      final parsed = list
          .map((e) => SeaStationTemp.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));

      setState(() {
        stations = parsed;
        loading = false;
        if (_selectedStationName == null || !parsed.any((s) => s.name == _selectedStationName)) {
          _selectedStationName = parsed.isNotEmpty ? parsed.first.name : null;
        }
      });

      _sendOnceToWatchIfPossible();
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _sendOnceToWatchIfPossible() async {
    if (_sentToWatch || stations.isEmpty) return;

    try {
      final payload = stations.take(8).map((s) {
        return {
          "name": s.name,
          "temp": s.tempC.toStringAsFixed(1),
          "obs_time": s.obsTime.toIso8601String(),
          "distance_km": s.distanceKm?.toStringAsFixed(1) ?? ""
        };
      }).toList();

      await WearBridge.sendTempStations(payload);
      _sentToWatch = true;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final timeStr = DateFormat('HH:mm').format(now);

    if (loading) {
      return const AqCard(
        child: SizedBox(
          height: 140,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (error != null) {
      return const AqCard(
        padding: EdgeInsets.all(16),
        child: Text('불러오기 실패'),
      );
    }
    if (stations.isEmpty) {
      return const AqCard(
        padding: EdgeInsets.all(16),
        child: Text('수온 데이터가 없습니다.'),
      );
    }

    stations.firstWhere(
          (s) => s.name == _selectedStationName,
      orElse: () => stations.first,
    );

    DateTime latestObs =
    stations.map((s) => s.obsTime).reduce((a, b) => a.isAfter(b) ? a : b);
    final String lastUpdateTextBottom = '최근 업데이트 : ${_fmtDate(latestObs)}';

    final visibleStations = stations.take(20).toList();
    final stationCount = visibleStations.length;
    final avgTemp =
        visibleStations.map((s) => s.tempC).reduce((a, b) => a + b) / stationCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatKDate(today),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,

                   color: _dateHeaderBlue,
                  letterSpacing: 0.2,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,

                  color: _dateHeaderBlue,
                  fontFeatures: [FontFeature.tabularFigures()],
                  shadows: [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        AqCard(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.regionLabel} 근처 바다 수온'),
              const SizedBox(height: 2),
              Text(
                '인근 관측소 $stationCount개  평균 수온 ${avgTemp.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  color: _appAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.0,
                ),
              ),
            ],
          ),
          child: Builder(
            builder: (context) {
              final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: th.tileBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: th.tileBorder),
                    ),
                    child: const _CompareHeaderWhite(),
                  ),
                  const SizedBox(height: 2),
                  ...visibleStations.map(
                        (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _CompareRowWhite(
                        place: e.name,
                        trendUp: true,
                        temp: '${e.tempC.toStringAsFixed(1)}°C',
                        dist: e.distanceKm == null
                            ? '-'
                            : '${e.distanceKm!.toStringAsFixed(1)}㎞',
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          lastUpdateTextBottom,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── 파도 시간표 컴포넌트 ───────────────────────────────

class _HourlyBlock extends StatelessWidget {
  final List<_HourlyDayGroup> groups;
  const _HourlyBlock({required this.groups});

  @override
  Widget build(BuildContext context) {
    // 각 날짜 세트를 파란 라운드 카드로 분리
    return Column(
      children: groups.map((g) => _WaveHourlyDay(group: g)).toList(),
    );
  }
}

class _WaveHourlyDay extends StatefulWidget {
  final _HourlyDayGroup group;
  const _WaveHourlyDay({required this.group});

  @override
  State<_WaveHourlyDay> createState() => _WaveHourlyDayState();
}

class _WaveHourlyDayState extends State<_WaveHourlyDay> {
  bool _collapsed = false;

  bool get _isToday {
    final now = DateTime.now();
    final d = widget.group.dateKey;
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static const double _timeColW = 60;
  static const double _headerH = 28;
  static const double _rowH = 34; // 살짝 더 촘촘하게

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
    final headerStyle = th.labelStyle;
    final valueStyle = th.metricStyle;

    return Container(
      // ⬇⬇ 파란 카드 여백 더 붙이기
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: _appBlue.withOpacity(0.28),          // 바깥 파란 카드
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.35), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Column(
        children: [
          // 날짜 / 접기
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            child: Row(
              children: [
            Expanded(
               child: Row(
                children: [
                  Text(
                   widget.group.dateLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
              color: Colors.white,
                          fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
        if (_isToday)
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,                  // ← 배경 투명
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white , width: 1.2), // ← 빨간 보더
      ),
      child: Text(
        '오늘',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: _appAccent,                        // ← 텍스트 빨강
        ),
      ),
    ),
        ],
    ),
     ),
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 28),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => setState(() => _collapsed = !_collapsed),
                  child: Text(_collapsed ? '펼치기' : '접기'),
                ),
              ],
            ),
          ),

          if (_collapsed) const SizedBox.shrink() else
          // 하얀 카드(표) 꽉 차 보이기: margin/padding 제거, clip 적용
            Container(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.zero,
                //border: Border.all(color: th.cardBorder.withOpacity(0.35), width: 0.8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽 시간 컬럼
                  Container(
                    width: _timeColW,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: th.cardBorder.withOpacity(0.25), width: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: _headerH, child: Center(child: Text('시간', style: headerStyle))),
    ...widget.group.rows.map(
      (e) => Container(
           height: _rowH,
        color: e.highlight ? const Color(0xFFFFF3F5) : Colors.transparent, // ← highlight
           child: Center(
              child: Text(
                e.timeLabel,
              style: valueStyle.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                textAlign: TextAlign.center,
              ),
             ),
         ),
       ),
    ],
    ),
    ),

                  // 우측 값 테이블
                  Expanded(
                    child: Table(
                      border: TableBorder.symmetric(
                        outside: BorderSide.none,
                        inside: BorderSide(color: th.cardBorder.withOpacity(0.25), width: 0.5),
                      ),
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(3),
                        2: FlexColumnWidth(3),
                        3: FlexColumnWidth(3),
                        4: FlexColumnWidth(3),
                      },
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      children: [
                        // 헤더 행
                        TableRow(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(color: th.cardBorder.withOpacity(0.35), width: 0.6),
                            ),
                          ),
                          children: [
                            _headerCell('날씨', headerStyle, _headerH),
                            _headerCell('파주기', headerStyle, _headerH),
                            _headerCell('파고', headerStyle, _headerH),
                            _headerCell('파향', headerStyle, _headerH),
                            _headerCell('풍속', headerStyle, _headerH),
                          ],
                        ),
                        // 데이터 행
                        ...widget.group.rows.map((e) {
                          final rowBg = e.highlight ? const Color(0xFFFFF3F5) : Colors.white;
                          return TableRow(
                            decoration: BoxDecoration(color: rowBg),
                            children: [
                              _weatherCell(e.skyLabel, e.skycode, _rowH),
                              _bodyCell(e.period, valueStyle, _rowH),
                              _bodyCell(e.height, valueStyle, _rowH),
                              _bodyCell(e.dir, valueStyle, _rowH),
                              _bodyCell(e.wind, valueStyle, _rowH),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // 패딩 없이 중앙 정렬만
  Widget _headerCell(String text, TextStyle style, double h) => SizedBox(
    height: h,
    child: Center(child: Text(text, style: style, textAlign: TextAlign.center)),
  );

  Widget _bodyCell(String text, TextStyle style, double h) => SizedBox(
    height: h,
    child: Center(child: Text(text, style: style, textAlign: TextAlign.center)),
  );

  Widget _weatherCell(String sky, String skycode, double h) {
    final icon = _skyIcon(sky, skycode);
    return SizedBox(
      height: h,
      child: Center(child: Icon(icon, size: 18, color: Colors.black87)),
    );
  }
}

IconData _skyIcon(String sky, String code) {
  final s = sky.toLowerCase();
  final c = code.toLowerCase();
  bool hasAny(List<String> keys) => keys.any((k) => s.contains(k) || c.contains(k));

  if (hasAny(['thunder', '번개'])) return Icons.bolt;
  if (hasAny(['snow', '눈'])) return Icons.ac_unit;
  if (hasAny(['rain', '비'])) return Icons.umbrella;
  if (hasAny(['wind', '바람'])) return Icons.air;
  if (hasAny(['cloud', '구름'])) return Icons.cloud_queue;
  return Icons.wb_sunny; // 맑음 기본
}

class _HourlyRowData {
  final String timeLabel; // 01:00
  final String skyLabel; // 원시 스카이 문자열(아이콘 판별용)
  final String skycode; // 코드(아이콘 판별 보조)
  final String period; // 4.3 s
  final String height; // 0.3 m
  final String dir; // 남남동
  final String wind; // 3.2 m/s
  final bool highlight; // 가장 가까운 다음 시간
  const _HourlyRowData({
    required this.timeLabel,
    required this.skyLabel,
    required this.skycode,
    required this.period,
    required this.height,
    required this.dir,
    required this.wind,
    required this.highlight,
  });
}

class _HourlyDayGroup {
  final String dateLabel;
  final DateTime dateKey; // 오늘 판별/정렬용
  final List<_HourlyRowData> rows;
  const _HourlyDayGroup(this.dateLabel, this.dateKey, this.rows);
}

List<_HourlyDayGroup> _groupByDateHours(
    List<SeaWave> waves, {
      int days = 3,
      DateTime? highlightTime,
    }) {
  final byDay = <DateTime, List<SeaWave>>{};
  for (final w in waves) {
    final d = _kDateOnly(w.time);
    byDay.putIfAbsent(d, () => []).add(w);
  }
  final keys = byDay.keys.toList()..sort();
  final target = days >= keys.length ? keys : keys.take(days).toList();

  String kDateLabel(DateTime d) =>
      '${d.month}.${d.day} (${['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1]})';

  String sec(double v) => '${v.toStringAsFixed(1)} s';
  String meter(double v) => '${v.toStringAsFixed(1)} m';
  String wind(double v) => '${v.toStringAsFixed(1)} m/s';

  return target.map((d) {
    final list = (byDay[d]!..sort((a, b) => a.time.compareTo(b.time)));
    final rows = list.map((w) {
      final hh = w.time.hour.toString().padLeft(2, '0');
      final isHL = (highlightTime != null &&
          w.time.year == highlightTime.year &&
          w.time.month == highlightTime.month &&
          w.time.day == highlightTime.day &&
          w.time.hour == highlightTime.hour);
      return _HourlyRowData(
        timeLabel: '$hh:00',
        skyLabel: w.sky,
        skycode: w.skycode,
        period: sec(w.wavePrd),
        height: meter(w.waveHt),
        dir: korDir(w.waveDir),
        wind: wind(w.windSpd),
        highlight: isHL,
      );
    }).toList();
    return _HourlyDayGroup(kDateLabel(d), d, rows);
  }).toList();
}

// ─────────────────────────────── 표 헤더/행 (수온 카드용) ───────────────────────────────

class _CompareHeaderWhite extends StatelessWidget {
  const _CompareHeaderWhite();

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontWeight: FontWeight.w800, color: Colors.black87);
    const cell = TextStyle(color: Colors.black87);

    return Row(
      children: const [
        Expanded(flex: 4, child: Text('위치', style: head, overflow: TextOverflow.ellipsis)),
        Expanded(flex: 3, child: Text('변화', textAlign: TextAlign.left, style: cell)),
        Expanded(flex: 4, child: Text('수온', textAlign: TextAlign.center, style: cell)),
        Expanded(flex: 4, child: Text('거리', textAlign: TextAlign.center, style: cell)),
      ],
    );
  }
}

class _CompareRowWhite extends StatelessWidget {
  final String place;
  final bool trendUp;
  final String temp;
  final String dist;

  const _CompareRowWhite({
    required this.place,
    required this.trendUp,
    required this.temp,
    required this.dist,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              place,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Icon(
                trendUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 28,
                color: trendUp ? Colors.redAccent : Colors.blueAccent,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: Text(
                temp,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: Text(
                dist,
                style: const TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── 공통 위젯/유틸 ───────────────────────────────

class _GlassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GlassChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(selected ? 0.9 : 0.4),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderWhite extends StatelessWidget {
  final String text;
  const _HeaderWhite(this.text);
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
    return Text(text, style: th.labelStyle);
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  const _IconCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: th.tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.tileBorder),
      ),
      child: Center(child: Icon(icon, size: 34, color: th.titleStyle.color)),
    );
  }
}

class _PillWhite extends StatelessWidget {
  final String text;
  const _PillWhite({required this.text});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: th.tileBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.tileBorder),
      ),
      child: Center(child: Text(text, style: th.metricStyle)),
    );
  }
}

// 유틸
Future<String> _reverseRegionName(double lat, double lon) async {
  try {
    final list = await geo.placemarkFromCoordinates(lat, lon, localeIdentifier: 'ko_KR');
    if (list.isEmpty) return '현재 위치';
    final p = list.first;
    final siDo = (p.administrativeArea ?? '').trim();
    final siGunGu = (p.locality ?? p.subAdministrativeArea ?? '').trim();
    if (siDo.isNotEmpty && siGunGu.isNotEmpty) return '$siDo $siGunGu';
    if (siDo.isNotEmpty) return siDo;
    if (siGunGu.isNotEmpty) return siGunGu;
    final dong = (p.subLocality ?? p.thoroughfare ?? '').trim();
    if (dong.isNotEmpty) return dong;
    return '현재 위치';
  } catch (_) {
    return '현재 위치';
  }
}

DateTime _kDateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String _formatKDate(DateTime dt) {
  const wd = ['월', '화', '수', '목', '금', '토', '일'];
  final w = wd[dt.weekday - 1];
  return '${dt.year}.${dt.month}.${dt.day} ($w)';
}

String _fmtDate(DateTime dt) {
  final ap = dt.hour < 12 ? 'A.M.' : 'P.M.';
  final hh = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
  return '${dt.year}.${dt.month}.${dt.day} $hh:00 $ap';
}

String korDir(String dir) {
  const m = {
    'N': '북',
    'NNE': '북북동',
    'NE': '북동',
    'ENE': '동북동',
    'E': '동',
    'ESE': '동남동',
    'SE': '남동',
    'SSE': '남남동',
    'S': '남',
    'SSW': '남남서',
    'SW': '남서',
    'WSW': '서남서',
    'W': '서',
    'WNW': '서북서',
    'NW': '북서',
    'NNW': '북북서',
  };
  return m[dir.toUpperCase()] ?? dir;
}



String _modeOrLast(List<String> vals) {
  if (vals.isEmpty) return '-';
  final freq = <String, int>{};
  for (final v in vals) {
    freq[v] = (freq[v] ?? 0) + 1;
  }
  final best = freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return best;
}

// ─────────────────────────────── 모델 ───────────────────────────────

class SeaWave {
  final DateTime time;
  final double wavePrd;
  final double waveHt;
  final String waveDir;

  // 시간표용 추가 필드
  final String sky;
  final String skycode;
  final double windSpd;
  final String windDir;

  SeaWave({
    required this.time,
    required this.wavePrd,
    required this.waveHt,
    required this.waveDir,
    this.sky = '',
    this.skycode = '',
    this.windSpd = 0,
    this.windDir = '',
  });

  static String _norm(String k) {
    final letters = RegExp(r'[A-Za-z]');
    return k.split('').where((c) => letters.hasMatch(c)).join().toLowerCase();
  }

  static T? _pick<T>(Map<String, dynamic> j, List<String> cands) {
    for (final cand in cands) {
      final hit =
      j.keys.firstWhere((k) => _norm(k) == cand.toLowerCase(), orElse: () => '');
      if (hit.isNotEmpty) return j[hit] as T?;
    }
    return null;
  }

  static double _toDouble(dynamic v, {double def = 0}) {
    if (v == null) return def;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? def;
  }

  factory SeaWave.fromJson(Map<String, dynamic> j) {
    String? t = (j['ymdt'] ?? j['time'] ?? j['date'])?.toString();
    late DateTime dt;
    DateTime fromYmd(String s) => DateTime(
      int.parse(s.substring(0, 4)),
      int.parse(s.substring(4, 6)),
      int.parse(s.substring(6, 8)),
    );
    DateTime fromYmdH(String s) => DateTime(
      int.parse(s.substring(0, 4)),
      int.parse(s.substring(4, 6)),
      int.parse(s.substring(6, 8)),
      int.parse(s.substring(8, 10)),
    );

    if (t != null && RegExp(r'^\d{10}$').hasMatch(t)) {
      dt = fromYmdH(t);
    } else if (t != null && RegExp(r'^\d{8}$').hasMatch(t)) {
      dt = fromYmd(t);
    } else if (t != null && t.isNotEmpty) {
      t = t.replaceAll('/', '-').replaceFirst(' ', 'T');
      dt = DateTime.tryParse(t) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }

    final prd = _toDouble(_pick(j, ['waveprd', 'prd', 'period']));
    final ht = _toDouble(_pick(j, ['waveht', 'height']));
    final dir = (_pick<String>(j, ['wavedir', 'dir']) ?? '').toString().toUpperCase();

    final sky = (_pick<String>(j, ['sky']) ?? '').toString();
    final skycode = (_pick(j, ['skycode']) ?? '').toString();
    final windSpd = _toDouble(_pick(j, ['windspd']));
    final windDir = (_pick<String>(j, ['winddir']) ?? '').toString().toUpperCase();

    return SeaWave(
      time: dt,
      wavePrd: prd,
      waveHt: ht,
      waveDir: dir.isEmpty ? '-' : dir,
      sky: sky,
      skycode: skycode,
      windSpd: windSpd,
      windDir: windDir,
    );
  }
}

class SeaStationTemp {
  final String name;
  final DateTime obsTime;
  final double tempC;
  final double? distanceKm;
  final double? lat;
  final double? lon;

  SeaStationTemp({
    required this.name,
    required this.obsTime,
    required this.tempC,
    this.distanceKm,
    this.lat,
    this.lon,
  });

  static String _norm(String k) {
    final r = RegExp(r'[A-Za-z_]');
    return k.split('').where((c) => r.hasMatch(c)).join().toLowerCase();
  }

  static T? _pick<T>(Map<String, dynamic> j, List<String> cands) {
    for (final c in cands) {
      final hit =
      j.keys.firstWhere((k) => _norm(k) == c.toLowerCase(), orElse: () => '');
      if (hit.isNotEmpty) return j[hit] as T?;
    }
    return null;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  factory SeaStationTemp.fromJson(Map<String, dynamic> j) {
    final name = (j['obs_name'] ?? j['name'] ?? '관측소').toString();

    final t = (j['obs_time'] ?? j['time'] ?? '').toString();
    final obsTime = DateTime.tryParse(t.replaceFirst(' ', 'T')) ?? DateTime.now();

    final rawTemp = _pick(j, [
      'obs_wt',
      'sst',
      'sea_temperature',
      'seatemperature',
      'water_temp',
      'watertemp',
      'temp_c',
      'temp',
    ]);
    final tempC = _toDouble(rawTemp);

    final dt = (j['obs_dt'] ?? j['distance'] ?? '').toString();
    final distanceKm = double.tryParse(dt.replaceAll('km', '').replaceAll('㎞', '').trim());

    final latVal = _pick<dynamic>(j, ['lat', 'latitude', 'lat_dd', 'y']);
    final lonVal = _pick<dynamic>(j, ['lon', 'longitude', 'lon_dd', 'x']);

    final lat = _toDoubleOrNull(latVal);
    final lon = _toDoubleOrNull(lonVal);

    return SeaStationTemp(
      name: name,
      obsTime: obsTime,
      tempC: tempC,
      distanceKm: distanceKm,
      lat: lat,
      lon: lon,
    );
  }
}

class SeaTempPoint {
  final DateTime time;
  final double tempC;

  SeaTempPoint({required this.time, required this.tempC});

  static String _norm(String k) {
    final r = RegExp(r'[A-Za-z_]');
    return k.split('').where((c) => r.hasMatch(c)).join().toLowerCase();
  }

  static T? _pick<T>(Map<String, dynamic> j, List<String> cands) {
    for (final c in cands) {
      final hit =
      j.keys.firstWhere((k) => _norm(k) == c.toLowerCase(), orElse: () => '');
      if (hit.isNotEmpty) return j[hit] as T?;
    }
    return null;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory SeaTempPoint.fromJson(Map<String, dynamic> j) {
    String? t = (j['obs_time'] ?? j['time'] ?? j['ymdt'] ?? j['date'])?.toString();
    DateTime parseTime(String s) {
      if (RegExp(r'^\d{10}$').hasMatch(s)) {
        return DateTime(int.parse(s.substring(0, 4)), int.parse(s.substring(4, 6)),
            int.parse(s.substring(6, 8)), int.parse(s.substring(8, 10)));
      }
      if (RegExp(r'^\d{8}$').hasMatch(s)) {
        return DateTime(int.parse(s.substring(0, 4)), int.parse(s.substring(4, 6)),
            int.parse(s.substring(6, 8)));
      }
      return DateTime.tryParse(s.replaceAll('/', '-').replaceFirst(' ', 'T')) ?? DateTime.now();
    }
    final dt = t == null || t.isEmpty ? DateTime.now() : parseTime(t);

    final rawTemp = _pick(j, [
      'obs_wt',
      'sst',
      'sea_temperature',
      'seatemperature',
      'water_temp',
      'watertemp',
      'temp_c',
      'temp'
    ]);
    return SeaTempPoint(time: dt, tempC: _toDouble(rawTemp));
  }
}
