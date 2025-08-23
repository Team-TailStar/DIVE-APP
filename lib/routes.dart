import 'package:dive_app/pages/tide/tide_page.dart';
import 'package:flutter/material.dart';

import 'pages/sea_weather/sea_weather.dart';
import 'pages/fishing_point/fishing_point_main.dart';
import 'pages/fishing_point/fishing_point_detail.dart';
import 'pages/weather/weather_page.dart';
import 'package:geolocator/geolocator.dart';
import 'pages/watch_connect/watch_connection_page.dart';

class Routes {
  static const String home = '/';
  static const String regionSelect = '/region';
  static const String tempCompare = '/temp-compare';
  static const String fishingPointMain = '/fishing-point';
  static const String fishingPointDetail = '/fishingPoint/detail';
  static const String watchConnect = '/watch-connect';

  static const String seaWeather = '/seaWeather';
  static const String tide = '/tide';
  static const String health = '/health';
}

class RouteGenerator {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return MaterialPageRoute(builder: (_) => const _WeatherAutoPage());

      case Routes.regionSelect:
        return _page(const _DummyRegionPage());


      case Routes.fishingPointMain:
        return _page(const FishingPointMainPage());

      case Routes.fishingPointDetail:
        return _page(FishingPointDetailPage.from(settings.arguments));

      case Routes.watchConnect:
        return _page(const WatchConnectPage());

      case Routes.seaWeather:
        return _page(const SeaWeatherPage());

      case Routes.tide:
        return _page(const TidePage());

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
  const _WeatherAutoPage();

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
          return const WeatherPage(lat: 37.5665, lon: 126.9780);
        }
        final p = snap.data!;
        return WeatherPage(lat: p.latitude, lon: p.longitude);
      },
    );
  }
}
