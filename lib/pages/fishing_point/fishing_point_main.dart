// lib/pages/fishing_point/fishing_point_main.dart
import 'package:flutter/material.dart';
import '../../routes.dart';
import '../../models/fishing_point.dart';

class FishingPointMainPage extends StatefulWidget {
  const FishingPointMainPage({super.key});

  @override
  State<FishingPointMainPage> createState() => _FishingPointMainPageState();
}

class _FishingPointMainPageState extends State<FishingPointMainPage> {
  static const _img =
      'https://images.unsplash.com/photo-1508182311256-e3f6b475a2e4?auto=format&fit=crop&w=1080&q=80';

  final List<FishingPoint> _points = [
    FishingPoint(
      id: '1',
      name: '삼목수문',
      location: '인천광역시 옹진군',
      distanceKm: 11.7,
      depthRange: '2.4~2.9m',
      species: ['넙치', '노래미', '붕장어', '우럭'],
      imageUrl: _img,
      lat: 37.449, lng: 126.597,
    ),
    FishingPoint(
      id: '2',
      name: '삼목수문 A구역',
      location: '인천광역시 옹진군',
      distanceKm: 12.3,
      depthRange: '2.0~2.6m',
      species: ['감성돔', '우럭', '볼락'],
      imageUrl: _img,
      lat: 37.451, lng: 126.599,
    ),
    FishingPoint(
      id: '3',
      name: '삼목수문 B구역',
      location: '인천광역시 옹진군',
      distanceKm: 10.8,
      depthRange: '2.8~3.3m',
      species: ['광어', '농어'],
      imageUrl: _img,
      lat: 37.447, lng: 126.595,
    ),
    FishingPoint(
      id: '4',
      name: '삼목수문 C구역',
      location: '인천광역시 옹진군',
      distanceKm: 9.6,
      depthRange: '2.2~2.7m',
      species: ['넙치', '우럭'],
      imageUrl: _img,
      lat: 37.446, lng: 126.593,
    ),
  ];

  bool _incheonSelected = true;

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
      ),
      body: SafeArea(
        child: ListView.separated(
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
                  style: TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.w600),
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
                  arguments: item, // ➜ 상세에서 FishingPoint 받음
                );
              },
            );
          },
        ),
      ),
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
  const _ChipButton({required this.label, required this.selected, required this.onTap});
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
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Text(label, style: TextStyle(color: text, fontWeight: FontWeight.w700)),
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
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
                    text: data.species.join(', '),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFFA6DBFF),
                        foregroundColor: const Color(0xFF0B6AAE),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
            child: const Icon(Icons.image_not_supported_outlined, size: 28, color: Colors.black38),
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
