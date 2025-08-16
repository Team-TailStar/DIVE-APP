import 'package:dive_app/pages/fishing_point/fishing_point_main.dart';
import 'package:dive_app/pages/sea_weather/sea_weather.dart';
import 'package:dive_app/pages/weather/weather_page.dart';
import 'package:flutter/material.dart';

import '../pages/tide/tide_page.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (i) {
        if (i == currentIndex) return;
        _go(context, i);
      },
      selectedItemColor: Colors.redAccent,
      unselectedItemColor: Colors.grey,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      selectedIconTheme: const IconThemeData(size: 30),
      unselectedIconTheme: const IconThemeData(size: 30),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.place), label: ' 날씨'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: '바다 날씨'),
        BottomNavigationBarItem(icon: Icon(Icons.groups), label: '물때'),
        BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: '낚시 포인트'),
      ],
    );
  }

  static void _go(BuildContext context, int index) {
    final Widget page = switch (index) {
      0 => const WeatherPage(),
      1 => const SeaWeatherPage(),
      2 => const TidePage(),
      3 => const FishingPointMainPage(),
      _ => const WeatherPage(),
    };

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, __, ___, child) => child,
      ),
    );
  }
}
