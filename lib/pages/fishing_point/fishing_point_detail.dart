import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import '../../models/fishing_point.dart';

class FishingPointDetailPage extends StatefulWidget {
  final FishingPoint point;
  const FishingPointDetailPage({super.key, required this.point});

  static Widget from(Object? args) {
    if (args is FishingPoint) return FishingPointDetailPage(point: args);
    return const _ArgErrorPage();
  }

  @override
  State<FishingPointDetailPage> createState() => _FishingPointDetailPageState();
}

class _FishingPointDetailPageState extends State<FishingPointDetailPage> {
  int _season = 0;
  bool _loading = true;
  String? _error;

  late _SeasonData _spring;
  late _SeasonData _summer;
  late _SeasonData _fall;
  late _SeasonData _winter;

  String _notice = '';
  String _intro = '';
  String _forecast = '';
  String _ebbflow = '';

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final lat = widget.point.lat ?? 35.1151;
    final lon = widget.point.lng ?? 129.0415;
    final url =
        'https://www.badatime.com/DIVE/point?lat=$lat&lon=$lon&key=X2KN516OA5RAUL3GPCEFARGKHHKJQN';

    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final info = (j['info'] as Map).cast<String, dynamic>();

      T? pick<T>(Map<String, dynamic> j, List<String> cands) {
        String norm(String s) =>
            s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '').toLowerCase();
        final nk = {for (final k in j.keys) norm(k): k};
        for (final c in cands) {
          final hit = nk[norm(c)];
          if (hit != null) return j[hit] as T?;
        }
        return null;
      }

      List<String> parseFish(String? raw) => (raw ?? '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);

      _SeasonData parseTemp(String? raw, List<String> fishes) {
        final text = (raw ?? '').replaceAll(' ', '');
        final match =
        RegExp(r'표층:?([0-9.]+)℃.*?저층:?([0-9.]+)℃').firstMatch(text);
        final surface = match != null ? double.parse(match.group(1)!) : 0.0;
        final bottom = match != null ? double.parse(match.group(2)!) : 0.0;
        return _SeasonData(surface: surface, bottom: bottom, fishes: fishes);
      }

      _spring = parseTemp(
        pick<String>(info, ['wtemp_sp', 'wtempSpring', 'wtempsp']),
        parseFish(pick<String>(info, ['fish_sp', 'fishSpring', 'fishsp'])),
      );
      _summer = parseTemp(
        pick<String>(info, ['wtemp_su', 'wtempSummer', 'wtempsu']),
        parseFish(pick<String>(info, ['fish_su', 'fishSummer', 'fishsu'])),
      );
      _fall = parseTemp(
        pick<String>(info, ['wtemp_fa', 'wtempFall', 'wtempfa']),
        parseFish(pick<String>(info, ['fish_fa', 'fishFall', 'fishfa'])),
      );
      _winter = parseTemp(
        pick<String>(info, ['wtemp_wi', 'wtempWinter', 'wtempwi']),
        parseFish(pick<String>(info, ['fish_wi', 'fishWinter', 'fishwi'])),
      );

      _notice = pick<String>(info, ['notice', '주의', '알림']) ?? '';
      _intro = pick<String>(info, ['intro', '소개']) ?? '';
      _forecast = pick<String>(info, ['forecast', '기상']) ?? '';
      _ebbflow = pick<String>(info, ['ebbf', '조류', 'ebbFlow']) ?? '';

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '상세 데이터를 불러오지 못했어요. ${e.toString()}';
        _loading = false;
      });
    }
  }

  _SeasonData get _currentSeasonData =>
      [_spring, _summer, _fall, _winter][_season];

  @override
  Widget build(BuildContext context) {
    final p = widget.point;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: const Text('낚시포인트 상세페이지'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchInfo,
            tooltip: '새로고침',
          )
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _fetchInfo,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PointMap(point: p),
            const SizedBox(height: 12),
            _SummaryCard(point: p),
            const SizedBox(height: 12),
            _SeasonCard(
              season: _season,
              onChanged: (v) => setState(() => _season = v),
              data: _currentSeasonData,
            ),
            const SizedBox(height: 12),
            if (_notice.isNotEmpty) _WarningCard(text: _notice),
            if (_notice.isNotEmpty) const SizedBox(height: 12),
            _DetailCard(
              intro: _intro,
              forecast: _forecast,
              ebbflow: _ebbflow,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PointMap extends StatefulWidget {
  const _PointMap({required this.point});
  final FishingPoint point;

  @override
  State<_PointMap> createState() => _PointMapState();
}

class _PointMapState extends State<_PointMap> {
  NaverMapController? _controller;

  NLatLng get _target => NLatLng(
    widget.point.lat ?? 35.2313,
    widget.point.lng ?? 129.0825,
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            NaverMap(
              options: NaverMapViewOptions(
                initialCameraPosition:
                NCameraPosition(target: _target, zoom: 14),
                mapType: NMapType.basic,
                locationButtonEnable: false,
                scrollGesturesEnable: true,
                zoomGesturesEnable: true,
                scaleBarEnable: true,
              ),
              onMapReady: (controller) async {
                _controller = controller;
                final marker = NMarker(
                  id: 'point_${_target.latitude}_${_target.longitude}',
                  position: _target,
                  caption: NOverlayCaption(text: widget.point.name),
                );
                await _controller!.addOverlay(marker);
              },
            ),

            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.black),
                      onPressed: () async {
                        if (_controller == null) return;
                        final pos = await _controller!.getCameraPosition();
                        await _controller!.updateCamera(
                          NCameraUpdate.fromCameraPosition(
                            NCameraPosition(
                                target: pos.target, zoom: pos.zoom + 1),
                          ),
                        );
                      },
                    ),
                    Container(width: 36, height: 1, color: Colors.grey[300]),
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.black),
                      onPressed: () async {
                        if (_controller == null) return;
                        final pos = await _controller!.getCameraPosition();
                        await _controller!.updateCamera(
                          NCameraUpdate.fromCameraPosition(
                            NCameraPosition(
                                target: pos.target, zoom: pos.zoom - 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 10,
              bottom: 10,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final lat = widget.point.lat, lng = widget.point.lng;
                  if (lat == null || lng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('좌표가 없어 길찾기를 열 수 없어요.')),
                    );
                    return;
                  }
                  await _openNaverDirections(lat, lng, name: widget.point.name);
                },
                icon: const Icon(Icons.directions),
                label: const Text('길찾기'),
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.point});
  final FishingPoint point;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(point.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(point.location.isEmpty ? '-' : point.location,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const Icon(Icons.landscape_rounded,
                  size: 20, color: Colors.brown),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(
              icon: Icons.water_drop,
              iconColor: const Color(0xFF3B82F6),
              label: '수심',
              value: point.depthRange.isEmpty ? '-' : point.depthRange),
          const SizedBox(height: 6),
          _InfoLine(
              icon: Icons.place_rounded,
              iconColor: Colors.redAccent,
              label: '주소',
              value: point.location.isEmpty ? '-' : point.location),
          const SizedBox(height: 6),
          _InfoLine(
              icon: Icons.layers_rounded,
              iconColor: Colors.orange,
              label: '바닥지질',
              value: '정보 없음'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.campaign,
                    size: 18, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    point.species.isEmpty
                        ? '어종 정보 없음'
                        : point.species.join(', '),
                    style: const TextStyle(fontSize: 13.5, color: Colors.black87)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(
      {required this.icon,
        required this.iconColor,
        required this.label,
        required this.value});
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Text('$label  ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(
            child: Text(value, style: const TextStyle(color: Colors.black87))),
      ],
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard(
      {required this.season, required this.onChanged, required this.data});
  final int season;
  final ValueChanged<int> onChanged;
  final _SeasonData data;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle('계절별 어종 정보'),
          const SizedBox(height: 8),
          _SeasonChips(value: season, onChanged: onChanged),
          const SizedBox(height: 10),
          const Divider(height: 20),
          _InfoLine(
            icon: Icons.thermostat,
            iconColor: Colors.orange,
            label: '수온',
            value:
            '표층 : ${data.surface.toStringAsFixed(1)}°C   저층 : ${data.bottom.toStringAsFixed(1)}°C',
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.campaign,
                    size: 18, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  data.fishes.isEmpty ? '어종 정보 없음' : data.fishes.join(', '),
                  style:
                  const TextStyle(fontSize: 13.5, color: Colors.black87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SeasonChips extends StatelessWidget {
  const _SeasonChips({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = const ['봄', '여름', '가을', '겨울'];
    return Wrap(
      spacing: 8,
      children: List<Widget>.generate(items.length, (i) {
        final selected = value == i;
        return ChoiceChip(
          label: Text(items[i]),
          selected: selected,
          onSelected: (_) => onChanged(i),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? const Color(0xFF1664D9) : Colors.black87,
          ),
          selectedColor: const Color(0xFFEAF4FF),
          backgroundColor: Colors.white,
          side: BorderSide(
              color: selected
                  ? const Color(0xFFB6DAFF)
                  : const Color(0xFFE4E6EB)),
          shape: const StadiumBorder(),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        );
      }),
    );
  }
}

class _SeasonData {
  final double surface;
  final double bottom;
  final List<String> fishes;
  const _SeasonData(
      {required this.surface, required this.bottom, required this.fishes});
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: const Color(0xFFFFF7E6),
      borderColor: const Color(0xFFFFE0A1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 10, top: 2),
            child:
            Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          ),
          Expanded(
            child: Text(text.isEmpty ? '주의 정보 없음' : text,
                style: const TextStyle(height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard(
      {required this.intro, required this.forecast, required this.ebbflow});
  final String intro;
  final String forecast;
  final String ebbflow;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BlockTitle('상세 정보'),
          const SizedBox(height: 12),
          const _SubTitle(
              icon: Icons.waves,
              color: Color(0xFF3B82F6),
              title: '물·조류 정보'),
          const SizedBox(height: 6),
          Text(
            ebbflow.isEmpty ? '조류 정보 없음' : ebbflow,
            style: const TextStyle(height: 1.6),
          ),
          const SizedBox(height: 14),
          const _SubTitle(
              icon: Icons.dry,
              color: Color(0xFFFB923C),
              title: '기상 정보'),
          const SizedBox(height: 6),
          Text(
            forecast.isEmpty ? '기상 정보 없음' : forecast,
            style: const TextStyle(height: 1.6),
          ),
          const SizedBox(height: 14),
          const _SubTitle(
              icon: Icons.pin_drop_rounded,
              color: Color(0xFF10B981),
              title: '포인트 소개'),
          const SizedBox(height: 6),
          Text(
            intro.isEmpty ? '소개 정보 없음' : intro,
            style: const TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle(
      {required this.icon, required this.title, required this.color});
  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color, this.borderColor});
  final Widget child;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900));
  }
}

class _ArgErrorPage extends StatelessWidget {
  const _ArgErrorPage();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
        body: Center(child: Text('잘못된 인자입니다. FishingPoint를 넘겨주세요.')));
  }
}

Future<void> _openNaverDirections(double lat, double lng,
    {String name = '목적지'}) async {
  final appUrl =
      'nmap://route/public?dlat=$lat&dlng=$lng&dname=${Uri.encodeComponent(name)}&appname=com.pan.resq';
  final webUrl = 'https://map.naver.com/v5/?c=$lng,$lat,17,0,0,0,dh';

  final appUri = Uri.parse(appUrl);
  final webUri = Uri.parse(webUrl);

  if (await canLaunchUrl(appUri)) {
    await launchUrl(appUri);
  } else {
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
