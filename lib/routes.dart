import 'package:flutter/material.dart';
import 'pages/sea_weather.dart';

class Routes {
  static const String home = '/';
  static const String regionSelect = '/region';
}

class RouteGenerator {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return _page(const SeaWeatherPage());
      case Routes.regionSelect:
      // Placeholder page (tap "지역 선택" goes here)
        return _page(const _DummyRegionPage());
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
