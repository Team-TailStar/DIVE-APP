// lib/pages/weather/weather_models.dart
import 'package:intl/intl.dart';
import 'sky_icon_mapper.dart';

DateTime _parseYmdt10(String s) {
  if (s.length < 10) return DateTime.now();
  final y = int.parse(s.substring(0, 4));
  final m = int.parse(s.substring(4, 6));
  final d = int.parse(s.substring(6, 8));
  final h = int.parse(s.substring(8, 10));
  return DateTime(y, m, d, h);
}

dynamic _firstOf(Map j, List<String> keys) {
  // 제로폭/BOM 방어
  Map<String, dynamic> norm = {};
  j.forEach((k, v) {
    final nk = k.toString().replaceAll(RegExp(r'[\u200B-\u200F\uFEFF]'), '');
    norm[nk] = v;
  });
  for (final k in keys) {
    if (j.containsKey(k)) return j[k];
    if (norm.containsKey(k)) return norm[k];
  }
  return null;
}

double _d(dynamic v, {double def = 0}) {
  if (v == null) return def;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty) return def;
  return double.tryParse(s) ?? def;
}

int _i(dynamic v, {int def = 0}) {
  if (v == null) return def;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return def;
  return int.tryParse(s) ?? def;
}

class NowHead {
  final String fcastYmdt;
  final String type;
  NowHead({required this.fcastYmdt, required this.type});
  factory NowHead.fromJson(Map<String, dynamic> j) => NowHead(
    fcastYmdt: (_firstOf(j, ['fcastYmdt']) ?? '').toString(),
    type: (_firstOf(j, ['type']) ?? '').toString(),
  );
}

class NowItem {
  final DateTime time;   // YYYYMMDDHH
  final String sky;
  final String skyCode;
  final double rainMm;   // 1시간 강수량(mm)  ← forecast의 rainAmt
  final double tempC;
  final String windDir;  // 8방위
  final double windSpd;  // m/s
  final double waveHt;   // m
  final double humidity; // %

  NowItem({
    required this.time,
    required this.sky,
    required this.skyCode,
    required this.rainMm,
    required this.tempC,
    required this.windDir,
    required this.windSpd,
    required this.waveHt,
    required this.humidity,
  });

  factory NowItem.fromJson(Map<String, dynamic> j) {
    // 시간: aplYmdt(기존) 또는 ymdt(forecast)
    final apl = _firstOf(j, ['aplYmdt'])?.toString() ?? '';
    final ymdt = _firstOf(j, ['ymdt'])?.toString() ?? '';
    final time = _parseYmdt10(apl.isNotEmpty ? apl : ymdt);

    // 하늘 코드: sky_code 또는 skycode
    final skyCode = (_firstOf(j, ['sky_code', 'skycode']) ?? '').toString();

    // 강수량: forecast는 rain(확률%), rainAmt(강수량 mm)
    final rainMm = _d(_firstOf(j, ['rainAmt', '﻿rainAmt', 'rainMm', 'rain_mm']), def: 0);

    // 파고: waveHt 또는 pago(옛 키)
    final waveHt = _d(_firstOf(j, ['waveHt', 'pago', '﻿﻿﻿﻿waveHt']), def: 0);

    return NowItem(
      time: time,
      sky: (_firstOf(j, ['sky']) ?? '').toString(),
      skyCode: skyCode,
      rainMm: rainMm,
      tempC: _d(_firstOf(j, ['temp', '﻿temp']), def: 0),
      windDir: (_firstOf(j, ['winddir']) ?? '').toString(),
      windSpd: _d(_firstOf(j, ['windspd', '﻿﻿windspd']), def: 0),
      waveHt: waveHt,
      humidity: _d(_firstOf(j, ['humidity', '﻿﻿humidity']), def: 0),
    );
  }
}

class NowResponse {
  final NowHead head;
  final List<NowItem> items;
  final String? city;
  final String? cityCode;
  NowResponse({required this.head, required this.items, this.city, this.cityCode});

  factory NowResponse.fromJson(Map<String, dynamic> j) {
    final head = NowHead.fromJson((j['head'] ?? {}) as Map<String, dynamic>);
    final body = (j['body'] ?? {}) as Map<String, dynamic>;
    final List list = (body['weather'] ?? const []) as List;
    final info = (body['info'] ?? {}) as Map<String, dynamic>;
    return NowResponse(
      head: head,
      items: list.map((e) => NowItem.fromJson(e as Map<String, dynamic>)).toList(),
      city: info['city']?.toString(),
      cityCode: info['cityCode']?.toString(),
    );
  }
}

class Day7Item {
  final DateTime time;   // 3시간 간격
  final String sky;
  final String skyCode;
  final int rainProb;      // %  ← forecast의 rain
  final double rainAmtMm;  // mm ← forecast의 rainAmt
  final double tempC;      // ℃
  final int humidity;      // %
  final String windDir;    // 8방위
  final double windSpd;    // m/s
  final double wavePrd;    // s
  final double waveHt;     // m
  final String waveDir;    // 16방위

  Day7Item({
    required this.time,
    required this.sky,
    required this.skyCode,
    required this.rainProb,
    required this.rainAmtMm,
    required this.tempC,
    required this.humidity,
    required this.windDir,
    required this.windSpd,
    required this.wavePrd,
    required this.waveHt,
    required this.waveDir,
  });

  factory Day7Item.fromJson(Map<String, dynamic> j) {
    // 시간: aplYmdt(기존) 또는 ymdt(forecast)
    final apl = _firstOf(j, ['aplYmdt'])?.toString() ?? '';
    final ymdt = _firstOf(j, ['ymdt'])?.toString() ?? '';
    final time = _parseYmdt10(apl.isNotEmpty ? apl : ymdt);

    return Day7Item(
      time: time,
      sky: (_firstOf(j, ['sky']) ?? '').toString(),
      skyCode: (_firstOf(j, ['sky_code', 'skycode']) ?? '').toString(),
      rainProb: _i(_firstOf(j, ['rain'])),
      rainAmtMm: _d(_firstOf(j, ['rainAmt', '﻿rainAmt'])),
      tempC: _d(_firstOf(j, ['temp', '﻿temp'])),
      humidity: _i(_firstOf(j, ['humidity', '﻿﻿humidity'])),
      windDir: (_firstOf(j, ['winddir']) ?? '').toString(),
      windSpd: _d(_firstOf(j, ['windspd', '﻿﻿windspd'])),
      wavePrd: _d(_firstOf(j, ['wavePrd', '﻿﻿﻿wavePrd'])),
      waveHt: _d(_firstOf(j, ['waveHt', 'pago', '﻿﻿﻿﻿waveHt'])),
      waveDir: (_firstOf(j, ['waveDir']) ?? '').toString(),
    );
  }
}
