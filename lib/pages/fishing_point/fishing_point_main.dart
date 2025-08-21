import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

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


  double? _myLat;
  double? _myLon;

  // 기본 좌표(부산 대략)
  static const double _defaultLat = 35.1151;
  static const double _defaultLon = 129.0415;

  // 바다별 중심 좌표(간단한 대표지점)
  static const Map<SeaArea, (double, double)> _seaCenters = {
    SeaArea.west: (37.4563, 126.7052), // 인천
    SeaArea.south: (35.1796, 129.0756), // 부산 시내
    SeaArea.east: (37.7519, 128.8761), // 강릉
    SeaArea.jeju: (33.4996, 126.5312), // 제주
  };

  Uri get _apiUri => Uri.parse(
    '${Env.API_BASE_URL}/point?lat=${_myLat ?? _defaultLat}&lon=${_myLon ?? _defaultLon}&key=${Env.BADA_SERVICE_KEY}',
  );

  static const _fallbackImg =
      'https://images.unsplash.com/photo-1508182311256-e3f6b475a2e4?auto=format&fit=crop&w=1080&q=80';

  // 선택 상태
  SeaArea _selectedSea = SeaArea.south; // 초기: 남해(부산)
  String? _selectedRegion; // 예) '부산광역시 영도구'
  String? _selectedSpot; // 예) '대항선착장'

  // (옵션) 반경 필터 참고용
  dynamic _lastChosenSeaSpot;
  double radiusKm = 0; // 0이면 미적용

  bool _loading = true;
  String? _error;
  List<FishingPoint> _points = const [];

  @override
  void initState() {
    super.initState();

    _init(); 
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _ensureLocationPermission();
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _myLat = pos.latitude;
      _myLon = pos.longitude;
      _regionTitle = '내 위치';
    } catch (_) {
      // 권한 거부/실패 → 기본좌표로 진행
      _myLat = null;
      _myLon = null;
      _regionTitle = '낚시포인트';
    }

    await _fetchPoints();
  }


  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('위치 서비스가 꺼져 있어요.');

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('위치 권한이 없어 현재 위치를 쓸 수 없어요.');
    }
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

      // 웨어러블 전송
      await WearBridge.sendFishingPoints(parsed
          .map((p) => {
        'name': p.name,
        'point_nm': p.name,
        'dpwt': p.depthRange,
        'material': '',
        'tide_time': '',
        'target': p.species.join(','),
        'lat': p.lat,
        'lon': p.lng,
        'point_dt': '',
      })
          .toList());
    } catch (e) {
      setState(() {
        _error = '데이터를 불러오지 못했어요. ${e.toString()}';
        _loading = false;
      });
    }
  }

  T? _pick<T>(Map<String, dynamic> j, List<String> cands) {
    String norm(String s) =>
        s.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '').toLowerCase();
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
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double d) => d * math.pi / 180.0;

  String resolveImageUrl(String? raw, {required String fallback}) {
    final p = raw?.trim() ?? '';
    if (p.isEmpty) return fallback;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    final base = Env.IMAGE_BASE_URL.trim();
    if (base.isEmpty) return fallback;

    final sep1 = base.endsWith('/') ? '' : '/';
    final sep2 = p.startsWith('/') ? '' : '/'; // ✅ 앞/뒤 슬래시 중복 방지
    return '$base$sep1$sep2$p';
  }

  FishingPoint _toModel(Map<String, dynamic> j) {
    final name = _pick<String>(j, ['point_nm', 'name']) ?? '이름 없음';
    final addr = _pick<String>(j, ['addr', '주소']) ?? '';
    final dpwt = _pick<String>(j, ['dpwt', 'depth', '수심']) ?? '';
    final latStr = _pick<String>(j, ['lat']) ?? '0';
    final lonStr = _pick<String>(j, ['lon']) ?? '0';

    final photoRaw = _pick<String>(j, ['photo', 'image_url', 'image', 'img']);
    final imageUrl = resolveImageUrl(photoRaw, fallback: _fallbackImg);

    final target = _pick<String>(j, ['target']);

    final lat = double.tryParse(latStr) ?? 0.0;
    final lon = double.tryParse(lonStr) ?? 0.0;

    // ✅ 거리 계산 기준: 내 위치가 있으면 내 위치, 없으면 기본값
    final baseLat = _myLat ?? _defaultLat;
    final baseLon = _myLon ?? _defaultLon;
    final dist = _haversineKm(baseLat, baseLon, lat, lon);

    return FishingPoint(
        id: '${lat}_${lon}_${name.hashCode}',
        name: name,
        location: addr,
        distanceKm: dist,
        depthRange: dpwt,
        species: _parseSpecies(target),
    imageUrl: imageUrl,
    lat: lon,
    );
  }

  // ---------- Region/Spot 유틸 ----------

  String _normalizeRegion(String addr) {
    if (addr.trim().isEmpty) return '';
    final parts = addr.split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return '${parts[0]} ${parts[1]}';
  }

  List<String> get _availableRegions {
    final set = <String>{};
    for (final p in _points) {
      final reg = _normalizeRegion(p.location);
      if (reg.isNotEmpty) set.add(reg);
    }
    final list = set.toList()..sort((a, b) => a.compareTo(b));
    return list;
  }

  List<String> _spotsForRegion(String region) {
    final list = _points
        .where((p) => _normalizeRegion(p.location) == region)
        .map((p) => p.name.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.compareTo(b));
    return list;
  }

  // ---------- Bottom Sheet ----------

  Future<void> _openSeaSheet() async {
    final ret = await showModalBottomSheet<SeaArea>(
      context: context,
      useSafeArea: true,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _PickerSheet<SeaArea>(
          title: '바다 선택',
          options: SeaArea.values,
          labelOf: (SeaArea s) => s.label,
          selected: _selectedSea,
        );
      },
    );
    if (ret != null && ret != _selectedSea) {
      setState(() {
        _selectedSea = ret;
        _selectedRegion = null;
        _selectedSpot = null;
        _setCenterBySea(ret); // ✅ 기준 좌표 변경
      });
      await _fetchPoints();   // ✅ 좌표 바뀌었으니 재호출
    }
  }

  Future<void> _openRegionSheet() async {
    final options = _availableRegions;
    final ret = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _PickerSheet<String>(
          title: '지역(도/시) 선택',
          options: options,
          labelOf: (s) => s,
          selected: _selectedRegion,
        );
      },
    );
    if (ret != null) {
      setState(() {
        _selectedRegion = ret;
        _selectedSpot = null;
      });
    }
  }

  Future<void> _openSpotSheet() async {
    if (_selectedRegion == null) return;
    final options = _spotsForRegion(_selectedRegion!);
    final ret = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _PickerSheet<String>(
          title: '스팟 선택',
          options: options,
          labelOf: (s) => s,
          selected: _selectedSpot,
        );
      },
    );
    if (ret != null) {
      setState(() {
        _selectedSpot = ret;
      });
    }
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true, // 배경을 앱바 뒤까지
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _regionTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        leadingWidth: 80,
        leading: IconButton(
          tooltip: '위치 선택',
          icon: const Icon(Icons.location_on_sharp, color: Color(0xFFFF4151)),
          onPressed: _pickRegion,
        ),
        actions: [
          IconButton(
            tooltip: '현재 위치로 새로고침',
            icon: const Icon(Icons.my_location, color: Colors.white),
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
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(0, topPad + kToolbarHeight, 0, 0),
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
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _init,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: _points.length + 1, // 1 = 섹션 타이틀만
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 4),
                        // child: Text(
                        //   '낚시 포인트 목록',
                        //   style: TextStyle(
                        //     fontSize: 14,
                        //     color: Colors.white,
                        //     fontWeight: FontWeight.w700,
                        //   ),
                        // ),
                      );
                    }

                    final item = _points[index - 1];
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
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  /// 리스트 필터(지역/스팟 + (옵션)반경)
  List<FishingPoint> _applyUiFilters(List<FishingPoint> src) {
    Iterable<FishingPoint> it = src;

    if (_selectedRegion != null) {
      it = it.where(
              (p) => _normalizeRegion(p.location) == (_selectedRegion ?? ''));
    }
    if (_selectedSpot != null) {
      it = it.where((p) => p.name.trim() == _selectedSpot);
    }

    final hasCenter = _lastChosenSeaSpot != null &&
        (_lastChosenSeaSpot.lat != null) &&
        (_lastChosenSeaSpot.lon != null);

    if (hasCenter && radiusKm > 0) {
      final double spotLat = (_lastChosenSeaSpot.lat as num).toDouble();
      final double spotLon = (_lastChosenSeaSpot.lon as num).toDouble();

      it = it.where((p) {
        final double pointLat = (p.lat as num).toDouble();
        final double pointLon = (p.lng as num).toDouble();
        return _haversineKm(spotLat, spotLon, pointLat, pointLon) <= radiusKm;
      });
    }

    return it.toList();
  }

  String _breadcrumbText() {
    final sea = _selectedSea.label;
    final region = _selectedRegion;
    final spot = _selectedSpot;
    final parts = ['총 포인트 목록 – $sea'];
    if (region != null) parts.add(region);
    if (spot != null) parts.add(spot);
    return parts.join(' > ');
  }
}

// ---------- Widgets ----------

class _TopFilters extends StatelessWidget {
  const _TopFilters({
    required this.seaLabel,
    required this.regionLabel,
    required this.spotLabel,
    required this.onTapSea,
    required this.onTapRegion,
    required this.onTapSpot,
  });

  final String seaLabel;
  final String regionLabel;
  final String spotLabel;
  final VoidCallback onTapSea;
  final VoidCallback onTapRegion;
  final VoidCallback onTapSpot;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _DropChip(label: seaLabel, onTap: onTapSea),
          const SizedBox(width: 8),
          _DropChip(label: regionLabel, onTap: onTapRegion),
          const SizedBox(width: 8),
          _DropChip(label: spotLabel, onTap: onTapSpot),
        ],
      ),
    );
  }
}

class _DropChip extends StatelessWidget {
  const _DropChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F7FC),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE1E6EF)),
          ),
          child: Row(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(width: 6),
              const Icon(Icons.expand_more, size: 18, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.labelOf,
    this.selected,
  });

  final String title;
  final List<T> options;
  final String Function(T) labelOf;
  final T? selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E7EE),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final o in options)
                    _SelectableChip(
                      label: labelOf(o),
                      selected: selected != null && selected == o,
                      onTap: () => Navigator.of(context).pop(o),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? const Color(0xFFEAF4FF) : Colors.white;
    final border = selected ? const Color(0xFFB6DAFF) : const Color(0xFFE4E6EB);
    final text = selected ? const Color(0xFF2A79FF) : Colors.black87;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),

          child: Text(
            label,
            style: TextStyle(color: text, fontWeight: FontWeight.w700),

          ),
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
      color: Colors.white.withOpacity(0.8),
      surfaceTintColor: Colors.transparent,
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
                    iconColor: Color(0xFF2A79FF),
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
