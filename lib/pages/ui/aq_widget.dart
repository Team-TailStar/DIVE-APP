import 'package:flutter/material.dart';
import 'package:dive_app/pages/ui/aq_theme.dart';

AqCardTheme _aq(BuildContext c) =>
    Theme.of(c).extension<AqCardTheme>() ?? AqCardTheme.light();

enum AqLevel { good, moderate, bad, veryBad, unknown }

Color _chipBgOf(AqCardTheme th, AqLevel lv) {
  switch (lv) {
    case AqLevel.good: return th.chipGoodBg;
    case AqLevel.moderate: return th.chipModerateBg;
    case AqLevel.bad: return th.chipBadBg;
    case AqLevel.veryBad: return th.chipVeryBadBg;
    case AqLevel.unknown: return th.chipBg;
  }
}

Color _chipFgOf(AqCardTheme th, AqLevel lv) {
  switch (lv) {
    case AqLevel.good: return th.chipGoodFg;
    case AqLevel.moderate: return th.chipModerateFg;
    case AqLevel.bad: return th.chipBadFg;
    case AqLevel.veryBad: return th.chipVeryBadFg;
    case AqLevel.unknown: return th.chipFg;
  }
}

class AqCard extends StatelessWidget {
  final Widget child;
  final Widget? title;
  final Widget? trailing;   // 우상단 액션(리프레시/아이콘)
  final String? subtitle;   // "서울"
  final EdgeInsetsGeometry? padding;
  final double? radius;

  const AqCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.subtitle,
    this.padding,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final th = _aq(context);
    final r = BorderRadius.circular(16);

    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: r,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (title != null)
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: th.titleStyle,
                      child: title!,
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: th.subtitleStyle),
            ],
            const SizedBox(height: 10),
          ],
          child,
        ],
      ),
    );
  }
}

class AqMetricTile extends StatelessWidget {
  final String label;          // "미세먼지"
  final String unit;           // "PM10"
  final String metricText;     // "좋음 / 보통 / 정보없음"
  final String footnote;       // 농도값 or "-"
  final AqLevel level;         // 색상 칩 레벨
  const AqMetricTile({
    super.key,
    required this.label,
    required this.unit,
    required this.metricText,
    required this.footnote,
    this.level = AqLevel.unknown,
  });

  @override
  Widget build(BuildContext context) {
    final th = _aq(context);
    return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE7F5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: th.labelStyle)),
              Text(unit, style: th.unitStyle),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _chipBgOf(th, level).withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFDCE7F5)),
            ),
            child: Text(
              metricText,
              style: th.metricStyle.copyWith(color: _chipFgOf(th, level)),
            ),
          ),
          const SizedBox(height: 6),
          Text(footnote, style: th.footnoteStyle),
        ],
      ),
    );
  }
}

class AqMetricGrid extends StatelessWidget {
  final List<Widget> tiles; // 2x2 고정 배치 예상
  const AqMetricGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      children: tiles,
    );
  }
}

class AqMessage extends StatelessWidget {
  final String text;
  const AqMessage(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final th = _aq(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(child: Text(text, style: th.messageStyle)),
    );
  }
}

/// -------- 재사용 가능한 “큰 카드 + 2x2 타일 + 메시지” 컴포넌트 --------
class AqMetricData {
  final String label;
  final String unit;
  final String gradeText; // 칩 안의 텍스트 (예: "좋음")
  final String footnote;  // 예: "19 μg/m³" / "0.019 ppm"
  final AqLevel level;
  const AqMetricData({
    required this.label,
    required this.unit,
    required this.gradeText,
    required this.footnote,
    this.level = AqLevel.unknown,
  });
}

class AqMetricGridCard extends StatelessWidget {
  final Widget? title;
  final String? subtitle;
  final Widget? trailing;
  final List<AqMetricData> metrics; // 1~4개 권장
  final String? message;            // 하단 문장

  const AqMetricGridCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.metrics,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AqCard(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AqMetricGrid(
            tiles: metrics.map((m) => AqMetricTile(
              label: m.label,
              unit: m.unit,
              metricText: m.gradeText,
              footnote: m.footnote,
              level: m.level,
            )).toList(),
          ),
          if (message != null) AqMessage(message!),
        ],
      ),
    );
  }
}
