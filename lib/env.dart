// lib/env.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Env {

  // static late final String AIRKOREA_SERVICE_KEY;
  // static late final String API_BASE_URL;
  // static late final String BADA_SERVICE_KEY;
  // static late final bool   USE_TIDE_MOCK;

  static bool _loaded = false;
  static Future<void>? _loading;

  static String AIRKOREA_SERVICE_KEY = '';
  static String API_BASE_URL = '';
  static String BADA_SERVICE_KEY = '';
  static bool   USE_TIDE_MOCK = false;
  static String KAKAO_REST_KEY = '';

  static Future<void> load() async {
    if (_loaded) return;
    if (_loading != null) { await _loading; return; }
    _loading = _doLoad();
    try { await _loading; } finally { _loading = null; }
  }

  static Future<void> _doLoad() async {
    // ✔︎ 경로 확인 (아래 참고)
    final raw = await rootBundle.loadString('assets/env.json');
    final j = json.decode(raw) as Map<String, dynamic>;
    String _s(dynamic v, {String or = ''}) => (v ?? or).toString().trim();
    bool _b(dynamic v, {bool or = false}) {
      if (v is bool) return v;
      final s = v?.toString().trim().toLowerCase();
      return s == 'true' ? true : s == 'false' ? false : or;
    }

    AIRKOREA_SERVICE_KEY = _s(j['AIRKOREA_SERVICE_KEY']);
    API_BASE_URL         = _s(j['API_BASE_URL']);
    BADA_SERVICE_KEY     = _s(j['BADA_SERVICE_KEY']);
    USE_TIDE_MOCK        = _b(j['USE_TIDE_MOCK']);
    KAKAO_REST_KEY       = _s(j['KAKAO_REST_KEY']);


    _loaded = true;
  }

  static Future<void> ensureLoaded() => _loaded ? Future.value() : load();
}
