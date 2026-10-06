// frontend/lib/main.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api/http_admin_api.dart';
import 'platform/web_file_downloader.dart';
import 'platform/web_file_picker.dart';
import 'screens/dashboard_screen.dart';
import 'services/download_helper.dart';
import 'services/file_picker_helper.dart';
import 'storage/web_token_store.dart';
import 'utils/localization.dart';

void main() {
  // 운영 환경 기본 인스턴스 초기화 (브라우저 구현 주입)
  HttpAdminApi.instance = HttpAdminApi(
    client: http.Client(),
    tokenStore: WebTokenStore(),
  );
  DownloadHelper.instance = WebFileDownloader();
  FilePickerHelper.instance = WebFilePicker();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseDarkTheme = ThemeData.dark();
    final darkTextTheme = baseDarkTheme.textTheme.apply(
      fontFamily: 'NotoSansKR',
    );

    final baseLightTheme = ThemeData.light();
    final lightTextTheme = baseLightTheme.textTheme.apply(
      fontFamily: 'NotoSansKR',
      bodyColor: const Color(0xFF1E293B),
      displayColor: const Color(0xFF0F172A),
    );

    return ValueListenableBuilder<String>(
      valueListenable: LanguageManager.languageCodeNotifier,
      builder: (context, currentLang, _) {
        return MaterialApp(
          title: 'AI Robot Config Dashboard'.tr,
          debugShowCheckedModeBanner: false,
          themeMode: _themeMode,
          builder: (context, child) {
            final mediaQueryData = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQueryData.copyWith(
                textScaler: const TextScaler.linear(1.2),
              ),
              child: child!,
            );
          },

          // 라이트 테마 정의
          theme: baseLightTheme.copyWith(
            textTheme: lightTextTheme,
            primaryTextTheme: lightTextTheme,
            scaffoldBackgroundColor: const Color(0xFFF8F9FA),
            dividerColor: const Color(0xFFE2E8F0),
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00838F), // Deep Cyan
              secondary: Color(0xFF1565C0), // Dark Blue
              surface: Color(0xFFFFFFFF),
              error: Color(0xFFD32F2F),
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFFFFFFFF),
              elevation: 2,
              shadowColor: Color(0x0F000000),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFF1F3F5),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              labelStyle: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
              ),
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF00838F),
                  width: 1.8,
                ),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFFFFFFF),
              elevation: 1,
              iconTheme: IconThemeData(color: Color(0xFF1E293B)),
              titleTextStyle: TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSansKR',
              ),
            ),
          ),

          // 다크 테마 정의
          darkTheme: baseDarkTheme.copyWith(
            textTheme: darkTextTheme,
            primaryTextTheme: darkTextTheme,
            scaffoldBackgroundColor: const Color(0xFF121212),
            dividerColor: const Color(0xFF2E2E2E),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00E5FF), // Neon Cyan
              secondary: Color(0xFF2979FF), // Electric Blue
              surface: Color(0xFF1E1E1E),
              error: Color(0xFFFF5252),
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF1E1E1E),
              elevation: 4,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFF252525),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              labelStyle: const TextStyle(
                color: Color(0xFFB0B0B0),
                fontSize: 14,
              ),
              hintStyle: const TextStyle(
                color: Color(0xFF707070),
                fontSize: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF00E5FF),
                  width: 1.8,
                ),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              elevation: 0,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSansKR',
              ),
            ),
          ),
          home: DashboardScreen(
            themeMode: _themeMode,
            onThemeModeChanged: _toggleTheme,
          ),
        );
      },
    );
  }
}
