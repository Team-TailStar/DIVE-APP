import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../app_bottom_nav.dart';
import '../../env.dart';
import '../../models/fishing_point.dart';
import '../../routes.dart';
import '../../wear_bridge.dart';

import 'fishing_point_region.dart'; // SeaSpot, kWestSeaSpots

class FishingPointMainPage extends StatefulWidget {
  const FishingPointMainPage({super.key});

  @override
  State<FishingPointMainPage> createState() => _FishingPointMainPageState();
}

class _FishingPointMainPageState extends State<FishingPointMainPage> {
  String _regionTitle = '내 위치';

  double? _myLat;
  double? _myLon;

  SeaSpot? _selectedSpot;

  SeaSpot? _nearestSpot;

  double? get _queryLat => _selectedSpot?.lat ?? _myLat;
  double? get _queryLon => _selectedSpot?.lon ?? _myLon;

  static const _fallbackImg =
      'https://images.unsplash.com/photo-1508182311256-e3f6b475a2e4?auto=format&fit=crop&w=1080&q=80';

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

      _nearestSpot = _findNearestSpot(_myLat!, _myLon!);
      _updateTitle();

      await _fetchPoints();
    } catch (e) {
      setState(() {
        _error = '현재 위치를 가져오지 못했어요. 위치 권한을 허용해 주세요.\n${e.toString()}';
        _loading = false;
      });
    }
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

  void _updateTitle() {
    setState(() {
      if (_selectedSpot != null) {
        _regionTitle = _formatSpotLabel(_selectedSpot!);
      } else if (_nearestSpot != null) {
        _regionTitle = _formatSpotLabel(_nearestSpot!);
      } else {
        _regionTitle = '내 위치';
      }
    });
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

  String _formatSpotLabel(SeaSpot s) {
    final sg = (s.subregion != null && s.subregion!.isNotEmpty)
        ? ' ${s.subregion}'
        : '';
    return '${s.region}$sg · ${s.name}';
  }

  Uri _buildApiUri(double lat, double lon) => Uri.parse(
    '${Env.API_BASE_URL}/point?lat=$lat&lon=$lon&key=${Env.BADA_SERVICE_KEY}',
  );

  Future<void> _fetchPoints() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final lat = _queryLat;
      final lon = _queryLon;
      if (lat == null || lon == null) {
        throw Exception('질의 좌표가 없어요 (내 위치/선택 지역).');
      }

      final res = await http.get(_buildApiUri(lat, lon));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list =
      (body['fishing_point'] as List).cast<Map<String, dynamic>>();

      final parsed = list.map<FishingPoint>(_toModel).toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      setState(() {
        _points = parsed;
        _loading = false;
      });

      await WearBridge.sendFishingPoints(parsed
          .map((p) => {
        'name': p.name,
        'point_nm': p.name,
        'dpwt': p.depthRange,
        'material': '',
        'tide_time': '',
        'target': p.species.join(','),
        'lat': p.lat,
        'lon': p.lng, // 모델이 lon이면 p.lon
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
    final p = (raw ?? '').trim();
    if (p.isEmpty) return fallback;
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    var base = Env.BDAD_TIME_IMAGE_URL;
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final right = p.startsWith('/') ? p.substring(1) : p;
    return '$base/$right';
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

    final baseLat = _queryLat ?? 0.0;
    final baseLon = _queryLon ?? 0.0;
    final dist = _haversineKm(baseLat, baseLon, lat, lon);

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

  Future<void> _openRegionTopSheet() async {
    final selected = await showGeneralDialog<SeaSpot>(
      context: context,
      barrierLabel: '지역 선택',
      barrierDismissible: true,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        final media = MediaQuery.of(context);
        final topMargin = media.padding.top + kToolbarHeight + 8; // 앱바 아래쪽

        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: EdgeInsets.fromLTRB(16, topMargin, 16, 0),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                constraints: BoxConstraints(
                  maxWidth: 640, // 태블릿 대응
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
                  initialSelected: _selectedSpot,
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
          position: Tween<Offset>(begin: const Offset(0, -0.12), end: Offset.zero)
              .animate(a),
          child: FadeTransition(opacity: a, child: child),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedSpot = selected;
        _nearestSpot = null; // 수동 선택 후 자동 라벨 해제
      });
      _updateTitle();
      await _fetchPoints();
    }
  }



  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
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
            padding: EdgeInsets.fromLTRB(16, topPad + kToolbarHeight, 16, 0),
            child: Column(
              children: [
                _RegionChipButton(
                  label: _selectedSpot == null
                      ? '지역 선택'
                      : _formatSpotLabel(_selectedSpot!),
                  onTap: _openRegionTopSheet, // ← 여기!
                ),
                const SizedBox(height: 12),

                // 리스트
                Expanded(
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
                      if (_points.isEmpty) {
                        return const Center(
                          child: Text(
                            '근처 포인트가 없어요.',
                            style:
                            TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                        itemCount: _points.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final item = _points[index];
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
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}


class _Dd<T> extends StatelessWidget {
  const _Dd({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          borderRadius: BorderRadius.circular(14),
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF5F7FB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE9ECF1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE9ECF1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF7C66D6), width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}


class _RegionChipButton extends StatelessWidget {
  const _RegionChipButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final baseBlue = Colors.blue.shade700;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.28),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.location_on_outlined, color: baseBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.keyboard_arrow_down_rounded, color: baseBlue, size: 20),
            ],
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
  late String _region;
  String? _subregion;
  late List<SeaSpot> _names;
  SeaSpot? _nameSel;

  @override
  void initState() {
    super.initState();
    _all = kWestSeaSpots.where((s) => s.lat != null && s.lon != null).toList();

    _regions = {
      for (final s in _all) s.region.trim(),
    }.toList()
      ..sort();

    _region = widget.initialSelected?.region ??
        widget.nearestSpot?.region ??
        (_regions.isNotEmpty ? _regions.first : '');

    _subregion = widget.initialSelected?.subregion ?? widget.nearestSpot?.subregion;

    _names = _namesSource(_region, _subregion);
    _nameSel = widget.initialSelected ?? (_names.isNotEmpty ? _names.first : null);
  }

  List<SeaSpot> _namesSource(String r, String? sr) => _all
      .where((s) => s.region == r && (sr == null ? true : s.subregion == sr))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  List<String?> _subregions(String r) => {
    for (final s in _all.where((s) => s.region == r)) s.subregion
  }.toList()
    ..sort((a, b) => (a ?? '').compareTo(b ?? ''));

  void _onChangeRegion(String r) {
    setState(() {
      _region = r;
      final subs = _subregions(_region);
      _subregion = subs.contains(_subregion) ? _subregion : (subs.isNotEmpty ? subs.first : null);
      _names = _namesSource(_region, _subregion);
      _nameSel = _names.isNotEmpty ? _names.first : null;
    });
  }

  void _onChangeSubregion(String? sr) {
    setState(() {
      _subregion = sr;
      _names = _namesSource(_region, _subregion);
      _nameSel = _names.isNotEmpty ? _names.first : null;
    });
  }

  void _onChangeName(SeaSpot v) => setState(() => _nameSel = v);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54, height: 5, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.black12, borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text('지역 선택', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),

          _Dd<String>(
            label: 'Region (시/도)',
            value: _region,
            items: _regions
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) { if (v != null) _onChangeRegion(v); },
          ),
          const SizedBox(height: 12),

          _Dd<String?>(
            label: 'Subregion (시/군/구)',
            value: _subregion,
            items: _subregions(_region)
                .map((e) => DropdownMenuItem<String?>(
              value: e, child: Text(e ?? '전체'),
            ))
                .toList(),
            onChanged: _onChangeSubregion,
          ),
          const SizedBox(height: 12),

          _Dd<SeaSpot>(
            label: 'Name (지점)',
            value: _nameSel,
            items: _names
                .map((e) => DropdownMenuItem<SeaSpot>(value: e, child: Text(e.name)))
                .toList(),
            onChanged: (v) { if (v != null) _onChangeName(v); },
          ),
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
