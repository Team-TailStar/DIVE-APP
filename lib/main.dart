import 'package:flutter/material.dart';
import 'routes.dart';

void main() {
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
        fontFamily: 'Pretendard', // (optional) remove if not added
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
