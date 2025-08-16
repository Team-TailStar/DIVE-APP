import 'package:flutter/material.dart';

// 페이지들 임포트
import 'pages/sea_weather/sea_weather.dart';               // SeaWeatherPage, TempComparePage 포함
import 'pages/fishing_point/fishing_point_main.dart';      // 새로 만들 파일
import 'pages/fishing_point/fishing_point_detail.dart';    // 새로 만들 파일

class Routes {
  static const String home = '/';
  static const String regionSelect = '/region';
  static const String tempCompare = '/temp-compare';

  // 낚시 포인트
  static const String fishingPointMain = '/fishing-point';
  static const String fishingPointDetail = '/fishingPoint/detail';
}

class RouteGenerator {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.home:
        return _page(const SeaWeatherPage());

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

// --- 더미 지역 선택 페이지 (그대로 둬도 됨) ---
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