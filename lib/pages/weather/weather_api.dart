// lib/pages/weather/weather_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'weather_models.dart';

const String baseUrl = 'https://YOUR_BACKEND_BASE_URL'; // 실제 키 받으면 교체
const bool _useMock = true; // ← 임시 데이터 사용 여부 토글

class WeatherApi {
  static Future<NowResponse> fetchNow(double lat, double lon) async {
    if (_useMock) {
      final head = NowHead(fcastYmdt: '20250816090000', type: 'now');
      final now = DateTime.now();
      final items = <NowItem>[
        NowItem(
          time: now,
          sky: '맑음',
          skyCode: '1',
          rainMm: 0.0,
          tempC: 30.6,
          windDir: 'S',
          windSpd: 5.8,
          waveHt: 0.29,
          humidity: 75.0,
        ),
        NowItem(
          time: now.add(const Duration(hours: 1)),
          sky: '맑음',
          skyCode: '1',
          rainMm: 0.0,
          tempC: 30.0,
          windDir: 'S',
          windSpd: 4.9,
          waveHt: 0.31,
          humidity: 73.0,
        ),
        NowItem(
          time: now.add(const Duration(hours: 2)),
          sky: '구름조금',
          skyCode: '2',
          rainMm: 0.0,
          tempC: 29.2,
          windDir: 'SSW',
          windSpd: 4.2,
          waveHt: 0.33,
          humidity: 78.0,
        ),
      ];
      return NowResponse(
        head: head,
        items: items,
        city: '서울특별시 중구',
        cityCode: '1114010500',
      );
    }

    // === 실제 API 호출 경로 (키 받으면 _useMock=false 로 전환) ===
    final url = Uri.parse('$baseUrl/api/weather/now?lat=$lat&lon=$lon');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('now fetch failed: ${res.statusCode}');
    }
    return NowResponse.fromJson(json.decode(res.body));
  }

  static Future<List<Day7Item>> fetchDay7(double lat, double lon) async {
    if (_useMock) {
      final now = DateTime.now();
      final List<Day7Item> items = [];
      final today0 = DateTime(now.year, now.month, now.day);

      for (int d = -3; d <= 3; d++) {
        for (int h = 0; h < 24; h += 3) {
          final t = today0.add(Duration(days: d, hours: h));
          items.add(
            Day7Item(
              time: t,
              sky: (h < 12) ? '맑음' : '구름조금',
              skyCode: (h < 12) ? '1' : '2',
              rainProb: (h == 15 && d.isEven) ? 30 : 0,
              rainAmtMm: (h == 15 && d.isEven) ? 1.2 : 0.0,
              tempC: 24.0 + d + (h / 6),      // 대충 변하는 온도
              humidity: 60 + (h % 4) * 5,     // 60~75
              windDir: 'S',
              windSpd: 1.5 + d * 0.3,         // -3일도 자연스럽게
              wavePrd: 6.0 + (h % 5) * 0.3,
              waveHt: 0.3 + (h % 6) * 0.05,
              waveDir: 'S',
            ),
          );
        }
      }

      items.sort((a, b) => a.time.compareTo(b.time));
      return items;
    }

    // === 실제 API 호출 (키 받으면 _useMock=false로 전환) ===
    final url = Uri.parse('$baseUrl/api/weather/day7?lat=$lat&lon=$lon');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('day7 fetch failed: ${res.statusCode}');
    }
    final Map<String, dynamic> j = json.decode(res.body);
    final List list = j['weather'] ?? [];
    final items = list.map((e) => Day7Item.fromJson(e)).toList().cast<
        Day7Item>();
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }
}