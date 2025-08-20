// lib/env.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Env {
  static late final String AIRKOREA_SERVICE_KEY;
  static late final String API_BASE_URL;
  static late final String BADA_SERVICE_KEY;
  static late final bool   USE_TIDE_MOCK;

  static late final String IMAGE_BASE_URL;

  static bool _loaded = false;
  static Future<void>? _loading; // 동시 호출 방지

  // 외부 진입점
  static Future<void> load() async {
    if (_loaded) return;
    if (_loading != null) {
      // 이미 로딩 중이면 완료까지 기다리고 리턴
      await _loading;
      return;
    }
    _loading = _doLoad();
    try {
      await _loading;
    } finally {
      _loading = null; // 누수 방지
    }
  }

  static Future<void> _doLoad() async {
    final raw = await rootBundle.loadString('lib/assets/env.json');
    if (raw.trim().isEmpty) {
      throw StateError('assets/env.json is empty');
    }

    final Map<String, dynamic> j = json.decode(raw) as Map<String, dynamic>;

    String _s(dynamic v, {String or = ''}) => (v ?? or).toString().trim();
    bool _b(dynamic v, {bool or = false}) {
      if (v is bool) return v;
      final s = v?.toString().trim().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
      return or;
    }

    AIRKOREA_SERVICE_KEY = _s(j['AIRKOREA_SERVICE_KEY']);
    API_BASE_URL         = _s(j['API_BASE_URL']);
    BADA_SERVICE_KEY     = _s(j['BADA_SERVICE_KEY']);
    USE_TIDE_MOCK        = _b(j['USE_TIDE_MOCK']);

    IMAGE_BASE_URL       = _s(j['IMAGE_BASE_URL']);


    // (선택) 필수 키 검증: 개발 중이라면 assert로 막아두면 빨리 발견 가능
    assert(API_BASE_URL.isNotEmpty, 'API_BASE_URL is required in assets/env.json');

    _loaded = true;
  }

  // 어디서든 “불러와져 있지 않으면 로드”
  static Future<void> ensureLoaded() => _loaded ? Future.value() : load();
}
