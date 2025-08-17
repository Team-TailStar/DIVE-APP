import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart'; // ← 추가
import 'routes.dart';
import 'env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await Env.ensureLoaded();
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

      // 로컬라이제이션 설정
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      locale: const Locale('ko', 'KR'),

      initialRoute: Routes.home,
      onGenerateRoute: RouteGenerator.onGenerateRoute,
    );
  }
}
