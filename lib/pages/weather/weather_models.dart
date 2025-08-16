import 'package:intl/intl.dart';
import 'sky_icon_mapper.dart';

class NowHead {
  final String fcastYmdt;
  final String type;
  NowHead({required this.fcastYmdt, required this.type});
  factory NowHead.fromJson(Map<String, dynamic> j) =>
      NowHead(fcastYmdt: j['fcastYmdt'] ?? '', type: j['type'] ?? '');
}

class NowItem {
  final DateTime time;   // aplYmdt → YYYYMMDDHH
  final String sky;
  final String skyCode;
  final double rainMm;   // 1시간 강수량
  final double tempC;
  final String windDir;  // 8방위
  final double windSpd;  // m/s
  final double waveHt;   // m (pago)
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

  static DateTime _parseApl(String s) {
    if (s.length < 10) return DateTime.now();
    final y = int.parse(s.substring(0, 4));
    final m = int.parse(s.substring(4, 6));
    final d = int.parse(s.substring(6, 8));
    final h = int.parse(s.substring(8, 10));
    return DateTime(y, m, d, h);
  }

  factory NowItem.fromJson(Map<String, dynamic> j) {
    double _d(dynamic v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;
    return NowItem(
      time: _parseApl(j['aplYmdt'] ?? ''),
      sky: j['sky'] ?? '',
      skyCode: j['sky_code']?.toString() ?? '',
      rainMm: _d(j['rain']),
      tempC: _d(j['temp']),
      windDir: j['winddir'] ?? '',
      windSpd: _d(j['windspd']),
      waveHt: _d(j['pago']),
      humidity: _d(j['humidity']),
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
    final head = NowHead.fromJson(j['head'] ?? {});
    final body = j['body'] ?? {};
    final List items = body['weather'] ?? [];
    final info = body['info'] ?? {};
    return NowResponse(
      head: head,
      items: items.map((e) => NowItem.fromJson(e as Map<String, dynamic>)).toList(),
      city: info['city'],
      cityCode: info['cityCode'],
    );
  }
}

class Day7Item {
  final DateTime time;   // 3시간 간격
  final String sky;
  final String skyCode;
  final int rainProb;      // %
  final double rainAmtMm;  // mm
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

  static DateTime _parseApl(String s) {
    if (s.length < 10) return DateTime.now();
    final y = int.parse(s.substring(0, 4));
    final m = int.parse(s.substring(4, 6));
    final d = int.parse(s.substring(6, 8));
    final h = int.parse(s.substring(8, 10));
    return DateTime(y, m, d, h);
  }

  factory Day7Item.fromJson(Map<String, dynamic> j) {
    double _d(dynamic v) => v == null ? 0 : double.tryParse(v.toString()) ?? 0;
    int _i(dynamic v) => v == null ? 0 : int.tryParse(v.toString()) ?? 0;
    return Day7Item(
      time: _parseApl(j['aplYmdt'] ?? ''),
      sky: j['sky'] ?? '',
      skyCode: j['sky_code']?.toString() ?? j['skycode']?.toString() ?? '',
      rainProb: _i(j['rain']),
      rainAmtMm: _d(j['rainAmt']),
      tempC: _d(j['temp']),
      humidity: _i(j['humidity']),
      windDir: j['winddir'] ?? '',
      windSpd: _d(j['windspd']),
      wavePrd: _d(j['wavePrd']),
      waveHt: _d(j['waveHt']),
      waveDir: j['waveDir'] ?? '',
    );
  }
}

