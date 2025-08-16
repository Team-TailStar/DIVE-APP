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
      final start = DateTime.now();
      // 3시간 간격으로 샘플 몇 개
      final List<Day7Item> items = [
        Day7Item(
          time: DateTime(start.year, start.month, start.day, 0),
          sky: '맑음',
          skyCode: '1',
          rainProb: 0,
          rainAmtMm: 0.0,
          tempC: 27,
          humidity: 91,
          windDir: 'NE',
          windSpd: 1.0,
          wavePrd: 7.2,
          waveHt: 0.20,
          waveDir: 'SSW',
        ),
        Day7Item(
          time: DateTime(start.year, start.month, start.day, 3),
          sky: '맑음',
          skyCode: '1',
          rainProb: 0,
          rainAmtMm: 0.0,
          tempC: 26,
          humidity: 85,
          windDir: 'N',
          windSpd: 1.8,
          wavePrd: 7.1,
          waveHt: 0.18,
          waveDir: 'SSW',
        ),
        Day7Item(
          time: DateTime(start.year, start.month, start.day, 6),
          sky: '구름조금',
          skyCode: '2',
          rainProb: 10,
          rainAmtMm: 0.0,
          tempC: 28,
          humidity: 74,
          windDir: 'E',
          windSpd: 0.6,
          wavePrd: 8.0,
          waveHt: 0.94,
          waveDir: 'ENE',
        ),
        Day7Item(
          time: DateTime(start.year, start.month, start.day, 9),
          sky: '맑음',
          skyCode: '1',
          rainProb: 0,
          rainAmtMm: 0.0,
          tempC: 30,
          humidity: 57,
          windDir: 'SE',
          windSpd: 2.2,
          wavePrd: 5.5,
          waveHt: 1.2,
          waveDir: 'ENE',
        ),
        Day7Item(
          time: DateTime(start.year, start.month, start.day, 12),
          sky: '맑음',
          skyCode: '1',
          rainProb: 0,
          rainAmtMm: 0.0,
          tempC: 31,
          humidity: 55,
          windDir: 'S',
          windSpd: 2.0,
          wavePrd: 6.3,
          waveHt: 0.6,
          waveDir: 'ESE',
        ),
        Day7Item(
          time: DateTime(start.year, start.month, start.day, 15),
          sky: '구름조금',
          skyCode: '2',
          rainProb: 10,
          rainAmtMm: 0.0,
          tempC: 30,
          humidity: 60,
          windDir: 'SSW',
          windSpd: 1.6,
          wavePrd: 6.8,
          waveHt: 0.5,
          waveDir: 'SE',
        ),
        Day7Item(
          time: DateTime(start.year, start.month, start.day, 18),
          sky: '맑음',
          skyCode: '1',
          rainProb: 0,
          rainAmtMm: 0.0,
          tempC: 28,
          humidity: 68,
          windDir: 'S',
          windSpd: 1.2,
          wavePrd: 7.5,
          waveHt: 0.4,
          waveDir: 'SSE',
        ),
        Day7Item(
          time: DateTime(start.year, start.month, start.day, 21),
          sky: '맑음',
          skyCode: '1',
          rainProb: 0,
          rainAmtMm: 0.0,
          tempC: 27,
          humidity: 72,
          windDir: 'SSW',
          windSpd: 0.8,
          wavePrd: 8.2,
          waveHt: 0.35,
          waveDir: 'SSW',
        ),
      ];
      return items;
    }

    // === 실제 API 호출 경로 (키 받으면 _useMock=false 로 전환) ===
    final url = Uri.parse('$baseUrl/api/weather/day7?lat=$lat&lon=$lon');
    final res = await http.get(url);
    if (res.statusCode != 200) {
      throw Exception('day7 fetch failed: ${res.statusCode}');
    }
    final Map<String, dynamic> j = json.decode(res.body);
    final List list = j['weather'] ?? [];
    final items = list.map((e) => Day7Item.fromJson(e)).toList().cast<Day7Item>();
    items.sort((a, b) => a.time.compareTo(b.time));
    return items;
  }
}
