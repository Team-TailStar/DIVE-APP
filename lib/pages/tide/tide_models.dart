import 'package:intl/intl.dart';

/// 하루 물때 데이터
class TideDay {
  final String dateRaw;   // e.g. "2025-7-21-월-6-27"
  final String regionName;
  final String areaId;
  final String mul;       // e.g. "12물"
  final String sun;       // "05:51/19:00"
  final String moon;      // "07:32/19:59"
  final List<TideEvent> events; // 최대 4개

  TideDay({
    required this.dateRaw,
    required this.regionName,
    required this.areaId,
    required this.mul,
    required this.sun,
    required this.moon,
    required this.events,
  });

  /// "2025-7-21-월-6-27" -> DateTime(2025,7,21)
  DateTime get date {
    final parts = dateRaw.split('-');
    // [yyyy, m, d, 요일, 음월, 음일] 형태
    final y = int.tryParse(parts[0]) ?? 1970;
    final m = int.tryParse(parts[1]) ?? 1;
    final d = int.tryParse(parts[2]) ?? 1;
    return DateTime(y, m, d);
  }

  String get sunrise {
    if (!sun.contains('/')) return '';
    final parts = sun.split('/');
    if (parts.isEmpty) return '';
    final v = parts[0].trim();
    return (v == '----') ? '' : v;
  }
  String get sunset {
    if (!sun.contains('/')) return '';
    final parts = sun.split('/');
    if (parts.length < 2) return '';
    final v = parts[1].trim();
    return (v == '----') ? '' : v;
  }
  /// 월출/월몰 분리
  String get moonrise {
    if (!moon.contains('/')) return '';
    final parts = moon.split('/');
    if (parts.isEmpty) return '';
    final v = parts[0].trim();
    return (v == '----') ? '' : v;
  }
  String get moonset {
    if (!moon.contains('/')) return '';
    final parts = moon.split('/');
    if (parts.length < 2) return '';
    final v = parts[1].trim();
    return (v == '----') ? '' : v;
  }
}

/// 간만조 이벤트(간조1/만조1/간조2/만조2)
class TideEvent {
  final String label; // "간조 1" / "만조 1" ...
  final String hhmm;  // "07:51"
  final double heightCm; // 괄호안 높이 cm
  final String type;     // "만조" or "간조"
  final double? delta;   // +83.5 같은 증감(있으면 표시)

  TideEvent({
    required this.label,
    required this.hhmm,
    required this.heightCm,
    required this.type,
    required this.delta,
  });


  String toAmPm() {
    try {
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day,
          int.parse(hhmm.substring(0, 2)), int.parse(hhmm.substring(3, 5)));
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return hhmm;
    }
  }

  static TideEvent? parse(String raw, {required String label}) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // 1) 시간: 문자열 어디에 있어도 허용 (00:32 포함)
    final t = RegExp(r'([0-2]?\d):([0-5]\d)').firstMatch(s);
    if (t == null) return null; // 시간 없으면 그때만 null
    final h = int.parse(t.group(1)!);
    final m = int.parse(t.group(2)!);
    final hhmm = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    // 2) 높이(cm): 괄호 안 첫 숫자. 없으면 0.0으로 처리(드문 응답 변형 대비)
    final hm = RegExp(r'\(([-+]?\d+(?:\.\d+)?)\)').firstMatch(s);
    final height = double.tryParse(hm?.group(1) ?? '') ?? 0.0;

    // 3) 만조/간조: ▲/▼. 없으면 기본 '만조'로 처리해 드랍 방지
    String kind = '만조';
    final am = RegExp(r'(▲|▼)').firstMatch(s);
    if (am != null) {
      kind = (am.group(1) == '▼') ? '간조' : '만조';
    }

    // 4) 증감: 마지막 +/-숫자. 없으면 null
    final dm = RegExp(r'([+\-]\d+(?:\.\d+)?)').allMatches(s).toList();
    double? delta;
    if (dm.isNotEmpty) {
      delta = double.tryParse(dm.last.group(1)!);
    }
    // print('PARSED -> [$raw] => $hhmm / $height / $kind / $delta');
    return TideEvent(
      label: label,
      hhmm: hhmm,
      heightCm: height,
      type: kind,
      delta: delta,
    );
  }


}
