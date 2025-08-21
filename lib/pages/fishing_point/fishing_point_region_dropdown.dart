import 'package:flutter/material.dart';

class RegionItem {
  final String name;
  final double? lat;
  final double? lon;
  const RegionItem(this.name, this.lat, this.lon);
}

class RegionDropdownButton extends StatelessWidget {
  final List<RegionItem> regions;
  final RegionItem selected;
  final ValueChanged<RegionItem> onChanged;
  final EdgeInsets padding;
  final bool fullWidth;

  const RegionDropdownButton({
    super.key,
    required this.regions,
    required this.selected,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseBlue = Colors.blue.shade700;

    return PopupMenuButton<RegionItem>(
      itemBuilder: (context) => regions
          .map((r) => PopupMenuItem<RegionItem>(
        value: r,
        child: Text(
          r.name.isEmpty ? '(전체)' : r.name,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ))
          .toList(),
      onSelected: onChanged,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      constraints: const BoxConstraints(
        minWidth: 220,
        maxWidth: 320,
      ),
      padding: EdgeInsets.zero,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: padding,
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on_outlined, color: baseBlue, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                (selected.name.isEmpty ? '지역 선택' : selected.name),
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
    );
  }
}
