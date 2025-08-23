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
  // ───────── 속도 개선: 세션 캐시 ─────────
  static Position? _posCache;
  static DateTime? _posCachedAt;

  static final Map<String, _CacheEntry<List<FishingPoint>>> _pointsCache = {};

  // 포인트 캐시 TTL
  static const _pointsTtl = Duration(minutes: 3);
  // 위치 캐시 TTL
  static const _posTtl = Duration(minutes: 5);
  // 정밀 보정 후 재요청 임계(킬로미터)
  static const _refetchDistanceKm = 0.3;

  String _regionTitle = '내 위치';

  double? _myLat;
  double? _myLon;

  SeaSpot? _selectedSpot;
  SeaSpot? _nearestSpot;

  bool _isFetching = false;

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
      // 선택 지역이 있으면 위치를 기다리지 않고 바로 진행
      if (_selectedSpot == null) {
        await _ensureLocationPermission();

        // 1) 가장 빠른 소스: lastKnownPosition
        Position? pos = await Geolocator.getLastKnownPosition();

        // 2) 세션 캐시도 신선하면 사용
        final now = DateTime.now();
        if (pos == null && _posCache != null && now.difference(_posCachedAt ?? now) < _posTtl) {
          pos = _posCache;
        }

        // 3) 그래도 없으면 저정확도 + 짧은 타임아웃 (첫 화면 빨리 뜨게)
        pos ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 3),
        );

        _myLat = pos.latitude;
        _myLon = pos.longitude;
        _posCache = pos;
        _posCachedAt = DateTime.now();

        // 근접 지점 갱신
        if (_myLat != null && _myLon != null) {
          _nearestSpot = _findNearestSpot(_myLat!, _myLon!);
        }
      }

      _updateTitle();

      // 포인트: 캐시 먼저 시도
      final lat = _queryLat;
      final lon = _queryLon;
      if (lat == null || lon == null) {
        throw Exception('질의 좌표가 없어요 (내 위치/선택 지역).');
      }

      final cached = _getPointsFromCache(lat, lon);
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _points = cached;
          _loading = false;
        });
      } else {
        await _fetchPoints(useCache: true);
      }

      // 백그라운드 정밀 위치 보정 (선택 지역이 없을 때만 의미)
      if (_selectedSpot == null) {
        _refreshPrecisePositionInBackground();
      }
    } catch (e) {
      if (!mounted) return;
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
    if (!mounted) return;
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

  // ───────── 캐시 유틸 ─────────
  String _tileKey(double lat, double lon) {
    double r(double v) => (v * 1000).roundToDouble() / 1000; // 소수점 3자리(≈110m)
    return '${r(lat)},${r(lon)}';
  }

  List<FishingPoint>? _getPointsFromCache(double lat, double lon) {
    final e = _pointsCache[_tileKey(lat, lon)];
    if (e == null) return null;
    if (DateTime.now().difference(e.at) > _pointsTtl) return null;
    return e.value;
  }

  void _savePointsToCache(double lat, double lon, List<FishingPoint> pts) {
    _pointsCache[_tileKey(lat, lon)] = _CacheEntry(pts, DateTime.now());
  }

  Future<void> _fetchPoints({bool useCache = true}) async {
    if (_isFetching) return; // 중복 요청 방지
    _isFetching = true;

    try {
      final lat = _queryLat;
      final lon = _queryLon;
      if (lat == null || lon == null) {
        throw Exception('질의 좌표가 없어요 (내 위치/선택 지역).');
      }

      if (useCache) {
        final cached = _getPointsFromCache(lat, lon);
        if (cached != null) {
          if (!mounted) return;
          setState(() {
            _points = cached;
            _loading = false;
          });
          _isFetching = false;
          return;
        }
      }

      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
        });
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

      _savePointsToCache(lat, lon, parsed);

      if (!mounted) return;
      setState(() {
        _points = parsed;
        _loading = false;
      });

      // 웨어 전송
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
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러오지 못했어요. ${e.toString()}';
        _loading = false;
      });
    } finally {
      _isFetching = false;
    }
  }

  // 정밀 위치 백그라운드 보정
  Future<void> _refreshPrecisePositionInBackground() async {
    try {
      final precise = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 6),
      );

      if (precise.latitude == _myLat && precise.longitude == _myLon) return;

      final oldLat = _myLat;
      final oldLon = _myLon;

      _myLat = precise.latitude;
      _myLon = precise.longitude;
      _posCache = precise;
      _posCachedAt = DateTime.now();
      _nearestSpot = _findNearestSpot(_myLat!, _myLon!);

      // 많이 움직였을 때만 재요청
      final movedKm = (oldLat == null || oldLon == null)
          ? double.infinity
          : _haversineKm(oldLat, oldLon, _myLat!, _myLon!);

      if (movedKm > _refetchDistanceKm) {
        _updateTitle();
        await _fetchPoints(useCache: true);
      }
    } catch (_) {
      // 조용히 무시 (백그라운드 보정 실패 허용)
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
                  // 열 때는 마지막 선택값(없으면 근접값) 그대로 보여주기
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
      _updateTitle();
      await _fetchPoints(useCache: true);
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
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: '지역 선택',
          icon: const Icon(Icons.location_on, color: Colors.redAccent), // ← 빨간 핀
          onPressed: _openRegionTopSheet,
        ),
        title: Text(
          _regionTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              if (_selectedSpot == null) {
                // 내 위치 기준: 정밀 위치 먼저 시도하고 결과에 따라 재조회
                await _refreshPrecisePositionInBackground();
              }
              if (_queryLat != null && _queryLon != null) {
                await _fetchPoints(useCache: true);
              } else {
                await _init();
              }
            },
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
                // ← 지역 선택 칩 제거됨
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
                        separatorBuilder: (_, __) =>
                        const SizedBox(height: 16),
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

// 공용 위젯들 ---------------------------------------------------------------

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
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w700)),
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
              borderSide:
              const BorderSide(color: Color(0xFF7C66D6), width: 1.2),
            ),
          ),
        ),
      ],
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
          // 빠르게 보이도록 오류 시 즉시 대체
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFEFF3F8),
            alignment: Alignment.center,
            child: const Icon(Icons.image_not_supported_outlined,
                size: 28, color: Colors.black38),
          ),
          gaplessPlayback: true,
          // 네이티브 캐시를 활용 (네트워크 라이브러리 기본 캐시 사용)
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

  late String _region;     // 현재 표시 중인 지역(시/도)
  late List<SeaSpot> _names; // 현재 지역의 지점 목록
  SeaSpot? _nameSel;       // 현재 선택 지점

  @override
  void initState() {
    super.initState();
    _all = kWestSeaSpots.where((s) => s.lat != null && s.lon != null).toList();

    _regions = { for (final s in _all) s.region.trim() }.toList()..sort();

    // 열 때: 마지막 선택값(없으면 근접값) → 그대로 보여주기
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
    // 리스트 다이얼로그: 항상 0번부터 시작 (선택값 위치로 스크롤 안 함)
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
            decoration: BoxDecoration(
              color: Colors.black12, borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text('지역 선택',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),

          // ▶ 표시용 입력칸 (read-only) — 탭하면 우리 커스텀 리스트가 뜸
          _PickerField(
            label: '지역 (시/도)',
            valueText: _region.isEmpty ? '선택' : _region,
            onTap: _openRegionPicker,
          ),
          const SizedBox(height: 12),

          _PickerField(
            label: '지점',
            valueText: _nameSel?.name ?? '선택',
            onTap: _openNamePicker,
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF42A5F5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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

/// 공용: 항상 맨 위에서 시작하는 리스트 다이얼로그
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
      // ▼ 추가: 다이얼로그 배경 화이트
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        // ▼ 추가: 내부도 확실히 화이트
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              Center(child: Text(title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
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

/// 표기용 read-only 필드
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
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w700)),
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

class _CacheEntry<T> {
  final T value;
  final DateTime at;
  _CacheEntry(this.value, this.at);
}
