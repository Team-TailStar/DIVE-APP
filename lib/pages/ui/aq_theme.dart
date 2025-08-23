import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

@immutable
class AqCardTheme extends ThemeExtension<AqCardTheme> {
  // layout
  final double radius;
  final EdgeInsets padding;

  // colors
  final Color cardBg;
  final Color cardBorder;
  final Color tileBg;
  final Color tileBorder;
  final Color chipBg;
  final Color chipFg;
  final Color iconColor;

  // chip level colors
  final Color chipGoodBg;
  final Color chipGoodFg;
  final Color chipModerateBg;
  final Color chipModerateFg;
  final Color chipBadBg;
  final Color chipBadFg;
  final Color chipVeryBadBg;
  final Color chipVeryBadFg;

  // shadows
  final List<BoxShadow> cardShadows;
  final List<BoxShadow> tileShadows;

  // text
  final TextStyle titleStyle;
  final TextStyle subtitleStyle; // "서울"
  final TextStyle labelStyle;    // "미세먼지"
  final TextStyle metricStyle;   // "정보없음"
  final TextStyle unitStyle;     // "PM10"
  final TextStyle footnoteStyle; // "-";
  final TextStyle messageStyle;  // 하단 메시지

  const AqCardTheme({
    required this.radius,
    required this.padding,
    required this.cardBg,
    required this.cardBorder,
    required this.tileBg,
    required this.tileBorder,
    required this.chipBg,
    required this.chipFg,
    required this.iconColor,
    required this.chipGoodBg,
    required this.chipGoodFg,
    required this.chipModerateBg,
    required this.chipModerateFg,
    required this.chipBadBg,
    required this.chipBadFg,
    required this.chipVeryBadBg,
    required this.chipVeryBadFg,
    required this.cardShadows,
    required this.tileShadows,
    required this.titleStyle,
    required this.subtitleStyle,
    required this.labelStyle,
    required this.metricStyle,
    required this.unitStyle,
    required this.footnoteStyle,
    required this.messageStyle,
  });

   AqCardTheme._light()
      : radius = 16,
        padding = const EdgeInsets.all(12),
        cardBg = Colors.white,
        cardBorder = const Color(0xFFE9EEF3),
        tileBg = const Color(0xFFF7F9FC),
        tileBorder = const Color(0xFFE9EEF3),
        chipBg = const Color(0xFFEFF3F8),
        chipFg = Colors.black87,
        iconColor = Colors.black45,
  // level chips
        chipGoodBg = const Color(0xFFE8F5E9),
        chipGoodFg = const Color(0xFF1B5E20),
        chipModerateBg = const Color(0xFFFFF3E0),
        chipModerateFg = const Color(0xFF7A4F01),
        chipBadBg = const Color(0xFFFFEBEE),
        chipBadFg = const Color(0xFFB71C1C),
        chipVeryBadBg = const Color(0xFFFCE4EC),
        chipVeryBadFg = const Color(0xFF880E4F),
  // soft shadows
        cardShadows = const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 1)),
        ],
        tileShadows = const [
          BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 1)),
        ],
        titleStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
        subtitleStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
        labelStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
        metricStyle = const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
        unitStyle = const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black38),
        footnoteStyle = const TextStyle(fontSize: 12, color: Colors.black38),
        messageStyle = const TextStyle(fontSize: 12, color: Colors.black54);

  factory AqCardTheme.light() => AqCardTheme._light();

  @override
  AqCardTheme copyWith({
    double? radius,
    EdgeInsets? padding,
    Color? cardBg,
    Color? cardBorder,
    Color? tileBg,
    Color? tileBorder,
    Color? chipBg,
    Color? chipFg,
    Color? iconColor,
    Color? chipGoodBg,
    Color? chipGoodFg,
    Color? chipModerateBg,
    Color? chipModerateFg,
    Color? chipBadBg,
    Color? chipBadFg,
    Color? chipVeryBadBg,
    Color? chipVeryBadFg,
    List<BoxShadow>? cardShadows,
    List<BoxShadow>? tileShadows,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? labelStyle,
    TextStyle? metricStyle,
    TextStyle? unitStyle,
    TextStyle? footnoteStyle,
    TextStyle? messageStyle,
  }) {
    return AqCardTheme(
      radius: radius ?? this.radius,
      padding: padding ?? this.padding,
      cardBg: cardBg ?? this.cardBg,
      cardBorder: cardBorder ?? this.cardBorder,
      tileBg: tileBg ?? this.tileBg,
      tileBorder: tileBorder ?? this.tileBorder,
      chipBg: chipBg ?? this.chipBg,
      chipFg: chipFg ?? this.chipFg,
      iconColor: iconColor ?? this.iconColor,
      chipGoodBg: chipGoodBg ?? this.chipGoodBg,
      chipGoodFg: chipGoodFg ?? this.chipGoodFg,
      chipModerateBg: chipModerateBg ?? this.chipModerateBg,
      chipModerateFg: chipModerateFg ?? this.chipModerateFg,
      chipBadBg: chipBadBg ?? this.chipBadBg,
      chipBadFg: chipBadFg ?? this.chipBadFg,
      chipVeryBadBg: chipVeryBadBg ?? this.chipVeryBadBg,
      chipVeryBadFg: chipVeryBadFg ?? this.chipVeryBadFg,
      cardShadows: cardShadows ?? this.cardShadows,
      tileShadows: tileShadows ?? this.tileShadows,
      titleStyle: titleStyle ?? this.titleStyle,
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      labelStyle: labelStyle ?? this.labelStyle,
      metricStyle: metricStyle ?? this.metricStyle,
      unitStyle: unitStyle ?? this.unitStyle,
      footnoteStyle: footnoteStyle ?? this.footnoteStyle,
      messageStyle: messageStyle ?? this.messageStyle,
    );
  }

  @override
  AqCardTheme lerp(ThemeExtension<AqCardTheme>? other, double t) {
    if (other is! AqCardTheme) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AqCardTheme(
      radius: lerpDouble(radius, other.radius, t)!,
      padding: EdgeInsets.lerp(padding, other.padding, t)!,
      cardBg: c(cardBg, other.cardBg),
      cardBorder: c(cardBorder, other.cardBorder),
      tileBg: c(tileBg, other.tileBg),
      tileBorder: c(tileBorder, other.tileBorder),
      chipBg: c(chipBg, other.chipBg),
      chipFg: c(chipFg, other.chipFg),
      iconColor: c(iconColor, other.iconColor),
      chipGoodBg: c(chipGoodBg, other.chipGoodBg),
      chipGoodFg: c(chipGoodFg, other.chipGoodFg),
      chipModerateBg: c(chipModerateBg, other.chipModerateBg),
      chipModerateFg: c(chipModerateFg, other.chipModerateFg),
      chipBadBg: c(chipBadBg, other.chipBadBg),
      chipBadFg: c(chipBadFg, other.chipBadFg),
      chipVeryBadBg: c(chipVeryBadBg, other.chipVeryBadBg),
      chipVeryBadFg: c(chipVeryBadFg, other.chipVeryBadFg),
      cardShadows: (t < 0.5) ? cardShadows : other.cardShadows,
      tileShadows: (t < 0.5) ? tileShadows : other.tileShadows,
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t)!,
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t)!,
      labelStyle: TextStyle.lerp(labelStyle, other.labelStyle, t)!,
      metricStyle: TextStyle.lerp(metricStyle, other.metricStyle, t)!,
      unitStyle: TextStyle.lerp(unitStyle, other.unitStyle, t)!,
      footnoteStyle: TextStyle.lerp(footnoteStyle, other.footnoteStyle, t)!,
      messageStyle: TextStyle.lerp(messageStyle, other.messageStyle, t)!,
    );
  }
}
