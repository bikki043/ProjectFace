import 'dart:io';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'theme/app_colors.dart';
import 'theme/theme_controller.dart';

class DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (cert, host, port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = DevHttpOverrides(); // dev only!
  await ThemeController.instance.init(); // loads saved theme mode + accent
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds MaterialApp's theme/themeMode whenever Settings changes
    // it. The individual screens (home_screen.dart, login_screen.dart,
    // settings_screen.dart) each have their own AnimatedBuilder too, so
    // their AppColors-based colors refresh without losing navigation
    // state — see the comment in home_screen.dart for why that's
    // needed in addition to this one.
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Face Attendance System',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeController.instance.mode,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: AppColors.bg,
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.light(primary: AppColors.primary, secondary: AppColors.primary),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.bg,
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.dark(primary: AppColors.primary, secondary: AppColors.primary),
            useMaterial3: true,
          ),
          home: const LoginScreen(),
          routes: {
            '/home': (context) => const HomeScreen(),
          },
        );
      },
    );
  }
}
