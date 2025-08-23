// lib/pages/sea_weather/region_picker.dart
import 'package:flutter/material.dart';

/// 앱 전체에서 쓰는 지역 모델
class RegionItem {
  final String name;
  final double lat;
  final double lon;
  const RegionItem(this.name, this.lat, this.lon);
}

/// 예시 데이터 (실제 리스트로 대체/확장)
const List<RegionItem> kRegions = [
  RegionItem('경기북부', 37.9, 126.3),
  RegionItem('경기남부', 37.1, 126.4),
  RegionItem('충남북부', 36.9, 126.2),
  RegionItem('충남남부', 36.2, 126.4),
  RegionItem('전북북부', 35.8, 126.3),
  RegionItem('전북남부', 35.5, 126.5),
  RegionItem('전남북부서해', 35.1, 126.3),
  RegionItem('전남중부서해', 34.7, 126.2),
  RegionItem('전남남부서해', 34.3, 126.0),

  // 남해
  RegionItem('전남서부남해', 34.4, 126.5),
  RegionItem('전남동부남해', 34.7, 127.5),
  RegionItem('경남서부남해', 34.8, 128.3),
  RegionItem('경남중부남해', 35.0, 128.6),

  // 제주
  RegionItem('제주도서부', 33.3, 126.0),
  RegionItem('제주도북부', 33.7, 126.5),
  RegionItem('제주도남부', 33.1, 126.6),
  RegionItem('제주도동부', 33.4, 127.0),

  // 동해
  RegionItem('경북북부', 36.6, 129.5),
  RegionItem('경북남부', 35.9, 129.5),
  RegionItem('강원북부', 38.2, 128.6),
  RegionItem('강원중부', 37.7, 128.9),
  RegionItem('강원남부', 37.4, 129.2),

  // 광역시
  RegionItem('울산광역시', 35.5, 129.4),
  RegionItem('부산광역시', 35.1151, 129.0415),
];

/// 앱바 위치 아이콘에서 호출:
/// final picked = await rp.showRegionPicker(context, initialName: _region?.name);
Future<RegionItem?> showRegionPicker(
    BuildContext context, {
      String? initialName,
      List<RegionItem>? regions,
    }) {
  // 공통 스타일(모서리, 보더) — 다이얼로그/드롭다운/버튼 통일
  const double kRadius = 14;
  const BorderSide kBorder = BorderSide(color: Color(0x22000000), width: 1);

  final list = List<RegionItem>.from(regions ?? kRegions)
    ..sort((a, b) => a.name.compareTo(b.name));

  RegionItem? initial;
  if (initialName != null) {
    for (final r in list) {
      if (r.name == initialName) {
        initial = r;
        break;
      }
    }
  }
  initial ??= list.isNotEmpty ? list.first : null;

  // 위에서 "살짝" 떨어져 내려오는 Top-Sheet 느낌
  return showGeneralDialog<RegionItem>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '지역 선택',
    barrierColor: Colors.black.withOpacity(0.15),
    transitionDuration: const Duration(milliseconds: 170),
    pageBuilder: (ctx, _, __) {
      final pad = MediaQuery.of(ctx).padding;
      final topGap = pad.top + kToolbarHeight + 8; // AppBar 바로 아래
      final viewInsets = MediaQuery.of(ctx).viewInsets.bottom;

      return SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, topGap, 12, 12 + viewInsets),
            child: Material(
              color: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kRadius),
                side: kBorder,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: _RegionTopSheet(
                      regions: list,
                      initial: initial,
                      kRadius: kRadius,
                      kBorder: kBorder,
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton(
                      tooltip: '닫기',
                      icon: const Icon(Icons.close_rounded, color: Colors.black54),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, a, __, child) {
      final anim = CurvedAnimation(
        parent: a,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -0.08), end: Offset.zero)
            .animate(anim),
        child: FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(anim),
            child: child,
          ),
        ),
      );
    },
  );
}

class _RegionTopSheet extends StatefulWidget {
  final List<RegionItem> regions;
  final RegionItem? initial;
  final double kRadius;
  final BorderSide kBorder;

  const _RegionTopSheet({
    required this.regions,
    required this.initial,
    required this.kRadius,
    required this.kBorder,
  });

  @override
  State<_RegionTopSheet> createState() => _RegionTopSheetState();
}

class _RegionTopSheetState extends State<_RegionTopSheet> {
  RegionItem? _selected;

  // 드롭다운이 항상 아래로만 열리도록 남은 높이 계산
  final GlobalKey _fieldKey = GlobalKey();
  double _menuMaxHeight = 280;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalcMenuHeight());
  }

  void _recalcMenuHeight() {
    final ctx = _fieldKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (ctx == null || box == null || !box.hasSize) return;

    final screenH  = MediaQuery.of(ctx).size.height;
    final insets   = MediaQuery.of(ctx).viewInsets.bottom; // 키보드 높이
    final fieldBot = box.localToGlobal(Offset.zero).dy + box.size.height;

    // 아래 남은 공간만큼으로 메뉴 높이 제한 → 위로 뒤집히지 않음
    final available = (screenH - insets - fieldBot - 12);
    final safe = available.clamp(60.0, 420.0).toDouble();   // 너무 작을 때 하한 60

    if ((_menuMaxHeight - safe).abs() > 1) {
      setState(() => _menuMaxHeight = safe);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 회전/키보드/레이아웃 변화 이후에도 재계산
    WidgetsBinding.instance.addPostFrameCallback((_) => _recalcMenuHeight());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 핸들
        Container(
          width: 44,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const Text('지역 선택',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),

        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '지역',
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),

        Theme(
          data: Theme.of(context).copyWith(canvasColor: Colors.white),
          child: DropdownButtonFormField<RegionItem>(
            key: _fieldKey,            // 위치 계산용
            value: null,               // ✅ 항상 null → 메뉴는 맨 위부터
            hint: Text(                // ✅ 닫힌 상태에 현재 선택값을 표시
              _selected?.name ?? '지역',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            isExpanded: true,
            dropdownColor: Colors.white,
            items: widget.regions
                .map((r) => DropdownMenuItem<RegionItem>(
              value: r,
              child: Text(
                r.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ))
                .toList(),
            onChanged: (v) => setState(() => _selected = v),
            menuMaxHeight: _menuMaxHeight, // ✅ 항상 아래로, 내부 스크롤
            decoration: InputDecoration(
              hintText: '지역',
              filled: true,
              fillColor: Colors.white,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.kRadius),
                borderSide: widget.kBorder,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.kRadius),
                borderSide: widget.kBorder,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(widget.kRadius),
                borderSide: widget.kBorder,
              ),
            ),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.blue.shade700),
          ),
        ),

        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5EA2FF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(widget.kRadius),
                side: widget.kBorder,
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w900),
            ),
            child: const Text('적용'),
          ),
        ),
      ],
    );
  }
}
