import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter/services.dart';
import 'pages/ui/aq_theme.dart';
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
        case NQuotaExceededException():
          break;
        case NUnauthorizedClientException() ||
        NClientUnspecifiedException() ||
        NAnotherAuthFailedException():
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

      initialRoute: Routes.home,
      onGenerateRoute: RouteGenerator.onGenerateRoute,
      theme: ThemeData(
        useMaterial3: true,
          scaffoldBackgroundColor: Colors.transparent,

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF7BB8FF), // 투명
          elevation: 0,                        // 그림자 제거
          scrolledUnderElevation: 0,           // 스크롤 시 생기는 그림자 제거
          foregroundColor: Colors.black,       // 아이콘/텍스트 색상
          centerTitle: true,                   // 타이틀 중앙 (선택)
        ),
        extensions: <ThemeExtension<dynamic>>[
          AqCardTheme.light(),
        ],
      ),
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7BB8FF), Color(0xFFA8D3FF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: child,
        );
      },
    );

  }
}

/// Flutter ↔ Android 통신 채널
class WearChannel {
  static const _channel = MethodChannel("app.dive/wear");

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "requestWeather") {
        await testSendWeather();
      }
    });
  }

  static Future<void> sendWeather(Map<String, dynamic> weather) async {
    try {
      await _channel.invokeMethod("sendWeather", weather);
    } on PlatformException {
    }
  }
}

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
