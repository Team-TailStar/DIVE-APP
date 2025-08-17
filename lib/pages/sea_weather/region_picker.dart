import 'package:flutter/material.dart';

class RegionItem {
  final String name;
  final double lat;
  final double lon;
  const RegionItem(this.name, this.lat, this.lon);
}
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

/// 바텀시트 지역 선택기
Future<RegionItem?> showRegionPicker(
    BuildContext context, {
      String? initialName,
    }) {
  return showModalBottomSheet<RegionItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      String q = '';
      return StatefulBuilder(
        builder: (context, setState) {
          final items = kRegions.where((r) => r.name.contains(q)).toList();

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text('지역 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  autofocus: true,
                  onChanged: (t) => setState(() => q = t.trim()),
                  decoration: InputDecoration(
                    hintText: '지역명 검색',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 3.2,
                    ),
                    itemBuilder: (_, i) {
                      final r = items[i];
                      final selected = r.name == initialName;
                      return InkWell(
                        onTap: () => Navigator.pop(context, r),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE9F5FF)
                                : Colors.white,
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF79A7FF)
                                  : const Color(0xFFDEE6EE),
                              width: selected ? 1.6 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (selected) ...[
                                const Icon(Icons.check, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: Text(
                                  r.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
