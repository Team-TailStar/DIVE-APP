
// lib/wear_bridge.dart

import 'package:flutter/services.dart';

class WearBridge {
  static const MethodChannel _ch = MethodChannel('app.dive/wear');

  static Future<void> sendTempStations(List<Map<String, dynamic>> items) async {
    final payload = items
        .map((m) => m.map((k, v) => MapEntry(k, v?.toString() ?? '')))
        .toList();
    await _ch.invokeMethod('sendTempStations', {"items": payload});
  }

  static Future<void> sendWavesForecast(List<Map<String, dynamic>> items) async {
    final payload = items
        .map((m) => m.map((k, v) => MapEntry(k, v?.toString() ?? '')))
        .toList();
    await _ch.invokeMethod('sendWavesForecast', {"items": payload});
  }

  static Future<void> sendWeather(Map<String, dynamic> weather) async {
    final payload = weather.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    await _ch.invokeMethod('sendWeather', payload);
  }

  static Future<void> sendFishingPoints(List<Map<String, dynamic>> points) async {
    final payload = points.map((p) =>
    {
      'name': (p['name'] ?? '').toString(),
      'point_nm': (p['point_nm'] ?? p['name'] ?? '').toString(),
      'dpwt': (p['dpwt'] ?? '').toString(),
      'material': (p['material'] ?? '').toString(),
      'tide_time': (p['tide_time'] ?? '').toString(),
      'target': (p['target'] ?? '').toString(),
      'lat': (p['lat'] as num?)?.toDouble() ?? 0.0,
      'lon': (p['lon'] as num?)?.toDouble() ?? 0.0,
      'point_dt': (p['point_dt'] ?? '').toString(),
    }).toList();

    await _ch.invokeMethod('sendFishingPoints', { 'points': payload});
  }

  static Future<void> sendTide(Map<String, dynamic> tide) async {
    final payload = tide.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    await _ch.invokeMethod('sendTide', payload);
  }

  static Future<void> sendTemp(Map<String, dynamic> temp) async {
    final payload = temp.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    await _ch.invokeMethod('sendTemp', payload);
  }
}
