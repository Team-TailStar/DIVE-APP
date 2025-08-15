import 'package:flutter/material.dart';
import 'pages/sea_weather/sea_weather.dart';

class Routes {
  static const String home = '/';
  static const String regionSelect = '/region';
  static const String tempCompare = '/temp-compare'; // 추가
}

class RouteGenerator {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return _page(const SeaWeatherPage());
      case Routes.regionSelect:
        return _page(const _DummyRegionPage());
      case Routes.tempCompare:
        return _page(const TempComparePage()); // 추가
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
