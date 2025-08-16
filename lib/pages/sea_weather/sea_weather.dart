import 'package:flutter/material.dart';
import '../../app_bottom_nav.dart';
import '../../routes.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../wear_bridge.dart';
import 'lib/wear_bridge.dart';

class SeaWeatherPage extends StatefulWidget {
  const SeaWeatherPage({super.key});

  @override
  State<SeaWeatherPage> createState() => _SeaWeatherPageState();
}

class _SeaWeatherPageState extends State<SeaWeatherPage> {
  String tab = '파도';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text('바다 날씨', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('경기 북부 앞바다', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, Routes.regionSelect),
                  child: const Text('지역 선택', style: TextStyle(fontSize: 16, color: Colors.black45)),
                ),
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

            if (tab == '파도') const _WaveSectionApi() else const _TempSection(),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _WaveSectionApi extends StatefulWidget {
  const _WaveSectionApi();

  @override
  State<_WaveSectionApi> createState() => _WaveSectionApiState();
}

class _WaveSectionApiState extends State<_WaveSectionApi> {
  bool loading = true;
  bool _showAll = false;
  String? error;
  List<SeaWave> waves = [];

  // ✅ 워치로 중복 전송 방지용
  bool _sentToWatch = false;

  static const String _apiBase = 'https://www.badatime.com/DIVE/forecast';
  static const double _lat = 35.1151;
  static const double _lon = 129.0415;
  static const String _key = 'X2KN516OA5RAUL3GPCEFARGKHHKJQN';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final uri = Uri.parse('$_apiBase?lat=$_lat&lon=$_lon&key=$_key');
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

      // ✅ 데이터 로딩 후 워치로 한 번만 전송
      _sendOnceToWatchIfPossible();

    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  /// ✅ 화면에 표시하는 로직과 동일한 기준으로
  /// 평균 파고/대표 파향/관측시각을 만들어 워치로 1회 전송
  Future<void> _sendOnceToWatchIfPossible() async {
    if (_sentToWatch || waves.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todays = waves.where((w) =>
    w.time.year == today.year &&
        w.time.month == today.month &&
        w.time.day == today.day
    ).toList();

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

    final avgHt = basis.map((e) => e.waveHt).reduce((a,b)=>a+b) / basis.length;
    final dir   = _modeOrLast(basis.map((e)=>e.waveDir).toList());
    final obs   = basis.last.time;

    try {
      await WearBridge.sendWeather({
        "windspd": "",
        "winddir": dir,
        "waveHt": avgHt.toStringAsFixed(1),
        "obs_wt": _fmtDate(obs),
      });
      _sentToWatch = true;
    } catch (_) {
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Text('불러오기 실패: $error', style: const TextStyle(color: Colors.red)),
      );
    }
    if (waves.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Text('데이터가 없습니다.'),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todays = waves.where((w) =>
    w.time.year == today.year &&
        w.time.month == today.month &&
        w.time.day == today.day
    ).toList();

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
    final String topDir    = korDir(_modeOrLast(basis.map((e) => e.waveDir).toList()));

    final tomorrow = today.add(const Duration(days: 1));
    final afterTomorrow = waves.where((w) => !w.time.isBefore(tomorrow)).toList();

    final grouped = _groupByDateAmPm(afterTomorrow, days: _showAll ? 60 : 3);
    final rows = grouped.expand((g) => g.items).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Text(_formatKDate(today), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
        const SizedBox(height: 16),

        _TopThreeCards(period: topPeriod, height: topHeight, dir: topDir),

        const SizedBox(height: 24),
        const Text('파도 예측', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        _ForecastBlock(rows: rows),

        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _showAll = !_showAll),
            child: Text(_showAll ? '접기' : '더보기',
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}


class _TopThreeCards extends StatelessWidget {
  final String period;
  final String height;
  final String dir;
  const _TopThreeCards({required this.period, required this.height, required this.dir});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
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
            children: [
              Expanded(child: _ValuePill(text: period)),
              const SizedBox(width: 10),
              Expanded(child: _ValuePill(text: height)),
              const SizedBox(width: 10),
              Expanded(child: _ValuePill(text: dir)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TempSection extends StatefulWidget {
  const _TempSection();

  @override
  State<_TempSection> createState() => _TempSectionState();
}

class _TempSectionState extends State<_TempSection> {
  String mode = '그래프';
  bool loading = true;
  String? error;
  List<SeaStationTemp> stations = [];


  bool _sentToWatch = false;

  static const double _lat = 35.1151;
  static const double _lon = 129.0415;
  static const String _key = 'X2KN516OA5RAUL3GPCEFARGKHHKJQN';

  @override
  void initState() {
    super.initState();
    _fetchTemp();
  }

  Future<void> _fetchTemp() async {
    try {
      final uri = Uri.parse('https://www.badatime.com/DIVE/temp?lat=$_lat&lon=$_lon&key=$_key');
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
      final payload = stations.take(8).map((s) => {
        "name": s.name,
        "temp": s.tempC.toStringAsFixed(1),
        "obs_time": s.obsTime.toIso8601String(),
        "distance_km": s.distanceKm?.toStringAsFixed(1) ?? ""
      }).toList();

      await WearBridge.sendTempStations(payload);

      _sentToWatch = true;
    } catch (_) {
      // 전송 실패는 조용히 무시 (UI 영향 X)
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Text('불러오기 실패: $error', style: const TextStyle(color: Colors.red)),
      );
    }
    if (stations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: Text('수온 데이터가 없습니다.'),
      );
    }

    final current = stations.first;
    final String currentTempText = '${current.tempC.toStringAsFixed(1)}°C';
    final String lastUpdateText = '최근 업데이트 : ${_fmtDate(current.obsTime)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Text(_formatKDate(today), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
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
                    children: [
                      Expanded(
                        child: Text('${current.name}\n현재 수온 :',
                            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2)),
                      ),
                      Text(currentTempText,
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 18)),
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
                    child: const _MiniLineChart(), // 히스토리 없으므로 더미 그래프
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(lastUpdateText, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.pushNamed(context, Routes.tempCompare),
                    child: const Text(
                      '인근 바다와 수온 비교해보기',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),
        const Text('주변 관측소 수온', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),

        Row(
          children: [
            _SelectableChip(label: '그래프', selected: mode == '그래프', onTap: () => setState(() => mode = '그래프')),
            const SizedBox(width: 8),
            _SelectableChip(label: '표', selected: mode == '표', onTap: () => setState(() => mode = '표')),
          ],
        ),
        const SizedBox(height: 12),

        if (mode == '그래프')
          SizedBox(
            height: 180,
            child: DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFFE9F5FF), borderRadius: BorderRadius.circular(16)),
              child: const Padding(padding: EdgeInsets.all(8.0), child: _MiniLineChart(secondary: true)),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                children: [
                  const _CompareHeader(),
                  const SizedBox(height: 8),
                  ...stations.take(8).map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: _CompareRow(
                      place: s.name,
                      trendUp: true, // 추세 미제공: 임시 고정
                      temp: '${s.tempC.toStringAsFixed(1)}°C',
                      dist: s.distanceKm == null ? '-' : '${s.distanceKm!.toStringAsFixed(1)}㎞',
                    ),
                  )),
                ],
              ),
            ),
          ),
      ],
    );
  }
}


class TempComparePage extends StatefulWidget {
  const TempComparePage({super.key});

  @override
  State<TempComparePage> createState() => _TempComparePageState();
}

class _TempComparePageState extends State<TempComparePage> {
  bool loading = true;
  String? error;
  List<SeaStationTemp> stations = [];

  static const double _lat = 35.1151;
  static const double _lon = 129.0415;
  static const String _key = 'X2KN516OA5RAUL3GPCEFARGKHHKJQN';

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final uri = Uri.parse('https://www.badatime.com/DIVE/temp?lat=$_lat&lon=$_lon&key=$_key');
      final res = await http.get(uri);
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final body = json.decode(utf8.decode(res.bodyBytes));
      final list = (body is List) ? body : (body['data'] ?? body['items'] ?? []) as List;
      final parsed = list.map((e) => SeaStationTemp.fromJson(e as Map<String, dynamic>)).toList()
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
      appBar: AppBar(title: const Text('바다 날씨'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Center(child: Text(_formatKDate(DateTime.now()), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('인근 바다와 수온 비교', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: _CompareHeader()),
                const SizedBox(height: 8),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('불러오기 실패: $error', style: const TextStyle(color: Colors.red)),
                  )
                else
                  ...stations.take(20).map((e) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: _CompareRow(
                      place: e.name,
                      trendUp: true,
                      temp: '${e.tempC.toStringAsFixed(1)}°C',
                      dist: e.distanceKm == null ? '-' : '${e.distanceKm!.toStringAsFixed(1)}㎞',
                    ),
                  )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}


class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({required this.label, required this.selected, required this.onTap});

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
          border: Border.all(color: selected ? cs.primary : Colors.black12, width: selected ? 1.4 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check, size: 16, color: cs.primary),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? cs.primary : Colors.black87)),
          ],
        ),
      ),
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
      decoration: BoxDecoration(color: const Color(0xFFF1FAFF), borderRadius: BorderRadius.circular(12)),
      child: Center(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
    );
  }
}

class _ForecastRowData {
  final String date;
  final String amPm;
  final String period;
  final String height;
  final String dir;
  const _ForecastRowData({required this.date, required this.amPm, required this.period, required this.height, required this.dir});
}

class _ForecastBlock extends StatelessWidget {
  final List<_ForecastRowData> rows;
  const _ForecastBlock({required this.rows});

  @override
  Widget build(BuildContext context) {
    const headerStyle = TextStyle(fontWeight: FontWeight.w800, color: Colors.black54);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFE9F5FF), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: const [
                  Expanded(flex: 8, child: Text('날짜', style: headerStyle)),
                  Expanded(flex: 4, child: Padding(padding: EdgeInsets.only(left: 10), child: Text('파주기', style: headerStyle))),
                  Expanded(flex: 3, child: Padding(padding: EdgeInsets.only(left: 14), child: Text('파고', style: headerStyle))),
                  Expanded(flex: 4, child: Padding(padding: EdgeInsets.only(left: 14), child: Text('파향', style: headerStyle))),
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
}

class _ForecastCard extends StatelessWidget {
  final String date;
  final List<_ForecastRowData> items;

  const _ForecastCard({super.key, required this.date, required this.items});

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(fontWeight: FontWeight.w800, color: Colors.black.withOpacity(0.85));

    Widget colTexts(List<String> v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        v.length,
            (i) => Padding(
          padding: EdgeInsets.only(bottom: i == v.length - 1 ? 0 : 12),
          child: Text(v[i], overflow: TextOverflow.ellipsis, softWrap: false),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD7E9FF))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(width: 72, child: Center(child: Text(date, style: labelStyle))),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(
                    items.length,
                        (i) => Padding(
                      padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
                      child: _AmPmChip(text: items[i].amPm, isAm: items[i].amPm == '오전'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 4, child: Padding(padding: const EdgeInsets.only(left: 10), child: colTexts(items.map((e) => e.period).toList()))),
          Expanded(flex: 3, child: Padding(padding: const EdgeInsets.only(left: 14), child: colTexts(items.map((e) => e.height).toList()))),
          Expanded(flex: 4, child: Padding(padding: const EdgeInsets.only(left: 14), child: colTexts(items.map((e) => e.dir).toList()))),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _CompareHeader extends StatelessWidget {
  const _CompareHeader();

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

  const _CompareRow({required this.place, required this.trendUp, required this.temp, required this.dist});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE9EEF3))),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(place, style: const TextStyle(fontWeight: FontWeight.w700))),
          Expanded(
            flex: 3,
            child: Center(child: Icon(trendUp ? Icons.arrow_drop_up : Icons.arrow_drop_down, color: trendUp ? Colors.red : Colors.blue)),
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
      decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
    );
  }
}

class _MiniLineChart extends StatelessWidget {
  final bool secondary;
  const _MiniLineChart({this.secondary = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth.isFinite ? constraints.maxWidth : 300.0;
        final double h = constraints.maxHeight.isFinite ? constraints.maxHeight : 150.0;
        return CustomPaint(size: Size(w, h), painter: _MiniLinePainter(secondary: secondary));
      },
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final bool secondary;
  _MiniLinePainter({required this.secondary});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = const Color(0xFFDAE7F2)..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final p1 = Paint()..color = const Color(0xFF5A7DFF)..style = PaintingStyle.stroke..strokeWidth = 2.2;
    final path1 = Path();
    for (int i = 0; i <= 20; i++) {
      final wave = (i % 4 < 2 ? 1 - (i % 2) * 0.5 : 0.5);
      final x = size.width * (i / 20);
      final y = size.height * (0.7 - 0.2 * wave);
      if (i == 0) path1.moveTo(x, y); else path1.lineTo(x, y);
    }
    canvas.drawPath(path1, p1);

    if (secondary) {
      final p2 = Paint()..color = const Color(0xFFB35DFF)..style = PaintingStyle.stroke..strokeWidth = 2.0;
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
  bool shouldRepaint(covariant _MiniLinePainter oldDelegate) => oldDelegate.secondary != secondary;
}
DateTime _kDateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

String _formatKDate(DateTime dt) {
  const wd = ['월','화','수','목','금','토','일'];
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
    'N':'북','NNE':'북북동','NE':'북동','ENE':'동북동',
    'E':'동','ESE':'동남동','SE':'남동','SSE':'남남동',
    'S':'남','SSW':'남남서','SW':'남서','WSW':'서남서',
    'W':'서','WNW':'서북서','NW':'북서','NNW':'북북서',
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
  final avg = vals.reduce((a,b)=>a+b)/vals.length;
  return '${avg.toStringAsFixed(1)} $unit';
}

String _modeOrLast(List<String> vals) {
  if (vals.isEmpty) return '-';
  final freq = <String,int>{};
  for (final v in vals) { freq[v] = (freq[v] ?? 0) + 1; }
  final best = freq.entries.reduce((a,b)=>a.value>=b.value?a:b).key;
  return best;
}

class _ForecastDayGroup {
  final String dateLabel;
  final List<_ForecastRowData> items;
  _ForecastDayGroup(this.dateLabel, this.items);
}

List<_ForecastDayGroup> _groupByDateAmPm(
    List<SeaWave> waves, {
      int days = 3,
    }) {
  final byDay = <DateTime, List<SeaWave>>{};
  for (final w in waves) {
    final d = _kDateOnly(w.time);
    byDay.putIfAbsent(d, () => []).add(w);
  }

  final keys = byDay.keys.toList()..sort();
  final targetKeys = days >= keys.length ? keys : keys.take(days).toList();

  final out = <_ForecastDayGroup>[];
  for (final d in targetKeys) {
    final list = byDay[d]!..sort((a,b)=>a.time.compareTo(b.time));
    final am = list.where((w) => w.time.hour < 12).toList();
    final pm = list.where((w) => w.time.hour >= 12).toList();

    String label = '${d.month}.${d.day} (${['월','화','수','목','금','토','일'][d.weekday-1]})';
    String prd(List<SeaWave> xs) => _rangeText(xs.map((e)=>e.wavePrd).toList(), unit: 's');
    String hgt(List<SeaWave> xs) => _avgText(xs.map((e)=>e.waveHt).toList(), unit: 'm');
    String dir(List<SeaWave> xs) => xs.isEmpty ? '-' : korDir(_modeOrLast(xs.map((e)=>e.waveDir).toList()));

    final items = <_ForecastRowData>[];
    if (am.isNotEmpty) items.add(_ForecastRowData(date: label, amPm: '오전', period: prd(am), height: hgt(am), dir: dir(am)));
    if (pm.isNotEmpty) items.add(_ForecastRowData(date: label, amPm: '오후', period: prd(pm), height: hgt(pm), dir: dir(pm)));
    if (items.isEmpty) continue;
    out.add(_ForecastDayGroup(label, items));
  }
  return out;
}

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
    // 시간
    String? t = (j['ymdt'] ?? j['time'] ?? j['date'])?.toString();
    late DateTime dt;
    DateTime _fromYmd(String s) {
      final y = int.parse(s.substring(0, 4));
      final m = int.parse(s.substring(4, 6));
      final d = int.parse(s.substring(6, 8));
      return DateTime(y, m, d);
    }
    DateTime _fromYmdH(String s) {
      final y = int.parse(s.substring(0, 4));
      final m = int.parse(s.substring(4, 6));
      final d = int.parse(s.substring(6, 8));
      final h = int.parse(s.substring(8, 10));
      return DateTime(y, m, d, h);
    }
    if (t != null && RegExp(r'^\d{10}$').hasMatch(t)) {
      dt = _fromYmdH(t);
    } else if (t != null && RegExp(r'^\d{8}$').hasMatch(t)) {
      dt = _fromYmd(t);
    } else if (t != null && t.isNotEmpty) {
      t = t.replaceAll('/', '-').replaceFirst(' ', 'T');
      dt = DateTime.tryParse(t) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }

    final prd = _toDouble(_pick(j, ['waveprd', 'prd', 'period']));
    final ht  = _toDouble(_pick(j, ['waveht', 'height']));
    final dir = (_pick<String>(j, ['wavedir', 'dir']) ?? '').toString().toUpperCase();

    return SeaWave(time: dt, wavePrd: prd, waveHt: ht, waveDir: dir.isEmpty ? '-' : dir);
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

  static T? _pick<T>(Map<String,dynamic> j, List<String> cands) {
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

  factory SeaStationTemp.fromJson(Map<String,dynamic> j) {
    final name = (j['obs_name'] ?? j['name'] ?? '관측소').toString();

    final t = (j['obs_time'] ?? j['time'] ?? '').toString();
    final obsTime = DateTime.tryParse(t.replaceFirst(' ', 'T')) ?? DateTime.now();

    final rawTemp = _pick(j, ['sst','seatemperature','watertemp','temp_c','temp']);
    final tempC = _toDouble(rawTemp);

    final dt = (j['obs_dt'] ?? j['distance'] ?? '').toString();
    final distanceKm = double.tryParse(dt.replaceAll('km', '').replaceAll('㎞', '').trim());

    return SeaStationTemp(name: name, obsTime: obsTime, tempC: tempC, distanceKm: distanceKm);
  }
}
