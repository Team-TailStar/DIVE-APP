import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter/services.dart';

import 'routes.dart';
import 'env.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 한국어 날짜 포맷 초기화
  await initializeDateFormatting('ko_KR', null);

  // 환경 변수 로드
  await Env.ensureLoaded();

  // Wear 채널 초기화
  WearChannel.init();

  // 네이버 지도 인증
  await FlutterNaverMap().init(
    clientId: 'vwykpurwuk',
    onAuthFailed: (ex) {
      switch (ex) {
        case NQuotaExceededException(:final message):
          print("❌ 네이버 지도 사용량 초과 (message: $message)");
          break;
        case NUnauthorizedClientException() ||
        NClientUnspecifiedException() ||
        NAnotherAuthFailedException():
          print("❌ 네이버 지도 인증 실패: $ex");
          break;
      }
    },
  );

  runApp(const SeaWeatherApp());
}

class SeaWeatherApp extends StatelessWidget {
  const SeaWeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '바다 친구',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6EC5FF),
        scaffoldBackgroundColor: const Color(0xFFEFF8FD),
        fontFamily: 'Pretendard',
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      initialRoute: Routes.home,
      onGenerateRoute: RouteGenerator.onGenerateRoute,
    );
  }
}

/// Flutter ↔ Android 통신 채널
class WearChannel {
  static const _channel = MethodChannel("app.dive/wear");

  static void init() {
    // Android → Flutter 메시지 수신
    _channel.setMethodCallHandler((call) async {
      if (call.method == "requestWeather") {
        print("📩 Android → Flutter: requestWeather 호출됨");
        await testSendWeather(); // 요청이 오면 날씨 데이터를 다시 보냄
      }
    });
  }

  /// Flutter → Android 날씨 데이터 전송
  static Future<void> sendWeather(Map<String, dynamic> weather) async {
    print("📤 Flutter → Android: sendWeather 전송 시도");
    try {
      await _channel.invokeMethod("sendWeather", weather);
      print("✅ Flutter → Android: sendWeather 전송 성공");
    } on PlatformException catch (e) {
      print("❌ Flutter → Android: sendWeather 전송 실패: ${e.message}");
    }
  }
}

/// 테스트용 더미 날씨 데이터 전송
Future<void> testSendWeather() async {
  final weatherData = {
    "sky": "맑음",
    "windspd": "3.2",
    "temp": "28",
    "humidity": "65",
    "rain": "0",
    "winddir": "NW",
    "waveHt": "0.5",
    "waveDir": "북서",
    "obs_wt": "25.5",
  };

  await WearChannel.sendWeather(weatherData);
}
