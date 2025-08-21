// lib/pages/sea_weather/sea_weather_page.dart
import 'package:flutter/material.dart';
import '../../app_bottom_nav.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../wear_bridge.dart';
import '../../env.dart';
import 'region_picker.dart' as rp;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:flutter/services.dart';
import 'package:dive_app/pages/ui/aq_theme.dart';
import 'package:dive_app/pages/ui/aq_widget.dart';
import 'dart:math' as math;


class SeaWeatherPage extends StatefulWidget {
  const SeaWeatherPage({super.key});

  @override
  State<SeaWeatherPage> createState() => _SeaWeatherPageState();
}

class _SeaWeatherPageState extends State<SeaWeatherPage> {
  String tab = '파도';
  rp.RegionItem _region = rp.RegionItem('서울', _seoulLat, _seoulLon);

  static const _seoulLat = 37.5665;
  static const _seoulLon = 126.9780;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final picked = await _resolveCurrentOrSeoul();
    if (!mounted) return;
    setState(() => _region = picked);
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 6),
      );

      final lat = pos.latitude, lon = pos.longitude;
      if (lat.isNaN || lon.isNaN) return rp.RegionItem('서울', _seoulLat, _seoulLon);

      final name = await _reverseRegionName(lat, lon);
      return rp.RegionItem(name, lat, lon);
    } catch (_) {
      return rp.RegionItem('서울', _seoulLat, _seoulLon);
    }
  }


  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Color(0xFF7BB8FF),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _region.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leadingWidth: 80,
        leading: SizedBox(
          width: 100,
          child: Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final picked = await rp.showRegionPicker(
                  context,
                  initialName: _region.name,
                );
                if (picked != null && mounted) {
                  setState(() => _region = picked); // 타입 동일해졌음
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(left: 15),
                child: Icon(Icons.location_on_sharp, size: 24, color: Color(
                    0xFFFF4151)),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '현재 위치로 새로고침',
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
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topPad + kToolbarHeight + 8, 16, 24),
          children: [
            // 탭(파도/수온) — WeatherPage 톤에 맞춘 반투명 칩
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
              ],
            ),
            const SizedBox(height: 14),

            // 본문 섹션들 — 전부 반투명 박스(WeatherPage 스타일)
            if (tab == '파도')
              _WaveSectionApi(
                key: ValueKey('wave-${_region.lat},${_region.lon}'),
                lat: _region.lat,
                lon: _region.lon,
              )
            else
              _TempSection(
                key: ValueKey('temp-${_region.lat},${_region.lon}'),
                lat: _region.lat,
                lon: _region.lon,
              ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

// ─────────────────────────────── 파도 섹션 ───────────────────────────────

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
      final uri = Uri.parse(
        '${Env.API_BASE_URL}/forecast?lat=${widget.lat}&lon=${widget.lon}&key=${Env.BADA_SERVICE_KEY}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final decoded = utf8.decode(res.bodyBytes);
      final body = json.decode(decoded);

      List raw;
      if (body is List) {
        raw = body;
      } else if (body is Map<String, dynamic>) {
        raw = (body['forecast'] ?? body['data'] ?? body['items'] ?? body['list'] ?? []) as List;
      } else {
        raw = const [];
      }

      final parsed = raw
          .map((e) => SeaWave.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));

      setState(() {
        waves = parsed;
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

    final todays = waves.where((w) =>
    w.time.year == today.year &&
        w.time.month == today.month &&
        w.time.day == today.day).toList();

    final basis = todays.isNotEmpty
        ? todays
        : (() {
      final nearest = waves.reduce((a, b) =>
      (a.time.difference(now).abs() < b.time.difference(now).abs()) ? a : b);
      final d = DateTime(nearest.time.year, nearest.time.month, nearest.time.day);
      return waves.where((w) =>
      w.time.year == d.year && w.time.month == d.month && w.time.day == d.day).toList();
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todays = waves.where((w) =>
    w.time.year == today.year &&
        w.time.month == today.month &&
        w.time.day == today.day).toList();

    final basis = todays.isNotEmpty
        ? todays
        : (() {
      final nearest = waves.reduce((a, b) =>
      (a.time.difference(now).abs() < b.time.difference(now).abs()) ? a : b);
      final d = DateTime(nearest.time.year, nearest.time.month, nearest.time.day);
      return waves.where((w) =>
      w.time.year == d.year && w.time.month == d.month && w.time.day == d.day).toList();
    })();

    final String topPeriod = _rangeText(basis.map((e) => e.wavePrd).toList(), unit: 's');
    final String topHeight = _avgText(basis.map((e) => e.waveHt).toList(), unit: 'm');
    final String topDir = korDir(_modeOrLast(basis.map((e) => e.waveDir).toList()));

    final tomorrow = today.add(const Duration(days: 1));
    final afterTomorrow = waves.where((w) => !w.time.isBefore(tomorrow)).toList();

    final grouped = _groupByDateAmPm(afterTomorrow, days: _showAll ? 60 : 3);
    final rows = grouped.expand((g) => g.items).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(

          child: Text(
            _formatKDate(today),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 상단 요약 3열 — 반투명 박스 + 화이트 텍스트
        AqCard(
          child: Column(
            children: [
              Row(
                children: const [
                  Expanded(child: Center(child: _HeaderWhite('파주기'))),
                  Expanded(child: Center(child: _HeaderWhite('파고'))),
                  Expanded(child: Center(child: _HeaderWhite('파향'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Expanded(child: _IconCircle(icon: Icons.ssid_chart)),
                  SizedBox(width: 10),
                  Expanded(child: _IconCircle(icon: Icons.tsunami)),
                  SizedBox(width: 10),
                  Expanded(child: _IconCircle(icon: Icons.explore)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _PillWhite(text: topPeriod)),
                  const SizedBox(width: 10),
                  Expanded(child: _PillWhite(text: topHeight)),
                  const SizedBox(width: 10),
                  Expanded(child: _PillWhite(text: topDir)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 리스트 헤더
        const Text('파도 예측',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 10),

        // 예측 표 — WeatherPage 스타일의 반투명 카드 묶음
        _ForecastBlock(rows: rows),

        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(
              _showAll ? '접기' : '더보기',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────── 수온 섹션 ───────────────────────────────

class _TempSection extends StatefulWidget {
  const _TempSection({super.key, required this.lat, required this.lon});
  final double lat;
  final double lon;

  @override
  State<_TempSection> createState() => _TempSectionState();
}

class _TempSectionState extends State<_TempSection> {
  String mode = '그래프';
  bool loading = true;
  String? error;
  List<SeaStationTemp> stations = [];
  bool _sentToWatch = false;

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
      });
      _fetchTemp();
    }
  }

  Future<void> _fetchTemp() async {
    try {
      final uri = Uri.parse(
        '${Env.API_BASE_URL}/temp?lat=${widget.lat}&lon=${widget.lon}&key=${Env.BADA_SERVICE_KEY}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final body = json.decode(utf8.decode(res.bodyBytes));
      final list = (body is List) ? body : (body['data'] ?? body['items'] ?? []) as List;

      final parsed = list
          .map((e) => SeaStationTemp.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));

      setState(() {
        stations = parsed;
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

    final current = stations.first;
    final String currentTempText = '${current.tempC.toStringAsFixed(1)}°C';
    final String lastUpdateText = '최근 업데이트 : ${_fmtDate(current.obsTime)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(

          child: Text(
            _formatKDate(today),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 상단 현재 수온 카드(반투명)
        AqCard(
          title: const Text('현재 수온'),
          subtitle: _formatKDate(today),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 행 (관측소명 + 수온)
              Builder(builder: (context) {
                final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),

                  decoration: BoxDecoration(
                    color: th.tileBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: th.tileBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text('${current.name}\n현재 수온 :', style: th.labelStyle.copyWith(height: 1.2))),
                      Text(currentTempText, style: th.metricStyle.copyWith(fontSize: 18)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),

              // 그래프 박스
              Builder(builder: (context) {
                final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
                return SizedBox(
                  height: 140,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: th.tileBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: th.tileBorder),
                    ),
                    child: const _MiniLineChart(gridColor: Color(0x332E5BFF),lineColor: Color(0xFF2E5BFF),),
                  ),

                );
              }),

              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(lastUpdateText),
              ),
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => TempComparePage(lat: widget.lat, lon: widget.lon)),
                  ),
                  child: const Text(
                    '인근 바다와 수온 비교해보기',
                    style: TextStyle(decoration: TextDecoration.underline),

                  ),
                ),
              ),
            ],
          ),
        ),


        const SizedBox(height: 16),
        const Text('주변 관측소 수온',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 10),

        // 그래프/표 토글 칩
        Row(
          children: [
            _GlassChip(
              label: '그래프',
              selected: mode == '그래프',
              onTap: () => setState(() => mode = '그래프'),
            ),
            const SizedBox(width: 8),
            _GlassChip(
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
            child: Builder(builder: (context) {
              final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: th.tileBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: th.tileBorder),
                  boxShadow: th.tileShadows,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: _MiniLineChart(secondary: true,gridColor: Color(0x332E5BFF),
                    lineColor: Color(0xFF2E5BFF),       // 메인(파랑)
                    secondaryLineColor: Color(0xFF00BFA5),), // 보조(민트)),
                ),
              );
            }),
          )
        else

          Builder(builder: (context) {
            // 수온 요약 계산
            final minStation = stations.reduce((a, b) => a.tempC <= b.tempC ? a : b);
            final maxStation = stations.reduce((a, b) => a.tempC >= b.tempC ? a : b);
            final avgTemp = stations.map((s) => s.tempC).reduce((a, b) => a + b) / stations.length;

            return AqCard(
              title: const Text('수온 요약'),
              subtitle: _formatKDate(today),
              child: AqMetricGrid(
                tiles: [
                  AqMetricTile(
                    label: '최저 수온',
                    unit: '°C',
                    metricText: minStation.tempC.toStringAsFixed(1),
                    footnote: minStation.name, // 최저 관측소
                  ),
                  AqMetricTile(
                    label: '최고 수온',
                    unit: '°C',
                    metricText: maxStation.tempC.toStringAsFixed(1),
                    footnote: maxStation.name, // 최고 관측소
                  ),
                  AqMetricTile(
                    label: '평균 수온',
                    unit: '°C',
                    metricText: avgTemp.toStringAsFixed(1),
                    footnote: '관측소 ${stations.length}개',

                  ),
                ],
              ),
            );
          }),

      ],
    );
  }
}


// ─────────────────────────────── 공통(WeatherPage 톤) 위젯 ───────────────────────────────

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
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  const _GlassBox({required this.child, this.padding, this.height});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: child,
    );
    if (height != null) {
      return SizedBox(height: height, child: box);
    }
    return box;
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

// ───────────────────── 파도 예측: Aq 테마 버전 ─────────────────────

class _ForecastBlock extends StatelessWidget {
  final List<_ForecastRowData> rows;
  const _ForecastBlock({required this.rows});

  @override
  Widget build(BuildContext context) {

    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();

    return AqCard(
      // title: const Text('파도 예측'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [


          const SizedBox(height: 10),
          ..._buildGrouped(rows),
        ],

      ),
    );
  }

  List<Widget> _buildGrouped(List<_ForecastRowData> rows) {
    final List<Widget> cards = [];
    String? currentDate;
    List<_ForecastRowData> bucket = [];

    void flush() {
      if (bucket.isEmpty) return;
      cards.add(_WaveDayTile(date: currentDate!, items: List.of(bucket)));
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
}

class _WaveDayTile extends StatelessWidget {
  final String date;
  final List<_ForecastRowData> items;
  const _WaveDayTile({required this.date, required this.items});

  static const double _amColW  = 56;   // 오전/오후 칩 칼럼 폭
  static const double _headerH = 32;   // 표 헤더 높이
  static const double _rowH    = 40;   // 표 한 행 높이

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
    final dateStyle   = th.titleStyle;
    final headerStyle = th.labelStyle;
    final valueStyle  = th.metricStyle;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Text(date, style: dateStyle.copyWith(fontWeight: FontWeight.w800)),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: th.tileBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: th.tileBorder),
            boxShadow: th.tileShadows,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⬇️ 왼쪽 칩 컬럼만 이렇게 변경
              SizedBox(
                width: _amColW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: _headerH), // 헤더 높이만큼 위로 띄움
                    ...items.map((e) => SizedBox(
                      height: _rowH,                 // 각 데이터 행 높이
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _AqAmPmChip(
                          text: e.amPm,
                          isAm: e.amPm == '오전',
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // 오른쪽 표(이전 버전 유지)
              Expanded(
                child: Table(
                  border: TableBorder(
                    top: BorderSide(color: Colors.transparent, width: 0),
                    bottom: BorderSide(color: Colors.transparent, width: 0),
                    left: BorderSide(color: Colors.transparent, width: 0),
                    right: BorderSide(color: Colors.transparent, width: 0),
                    verticalInside: BorderSide(color: Colors.transparent, width: 0),
                    horizontalInside: BorderSide(
                      color: th.cardBorder.withOpacity(0.9),
                      width: 1,

                    ),
                  ),
                  columnWidths: const {
                    0: FlexColumnWidth(5),
                    1: FlexColumnWidth(3),
                    2: FlexColumnWidth(4),
                  },
                  children: [
                    TableRow(children: [
                      _headerCell('파주기', headerStyle, _headerH),
                      _headerCell('파고', headerStyle, _headerH),
                      _headerCell('파향', headerStyle, _headerH),
                    ]),
                    ...items.map((e) => TableRow(children: [
                      _bodyCell(e.period, valueStyle, _rowH),
                      _bodyCell(e.height, valueStyle, _rowH),
                      _bodyCell(e.dir, valueStyle, _rowH),
                    ])),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerCell(String text, TextStyle style, double h) =>
      SizedBox(height: h, child: Center(child: Text(text, style: style)));
  Widget _bodyCell(String text, TextStyle style, double h) =>
      SizedBox(
        height: h,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Align(
            alignment: Alignment.center,
            child: Text(text, style: style),
          ),
        ),
      );

}


class _HeaderThemed extends StatelessWidget {
  final String text;
  const _HeaderThemed(this.text);
  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
    return Text(text, style: th.labelStyle);
  }
}

class _AqAmPmChip extends StatelessWidget {
  final String text;
  final bool isAm;
  const _AqAmPmChip({required this.text, required this.isAm});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: th.chipBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: th.cardBorder),
      ),
      child: Text(text, style: th.metricStyle),
    );
  }
}


// 표 헤더/행(화이트 톤)
class _CompareHeaderWhite extends StatelessWidget {
  const _CompareHeaderWhite();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 5, child: Text('위치', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white))),
        Expanded(flex: 3, child: Text('변화', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))),
        Expanded(flex: 4, child: Text('수온', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))),
        Expanded(flex: 3, child: Text('거리', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))),
        Expanded(flex: 3, child: Text('이동', textAlign: TextAlign.center, style: TextStyle(color: Colors.white))),
      ],
    );
  }
}

class _CompareRowWhite extends StatelessWidget {
  final String place;
  final bool trendUp;
  final String temp;
  final String dist;


  const _CompareRowWhite({required this.place, required this.trendUp, required this.temp, required this.dist});


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(place, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white))),
          Expanded(
            flex: 3,
            child: Center(
              child: Icon(
                trendUp ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  temp,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
          Expanded(flex: 3, child: Center(child: Text(dist, style: const TextStyle(color: Colors.white)))),
          Expanded(
            flex: 3,
            child: Center(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(

                  side: BorderSide(color: Colors.white.withOpacity(0.8)),
                  foregroundColor: Colors.white,
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
}


// ─────────────────────────────── 유틸/모델/그래프(기존 유지) ───────────────────────────────

class _ForecastRowData {
  final String date;
  final String amPm;
  final String period;
  final String height;
  final String dir;
  const _ForecastRowData({required this.date, required this.amPm, required this.period, required this.height, required this.dir});

}

class _MiniLineChart extends StatelessWidget {
  final bool secondary;
  final Color gridColor;
  final Color lineColor;
  final Color? secondaryLineColor;

  const _MiniLineChart({
    this.secondary = false,
    this.gridColor = const Color(0x338EA6FF), // 연한 파랑(그리드)
    this.lineColor = const Color(0xFF2E5BFF), // 선: 진한 파랑
    this.secondaryLineColor,                   // 2번째 선(옵션)
  });


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
        final double h = constraints.maxHeight.isFinite ? constraints.maxHeight : 150.0;
        return CustomPaint(

          size: Size(w, h),
          painter: _MiniLinePainter(
            secondary: secondary,
            gridColor: gridColor,
            lineColor: lineColor,
            secondaryLineColor: secondaryLineColor,
          ),
        );

      },
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final bool secondary;

  final Color gridColor;
  final Color lineColor;
  final Color? secondaryLineColor;

  _MiniLinePainter({
    required this.secondary,
    required this.gridColor,
    required this.lineColor,
    this.secondaryLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 그리드
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // 메인 선
    final p1 = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path1 = Path();
    for (int i = 0; i <= 20; i++) {
      final wave = (i % 4 < 2 ? 1 - (i % 2) * 0.5 : 0.5);
      final x = size.width * (i / 20);
      final y = size.height * (0.7 - 0.2 * wave);
      if (i == 0) path1.moveTo(x, y); else path1.lineTo(x, y);
    }
    canvas.drawPath(path1, p1);

    // 보조 선(옵션)
    if (secondary) {
      final p2 = Paint()
        ..color = (secondaryLineColor ?? const Color(0xFF00BFA5)) // 민트톤
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

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
  bool shouldRepaint(covariant _MiniLinePainter old) =>
      old.secondary != secondary ||
          old.gridColor != gridColor ||
          old.lineColor != lineColor ||
          old.secondaryLineColor != secondaryLineColor;
}

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

String _rangeText(List<double> vals, {required String unit}) {
  if (vals.isEmpty) return '-';
  vals.sort();
  final min = vals.first, max = vals.last;
  return '${min.toStringAsFixed(1)}–${max.toStringAsFixed(1)} $unit';
}

String _avgText(List<double> vals, {required String unit}) {
  if (vals.isEmpty) return '-';
  final avg = vals.reduce((a, b) => a + b) / vals.length;
  return '${avg.toStringAsFixed(1)} $unit';
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

class _ForecastDayGroup {
  final String dateLabel;
  final List<_ForecastRowData> items;
  _ForecastDayGroup(this.dateLabel, this.items);
}

List<_ForecastDayGroup> _groupByDateAmPm(List<SeaWave> waves, {int days = 3}) {
  final byDay = <DateTime, List<SeaWave>>{};
  for (final w in waves) {
    final d = _kDateOnly(w.time);
    byDay.putIfAbsent(d, () => []).add(w);
  }

  final keys = byDay.keys.toList()..sort();
  final targetKeys = days >= keys.length ? keys : keys.take(days).toList();

  final out = <_ForecastDayGroup>[];
  for (final d in targetKeys) {
    final list = byDay[d]!..sort((a, b) => a.time.compareTo(b.time));
    final am = list.where((w) => w.time.hour < 12).toList();
    final pm = list.where((w) => w.time.hour >= 12).toList();

    String label = '${d.month}.${d.day} (${['월', '화', '수', '목', '금', '토', '일'][d.weekday - 1]})';
    String prd(List<SeaWave> xs) => _rangeText(xs.map((e) => e.wavePrd).toList(), unit: 's');
    String hgt(List<SeaWave> xs) => _avgText(xs.map((e) => e.waveHt).toList(), unit: 'm');
    String dir(List<SeaWave> xs) => xs.isEmpty ? '-' : korDir(_modeOrLast(xs.map((e) => e.waveDir).toList()));

    final items = <_ForecastRowData>[];
    if (am.isNotEmpty) {
      items.add(_ForecastRowData(date: label, amPm: '오전', period: prd(am), height: hgt(am), dir: dir(am)));
    }
    if (pm.isNotEmpty) {
      items.add(_ForecastRowData(date: label, amPm: '오후', period: prd(pm), height: hgt(pm), dir: dir(pm)));
    }
    if (items.isEmpty) continue;
    out.add(_ForecastDayGroup(label, items));
  }
  return out;
}

// 모델들(기존 유지)
class SeaWave {
  final DateTime time;
  final double wavePrd;
  final double waveHt;
  final String waveDir;

  SeaWave({required this.time, required this.wavePrd, required this.waveHt, required this.waveDir});

  static String _norm(String k) {
    final letters = RegExp(r'[A-Za-z]');
    return k.split('').where((c) => letters.hasMatch(c)).join().toLowerCase();
  }

  static T? _pick<T>(Map<String, dynamic> j, List<String> cands) {
    for (final cand in cands) {
      final hit = j.keys.firstWhere((k) => _norm(k) == cand.toLowerCase(), orElse: () => '');
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
    DateTime fromYmd(String s) {
      final y = int.parse(s.substring(0, 4));
      final m = int.parse(s.substring(4, 6));
      final d = int.parse(s.substring(6, 8));
      return DateTime(y, m, d);
    }

    DateTime fromYmdH(String s) {
      final y = int.parse(s.substring(0, 4));
      final m = int.parse(s.substring(4, 6));
      final d = int.parse(s.substring(6, 8));
      final h = int.parse(s.substring(8, 10));
      return DateTime(y, m, d, h);
    }

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
    final ht  = _toDouble(_pick(j, ['waveht', 'height']));
    final dir = (_pick<String>(j, ['wavedir', 'dir']) ?? '').toString().toUpperCase();

    return SeaWave(

      time: dt,
      wavePrd: prd,
      waveHt: ht,
      waveDir: dir.isEmpty ? '-' : dir,
    );

  }
}

class SeaStationTemp {
  final String name;
  final DateTime obsTime;
  final double tempC;
  final double? distanceKm;

  SeaStationTemp({required this.name, required this.obsTime, required this.tempC, this.distanceKm});


  static String _norm(String k) {
    final r = RegExp(r'[A-Za-z_]');
    return k.split('').where((c) => r.hasMatch(c)).join().toLowerCase();
  }

  static T? _pick<T>(Map<String, dynamic> j, List<String> cands) {
    for (final c in cands) {
      final hit = j.keys.firstWhere((k) => _norm(k) == c, orElse: () => '');
      if (hit.isNotEmpty) return j[hit] as T?;
    }
    return null;
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory SeaStationTemp.fromJson(Map<String, dynamic> j) {
    final name = (j['obs_name'] ?? j['name'] ?? '관측소').toString();

    final t = (j['obs_time'] ?? j['time'] ?? '').toString();
    final obsTime = DateTime.tryParse(t.replaceFirst(' ', 'T')) ?? DateTime.now();

    final rawTemp = _pick(j, [

      'obs_wt', 'sst', 'sea_temperature', 'seatemperature', 'water_temp', 'watertemp', 'temp_c', 'temp',

    ]);
    final tempC = _toDouble(rawTemp);

    final dt = (j['obs_dt'] ?? j['distance'] ?? '').toString();
    final distanceKm = double.tryParse(dt.replaceAll('km', '').replaceAll('㎞', '').trim());


    return SeaStationTemp(name: name, obsTime: obsTime, tempC: tempC, distanceKm: distanceKm);

  }
}

// 비교/상세 페이지(배경/톤만 맞춤)
class TempComparePage extends StatefulWidget {
  const TempComparePage({super.key, required this.lat, required this.lon});
  final double lat;
  final double lon;

  @override
  State<TempComparePage> createState() => _TempComparePageState();
}

class _TempComparePageState extends State<TempComparePage> {
  bool loading = true;
  String? error;
  List<SeaStationTemp> stations = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final uri = Uri.parse(
        '${Env.API_BASE_URL}/temp?lat=${widget.lat}&lon=${widget.lon}&key=${Env.BADA_SERVICE_KEY}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = json.decode(utf8.decode(res.bodyBytes));
      final list = (body is List) ? body : (body['data'] ?? body['items'] ?? []) as List;

      final parsed = list
          .map((e) => SeaStationTemp.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => (a.distanceKm ?? 1e9).compareTo(b.distanceKm ?? 1e9));
      setState(() {
        stations = parsed;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Color(0xFF7BB8FF),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('바다 날씨', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7BB8FF), Color(0xFFA8D3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 20, 16, 24),
          children: [
            Center(
              child: Text(
                _formatKDate(DateTime.now()),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            AqCard(
              title: const Text('인근 바다와 수온 비교'),
              subtitle: _formatKDate(DateTime.now()),
              child: Builder(
                builder: (context) {
                  final th = Theme.of(context).extension<AqCardTheme>() ?? AqCardTheme.light();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 표 헤더
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: th.tileBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: th.tileBorder),
                        ),
                        child: const _CompareHeaderWhite(),
                      ),
                      const SizedBox(height: 8),

                      // 로딩/에러/목록
                      if (loading)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (error != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('불러오기 실패: $error'),
                        )
                      else
                        ...stations.take(20).map(
                              (e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: _CompareRowWhite(
                              place: e.name,
                              trendUp: true,
                              temp: '${e.tempC.toStringAsFixed(1)}°C',
                              dist: e.distanceKm == null ? '-' : '${e.distanceKm!.toStringAsFixed(1)}㎞',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),


          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}