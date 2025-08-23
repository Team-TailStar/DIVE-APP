import 'package:dive_app/pages/fishing_point/fishing_point_main.dart';
import 'package:dive_app/pages/watch_connect/watch_connection_page.dart';
import 'package:dive_app/pages/sea_weather/sea_weather.dart';
import 'package:dive_app/pages/tide/tide_page.dart';
import 'package:dive_app/pages/weather/weather_page.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});
  final int currentIndex;

  // No animation on route change
  void _goReplace(BuildContext context, Widget page) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const blue = Colors.blue;
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        colorScheme: theme.colorScheme.copyWith(
          primary: blue,
          secondary: blue,
        ),
        bottomNavigationBarTheme: theme.bottomNavigationBarTheme.copyWith(
          backgroundColor: Colors.white, // ✅ 흰색 배경
          elevation: 0,                  // ✅ 그림자 제거
          selectedItemColor: blue,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedIconTheme: const IconThemeData(size: 24),
          unselectedIconTheme: const IconThemeData(size: 24),
          selectedLabelStyle: const TextStyle(fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.white, // ✅ 흰색 배경
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        selectedItemColor: blue,
        unselectedItemColor: Colors.grey,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 24),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        showUnselectedLabels: true,
        enableFeedback: false,
        onTap: (i) async {
          if (i == currentIndex) return;

          switch (i) {
            case 0:
              final pos = await _getPosition(context);
              if (pos == null) return;
              _goReplace(context, WeatherPage(lat: pos.latitude, lon: pos.longitude));
              break;
            case 1:
              _goReplace(context, const SeaWeatherPage());
              break;
            case 2:
              _goReplace(context, const TidePage());
              break;
            case 3:
              _goReplace(context, const FishingPointMainPage());
              break;
            case 4:
              _goReplace(context, const WatchConnectPage());
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.sunny), label: '날씨'),
          BottomNavigationBarItem(icon: Icon(Icons.water), label: '바다 날씨'),
          BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: '물때'),
          BottomNavigationBarItem(icon: Icon(Icons.place), label: '낚시 포인트'),
          BottomNavigationBarItem(icon: Icon(Icons.watch), label: '워치'),
        ],
      ),
    );
  }

  Future<Position?> _getPosition(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      messenger.showSnackBar(const SnackBar(content: Text('위치 서비스가 꺼져 있습니다.')));
      return null;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        messenger.showSnackBar(const SnackBar(content: Text('위치 권한이 거부되었습니다.')));
        return null;
      }
    }
    if (perm == LocationPermission.deniedForever) {
      messenger.showSnackBar(const SnackBar(content: Text('설정에서 위치 권한을 허용해 주세요.')));
      return null;
    }

    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }
}
