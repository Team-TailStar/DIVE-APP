import 'package:flutter/material.dart';

// 페이지들 임포트
import 'pages/sea_weather/sea_weather.dart';               // SeaWeatherPage, TempComparePage 포함
import 'pages/fishing_point/fishing_point_main.dart';      // 새로 만들 파일
import 'pages/fishing_point/fishing_point_detail.dart';    // 새로 만들 파일
import 'pages/weather/weather_page.dart';
import 'package:geolocator/geolocator.dart';

class Routes {
  static const String home = '/';
  static const String regionSelect = '/region';
  static const String tempCompare = '/temp-compare';
  static const String fishingPointMain = '/fishing-point';
  static const String fishingPointDetail = '/fishingPoint/detail';
}

class RouteGenerator {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return MaterialPageRoute(builder: (_) => const _WeatherAutoPage());

      case Routes.regionSelect:
        return _page(const _DummyRegionPage());

      case Routes.tempCompare:
        return _page(const TempComparePage());

    // 낚시 포인트 메인
      case Routes.fishingPointMain:
        return _page(const FishingPointMainPage());

    // 낚시 포인트 상세 (arguments 사용)
      case Routes.fishingPointDetail:
        return _page(FishingPointDetailPage.from(settings.arguments));

      default:
        return _page(const SeaWeatherPage());
    }
  }

  static PageRoute _page(Widget child) =>
      MaterialPageRoute(builder: (_) => child);
}


class _DummyRegionPage extends StatelessWidget {
  const _DummyRegionPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('지역 선택')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('뒤로'),
        ),
      ),
    );
  }
}

class _WeatherAutoPage extends StatelessWidget {
  const _WeatherAutoPage({super.key});

  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw '위치 서비스가 꺼져 있습니다.';
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw '위치 권한이 거부되었습니다.';
    }
    if (perm == LocationPermission.deniedForever) {
      throw '설정에서 위치 권한을 허용해 주세요.';
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: _getPosition(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !snap.hasData) {
          // 실패 시 임시 좌표(서울시청)로 진입
          return const WeatherPage(lat: 37.5665, lon: 126.9780);
        }
        final p = snap.data!;
        return WeatherPage(lat: p.latitude, lon: p.longitude);
      },
    );
  }
}
