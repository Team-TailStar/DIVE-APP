
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../app_bottom_nav.dart';
import '../../routes.dart';
import '../../models/fishing_point.dart';
import '../../wear_bridge.dart';
import '../../env.dart';

class FishingPointMainPage extends StatefulWidget {
  const FishingPointMainPage({super.key});

  @override
  State<FishingPointMainPage> createState() => _FishingPointMainPageState();
}

class _FishingPointMainPageState extends State<FishingPointMainPage> {

  static const double _originLat = 35.1151;
  static const double _originLon = 129.0415;

  Uri get _apiUri => Uri.parse(
    '${Env.API_BASE_URL}/point?lat=$_originLat&lon=$_originLon&key=${Env.BADA_SERVICE_KEY}',
  );

  static const _fallbackImg =
      'https://images.unsplash.com/photo-1508182311256-e3f6b475a2e4?auto=format&fit=crop&w=1080&q=80';

  bool _incheonSelected = true;

  bool _loading = true;
  String? _error;
  List<FishingPoint> _points = const [];

  @override
  void initState() {
    super.initState();
    _fetchPoints();
  }

  Future<void> _fetchPoints() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.get(_apiUri);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['fishing_point'] as List).cast<Map<String, dynamic>>();

      final parsed = list.map<FishingPoint>((j) => _toModel(j)).toList();

      parsed.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      setState(() {
        _points = parsed;
        _loading = false;
      });
      await WearBridge.sendFishingPoints(parsed.map((p) =>
      {
        'name': p.name,
        'point_nm': p.name,
        'dpwt': p.depthRange,
        'material': '',
        'tide_time': '',
        'target': p.species.join(','),
        'lat': p.lat,
        'lon': p.lng,
        'point_dt': '',
      }).toList());
    }
    catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했어요. ${e.toString()}';
        _loading = false;
      });
    }
  }

  T? _pick<T>(Map<String, dynamic> j, List<String> cands) {
    String norm(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '').toLowerCase();
    final nk = {for (final k in j.keys) norm(k): k};
    for (final c in cands) {
      final key = nk[norm(c)];
      if (key != null) return j[key] as T?;
    }
    return null;
  }

  List<String> _parseSpecies(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split('▶')
        .map((s) => s.split('-').first.trim())
        .where((s) => s.isNotEmpty)
        .toList(growable: false);
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  FishingPoint _toModel(Map<String, dynamic> j) {
    final name = _pick<String>(j, ['point_nm', 'name']) ?? '이름 없음';
    final addr = _pick<String>(j, ['addr', '주소']) ?? '';
    final dpwt = _pick<String>(j, ['dpwt', 'depth', '수심']) ?? '';
    final latStr = _pick<String>(j, ['lat']) ?? '0';
    final lonStr = _pick<String>(j, ['lon']) ?? '0';
    final photo = _pick<String>(j, ['photo', 'image', 'image_url', 'img']);
    final target = _pick<String>(j, ['target']);

    final imageUrl =
    (photo == null || photo.trim().isEmpty) ? _fallbackImg : photo.trim();

    final lat = double.tryParse(latStr) ?? 0.0;
    final lon = double.tryParse(lonStr) ?? 0.0;
    final dist = _haversineKm(_originLat, _originLon, lat, lon);

    return FishingPoint(
      id: '${lat}_${lon}_${name.hashCode}',
      name: name,
      location: addr,
      distanceKm: dist,
      depthRange: dpwt,
      species: _parseSpecies(target),
      imageUrl: imageUrl,
      lat: lat,
      lng: lon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black),
        title: const Text('낚시포인트'),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPoints,
            tooltip: '새로고침',
          )
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _fetchPoints,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: _points.length + 2, // 2 = 필터 영역 + 섹션 타이틀
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FilterRow(
                    incheonSelected: _incheonSelected,
                    onTap: () => setState(() => _incheonSelected = !_incheonSelected),
                  );
                }
                if (index == 1) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      '총 포인트 목록',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600),
                    ),
                  );
                }

                final item = _points[index - 2];
                return _FishingPointCard(
                  data: item,
                  onTapDetail: () {
                    Navigator.pushNamed(
                      context,
                      Routes.fishingPointDetail,
                      arguments: item,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.incheonSelected, required this.onTap});
  final bool incheonSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _ChipButton(label: '인천', selected: incheonSelected, onTap: onTap),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _ChipButton extends StatelessWidget {
  const _ChipButton(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFEAF4FF) : Colors.white;
    final border =
    selected ? const Color(0xFFB6DAFF) : const Color(0xFFE4E6EB);
    final text = selected ? const Color(0xFF2A79FF) : Colors.black87;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Text(label,
              style:
              TextStyle(color: text, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _FishingPointCard extends StatelessWidget {
  const _FishingPointCard({required this.data, required this.onTapDetail});
  final FishingPoint data;
  final VoidCallback onTapDetail;

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE9ECF1)),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumb(imageUrl: data.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목 + 거리
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          data.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatKm(data.distanceKm),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    iconColor: Colors.redAccent,
                    text: data.location,
                  ),
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.waves_outlined,
                    iconColor: const Color(0xFF2A79FF),
                    text: data.depthRange,
                  ),
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.arrow_right_alt_rounded,
                    iconColor: Colors.black54,
                    text: data.species.isEmpty
                        ? '어종 정보 없음'
                        : data.species.join(', '),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFA6DBFF),
                        foregroundColor: const Color(0xFF0B6AAE),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: onTapDetail,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('상세보기'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKm(double km) {
    final isInt = km.truncateToDouble() == km;
    return '${km.toStringAsFixed(isInt ? 0 : 1)} km';
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFEFF3F8),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined,
                size: 28, color: Colors.black38),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
