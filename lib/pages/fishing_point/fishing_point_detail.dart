// lib/pages/fishing_point/fishing_point_detail.dart
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';

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

  final Map<int, _SeasonData> _seasonData = const {
    0: _SeasonData(surface: 16.8, bottom: 13.9, fishes: ['감성돔', '참돔', '농어', '볼락']),
    1: _SeasonData(surface: 22.1, bottom: 19.0, fishes: ['농어', '전갱이', '돌돔']),
    2: _SeasonData(surface: 18.3, bottom: 15.2, fishes: ['광어', '우럭', '감성돔']),
    3: _SeasonData(surface: 11.9, bottom: 10.1, fishes: ['볼락', '우럭']),
  };

  @override
  Widget build(BuildContext context) {
    final p = widget.point;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        elevation: 0,
        title: const Text('낚시포인트 상세페이지'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _PointMap(point: p),
            const SizedBox(height: 12),
            _SummaryCard(point: p),
            const SizedBox(height: 12),
            _SeasonCard(
              season: _season,
              onChanged: (v) => setState(() => _season = v),
              data: _seasonData[_season]!,
            ),
            const SizedBox(height: 12),
            const _WarningCard(),
            const SizedBox(height: 12),
            const _DetailCard(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
        child: Row(
          children: [
            _roundIconBtn(Icons.bookmark_border, onTap: () {}),
            const SizedBox(width: 10),
            _roundIconBtn(Icons.ios_share, onTap: () {}),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () async {
                final lat = p.lat, lng = p.lng;
                if (lat == null || lng == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('좌표가 없어 길찾기를 열 수 없어요.')),
                  );
                  return;
                }
                await _openNaverDirections(lat, lng, name: p.name);
              },
              icon: const Icon(Icons.directions),
              label: const Text('길찾기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roundIconBtn(IconData icon, {VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.star_border, size: 0),
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
                initialCameraPosition: NCameraPosition(target: _target, zoom: 14),
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
              onMapTapped: (pt, latLng) {

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
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
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
                            NCameraPosition(target: pos.target, zoom: pos.zoom + 1),
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
                            NCameraPosition(target: pos.target, zoom: pos.zoom - 1),
                          ),
                        );
                      },
                    ),
                  ],
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
                    Text(point.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('영종도·옹진군', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const Icon(Icons.landscape_rounded, size: 20, color: Colors.brown),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(icon: Icons.water_drop, iconColor: Color(0xFF3B82F6), label: '수심', value: point.depthRange),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.place_rounded, iconColor: Colors.redAccent, label: '주소', value: point.location),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.layers_rounded, iconColor: Colors.orange, label: '바닥지질', value: '갯벌'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.campaign, size: 18, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(point.species.join(', '), style: const TextStyle(fontSize: 13.5, color: Colors.black87)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.iconColor, required this.label, required this.value});
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
        Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
      ],
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.season, required this.onChanged, required this.data});
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
            value: '표층 : ${data.surface.toStringAsFixed(1)}°C   저층 : ${data.bottom.toStringAsFixed(1)}°C',
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.campaign, size: 18, color: Color(0xFF3B82F6)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(data.fishes.join(', '), style: const TextStyle(fontSize: 13.5, color: Colors.black87)),
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
          side: BorderSide(color: selected ? const Color(0xFFB6DAFF) : const Color(0xFFE4E6EB)),
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
  const _SeasonData({required this.surface, required this.bottom, required this.fishes});
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      color: const Color(0xFFFFF7E6),
      borderColor: const Color(0xFFFFE0A1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Padding(
            padding: EdgeInsets.only(right: 10, top: 2),
            child: Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309)),
          ),
          Expanded(
            child: Text(
              '연화도 남쪽에 작은 간출암이 존재하고, 연화도와 무도를 연결하는 갯펄(해빈)이 있다. 또한 북쪽 해상에 양식장이 있어 운항 선박은 주의가 필요하다.',
              style: TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _BlockTitle('상세 정보'),
          SizedBox(height: 12),
          _SubTitle(icon: Icons.waves, color: Color(0xFF3B82F6), title: '물·조류 정보'),
          SizedBox(height: 6),
          Text(
            '벙도 남서에서의 창조류는 북동방향 2.3kn, 낙조류는 남서방향 2.5kn. 대조기 간조가 빠르고 소조기 만조는 느린 편.',
            style: TextStyle(height: 1.6),
          ),
          SizedBox(height: 14),
          _SubTitle(icon: Icons.dry, color: Color(0xFFFB923C), title: '기상 정보'),
          SizedBox(height: 6),
          Text(
            '봄철 북서계절풍 이후 대물 우럭의 움직임. 남서풍 강하면 감성돔 조황↑. 겨울엔 주변보다 수온 2~3°C 낮음.',
            style: TextStyle(height: 1.6),
          ),
          SizedBox(height: 14),
          _SubTitle(icon: Icons.pin_drop_rounded, color: Color(0xFF10B981), title: '포인트 소개'),
          SizedBox(height: 6),
          Text(
            '대표 어종: 광어, 우럭, 넙치, 노래미, 농어, 볼락 등. 미노우/지그헤드, 8~9ft 미디엄 로드 권장.',
            style: TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _SubTitle extends StatelessWidget {
  const _SubTitle({required this.icon, required this.title, required this.color});
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
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900));
  }
}

class _ArgErrorPage extends StatelessWidget {
  const _ArgErrorPage();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('잘못된 인자입니다. FishingPoint를 넘겨주세요.')));
  }
}


Future<void> _openNaverDirections(double lat, double lng, {String name = '목적지'}) async {
  final appUrl = 'nmap://route/public?dlat=$lat&dlng=$lng&dname=${Uri.encodeComponent(name)}&appname=com.pan.resq';
  final webUrl = 'https://map.naver.com/v5/?c=$lng,$lat,17,0,0,0,dh';

  final appUri = Uri.parse(appUrl);
  final webUri = Uri.parse(webUrl);

  if (await canLaunchUrl(appUri)) {
    await launchUrl(appUri);
  } else {
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
}
