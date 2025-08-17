// lib/pages/weather/weather_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../../env.dart';
import 'weather_models.dart';

// 서울 시청 기준
const _SEOUL_LAT = 37.5665;
const _SEOUL_LON = 126.9780;

class WeatherApi {
  // forecast 전용 URI (공백/인코딩 이슈 방지: queryParameters 사용)
  // 공통 보조
  static Future<void> _ensureEnv() => Env.ensureLoaded();

// URL 조립 시 base 비어있을 경우를 대비해 기본값 지정
  static Uri _forecastUri(double lat, double lon) {
    final base = (Env.API_BASE_URL.isEmpty)
        ? 'https://www.badatime.com/DIVE'
        : Env.API_BASE_URL.replaceAll(RegExp(r'/$'), '');
    final key  = Env.WEATHER_SERVICE_KEY;
    return Uri.parse('$base/forecast').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lon.toString(),
      'key': key,
    });
  }
  // 바다타임이 에러를 200으로 주는 케이스 방어
  static bool _looksLikeError(List list) {
    if (list.length == 1 && list.first is Map) {
      final m = Map<String, dynamic>.from(list.first as Map);
      final err = (m['errorMsg'] ?? m['error'] ?? '').toString();
      return err.isNotEmpty;
    }
    return false;
  }

  // 현재 위치 얻기 (권한 거부/실패 시 null)
  static Future<({double lat, double lon})?> _getCurrentLatLon() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// forecast → Day7Item 리스트
  static Future<List<Day7Item>> fetchDay7(double lat, double lon) async {
    await _ensureEnv();
    // 1차 시도: 현재 좌표
    var res = await http.get(_forecastUri(lat, lon));

    // 성공 코드지만 에러 메시지 (키 오류/영역 미지원 등)면 서울로 폴백
    List parsed = [];
    if (res.statusCode == 200) {
      parsed = json.decode(utf8.decode(res.bodyBytes)) as List;
      if (_looksLikeError(parsed)) {
        res = await http.get(_forecastUri(_SEOUL_LAT, _SEOUL_LON));
        if (res.statusCode != 200) {
          throw Exception('forecast fetch failed: ${res.statusCode}');
        }
        parsed = json.decode(utf8.decode(res.bodyBytes)) as List;
      }
    } else {
      // 1차 자체가 실패면 서울로 재시도
      res = await http.get(_forecastUri(_SEOUL_LAT, _SEOUL_LON));
      if (res.statusCode != 200) {
        throw Exception('forecast fetch failed: ${res.statusCode}');
      }
      parsed = json.decode(utf8.decode(res.bodyBytes)) as List;
    }

    final items = parsed.map<Day7Item>((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      DateTime _parseYmdt(String v) {
        final s = v.trim();
        final y = int.parse(s.substring(0, 4));
        final mo = int.parse(s.substring(4, 6));
        final d = int.parse(s.substring(6, 8));
        final h = int.parse(s.substring(8, 10));
        return DateTime(y, mo, d, h);
      }

      T _firstOf<T>(List<String> keys) {
        final norm = <String, dynamic>{};
        for (final e in m.entries) {
          final nk = e.key.replaceAll(RegExp(r'[\u200B-\u200F\uFEFF]'), '');
          norm[nk] = e.value;
        }
        for (final k in keys) {
          if (m.containsKey(k)) return m[k] as T;
          if (norm.containsKey(k)) return norm[k] as T;
        }
        return null as T;
      }

      double _d(dynamic v) {
        if (v == null) return 0;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? 0;
      }

      int _i(dynamic v) {
        if (v == null) return 0;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }

      final time = _parseYmdt((_firstOf<String>(['ymdt']) ?? '1970010100'));
      return Day7Item(
        time: time,
        sky: (_firstOf<String>(['sky']) ?? ''),
        skyCode: (_firstOf<String>(['skycode', 'sky_code']) ?? ''),
        rainProb: _i(_firstOf(['rain'])),
        rainAmtMm: _d(_firstOf(['rainAmt', '﻿rainAmt'])),
        tempC: _d(_firstOf(['temp', '﻿temp'])),
        humidity: _i(_firstOf(['humidity', '﻿﻿humidity'])),
        windDir: (_firstOf<String>(['winddir']) ?? ''),
        windSpd: _d(_firstOf(['windspd', '﻿﻿windspd'])),
        wavePrd: _d(_firstOf(['wavePrd', '﻿﻿﻿wavePrd'])),
        waveHt: _d(_firstOf(['waveHt', 'pago', '﻿﻿﻿﻿waveHt'])),
        waveDir: (_firstOf<String>(['waveDir']) ?? ''),
      );
    }).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return items;
  }

  /// 현재 위치 기반으로 forecast 호출, 실패 시 서울 좌표로 폴백
  static Future<List<Day7Item>> fetchDay7WithCurrentLocation() async {
    final cur = await _getCurrentLatLon();
    if (cur == null) {
      // 위치 권한/OFF → 바로 서울
      return fetchDay7(_SEOUL_LAT, _SEOUL_LON);
    }
    // 현재 좌표 시도 → 내부에서 에러 응답 시 자동 서울 폴백
    return fetchDay7(cur.lat, cur.lon);
  }
// WeatherApi 클래스 내부에 추가
  static Future<NowResponse> fetchNow(double lat, double lon) async {
    await _ensureEnv();
    // 기존 fetchDay7(lat, lon)을 재사용 (내부에서 서울 폴백까지 처리됨)
    final list = await fetchDay7(lat, lon);

    final now = DateTime.now();
    // 현재 시각과 가장 가까운 3개 선택
    final ranked = list
        .map((e) => (e, (e.time.difference(now)).inMinutes.abs()))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));

    final pick = ranked.take(3).map((x) => x.$1).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return NowResponse(
      head: NowHead(
        fcastYmdt: _fmtYmdt(pick.isNotEmpty ? pick.first.time : now),
        type: 'now-from-forecast',
      ),
      items: pick.map((d) => NowItem(
        time: d.time,
        sky: d.sky,
        skyCode: d.skyCode,
        rainMm: d.rainAmtMm,
        tempC: d.tempC,
        windDir: d.windDir,
        windSpd: d.windSpd,
        waveHt: d.waveHt,
        humidity: d.humidity.toDouble(),
      )).toList(),
      city: null,
      cityCode: null,
    );
  }

  /// 필요 시 “현재시각 근접 3개”로 NOW 구성 (UI에서 써야 하면)
  static Future<NowResponse> fetchNowFromForecastWithCurrentLocation() async {
    final list = await fetchDay7WithCurrentLocation();
    final now = DateTime.now();
    final ranked = list
        .map((e) => (e, (e.time.difference(now)).inMinutes.abs()))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    final pick = ranked.take(3).map((x) => x.$1).toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    return NowResponse(
      head: NowHead(fcastYmdt: _fmtYmdt(pick.isNotEmpty ? pick.first.time : now), type: 'now-from-forecast'),
      items: pick.map((d) => NowItem(
        time: d.time,
        sky: d.sky,
        skyCode: d.skyCode,
        rainMm: d.rainAmtMm,
        tempC: d.tempC,
        windDir: d.windDir,
        windSpd: d.windSpd,
        waveHt: d.waveHt,
        humidity: d.humidity.toDouble(),
      )).toList(),
      city: null,
      cityCode: null,
    );
  }

  static String _fmtYmdt(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final H = dt.hour.toString().padLeft(2, '0');
    return '$y$m$d$H';
  }
}
