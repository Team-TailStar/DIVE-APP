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

  /// 일출/일몰 분리
  String get sunrise => sun.contains('/') ? sun.split('/')[0] : '';
  String get sunset  => sun.contains('/') ? sun.split('/')[1] : '';

  /// 월출/월몰 분리
  String get moonrise => moon.contains('/') ? moon.split('/')[0] : '';
  String get moonset  => moon.contains('/') ? moon.split('/')[1] : '';
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

  /// "07:51" -> "07:51 AM" (로케일 독립적으로 AM/PM)
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

  /// 파서: "07:51 (136) ▲ +54" 형태
  static TideEvent? parse(String raw, {required String label}) {
    if (raw.trim().isEmpty) return null;

    // 시간
    final timeMatch = RegExp(r'(\d{2}:\d{2})').firstMatch(raw);
    final time = timeMatch?.group(1) ?? '';

    // 높이(cm)
    final heightMatch = RegExp(r'\((\-?\d+(?:\.\d+)?)\)').firstMatch(raw);
    final height = double.tryParse(heightMatch?.group(1) ?? '');

    // 만조/간조
    final arrowMatch = RegExp(r'(▲|▼)').firstMatch(raw);
    final arrow = arrowMatch?.group(1);
    final kind = (arrow == '▲') ? '만조' : '간조';

    // 증감(선택)
    final deltaMatch = RegExp(r'([+\-]\d+(?:\.\d+)?)').allMatches(raw).toList();
    // 맨 뒤 숫자를 증감으로 간주(예: -13, +83.5 …). 괄호안 높이와 중복될 수 있어 마지막 항목을 사용
    double? delta;
    if (deltaMatch.isNotEmpty) {
      final last = deltaMatch.last.group(1)!;
      // 괄호 속 높이 그대로 잡히는 케이스 방지: 괄호 뒤쪽 기호에 가깝게 매칭되므로 보통 OK
      delta = double.tryParse(last);
    }

    if (time.isEmpty || height == null || kind.isEmpty) return null;

    return TideEvent(
      label: label,
      hhmm: time,
      heightCm: height,
      type: kind,
      delta: delta,
    );
  }
}
