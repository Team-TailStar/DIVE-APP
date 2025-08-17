// lib/env.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class Env {
  static late final String AIRKOREA_SERVICE_KEY;
  static late final String API_BASE_URL;
  static late final String BADA_SERVICE_KEY;

  static bool _loaded = false;
  static Future<void>? _loading; // ← 중복 로딩 방지

  static Future<void> load() async {
    if (_loaded) return;
    if (_loading != null) return _loading; // 이미 로딩 중이면 그 Future 반환
    _loading = _doLoad();
    await _loading;
  }

  static Future<void> _doLoad() async {
    final raw = await rootBundle.loadString('assets/env.json');
    final Map<String, dynamic> j = json.decode(raw);

    AIRKOREA_SERVICE_KEY = (j['AIRKOREA_SERVICE_KEY'] ?? '').toString();
    API_BASE_URL        = (j['API_BASE_URL'] ?? '').toString();
    BADA_SERVICE_KEY = (j['BADA_SERVICE_KEY'] ?? '').toString();

    final mockRaw = (j['USE_TIDE_MOCK'] ?? 'false').toString().trim().toLowerCase();

    _loaded = true;
    _loading = null;
  }

  // 어디서든 “불러와져 있지 않으면 로드” 하도록 노출
  static Future<void> ensureLoaded() => _loaded ? Future.value() : load();
}
