import 'package:flutter/material.dart';

/// A named accent the person can pick from Settings. Only the "accent"
/// family changes between presets — backgrounds/text tone come from
/// light vs dark mode, not the preset itself (same pattern as
/// Twitter/X, Telegram, etc: pick a mode, pick an accent color).
enum AppAccent { indigo, mint, coral, amber, ocean }

extension AppAccentInfo on AppAccent {
  String get label {
    switch (this) {
      case AppAccent.indigo:
        return 'ม่วงคราม';
      case AppAccent.mint:
        return 'เขียวมิ้นท์';
      case AppAccent.coral:
        return 'ส้มคอรัล';
      case AppAccent.amber:
        return 'เหลืองทอง';
      case AppAccent.ocean:
        return 'ฟ้ามหาสมุทร';
    }
  }

  Color get seed {
    switch (this) {
      case AppAccent.indigo:
        return const Color(0xFF5B5FEF);
      case AppAccent.mint:
        return const Color(0xFF17C3B2);
      case AppAccent.coral:
        return const Color(0xFFFF6B6B);
      case AppAccent.amber:
        return const Color(0xFFFFB238);
      case AppAccent.ocean:
        return const Color(0xFF2196F3);
    }
  }

  Color get seedSoftLight => Color.alphaBlend(seed.withOpacity(0.12), Colors.white);
  Color get seedSoftDark => Color.alphaBlend(seed.withOpacity(0.24), const Color(0xFF1D1D1D));
}

/// Every color token the app's screens use, already resolved for one
/// specific accent + brightness combination. AppColors (see
/// app_colors.dart) always points at exactly one of these at a time.
class AppPalette {
  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color divider;

  final Color primary;
  final Color primaryDark;
  final Color primarySoft;

  final Color mint;
  final Color mintSoft;
  final Color amber;
  final Color amberSoft;
  final Color coral;
  final Color coralSoft;

  final Color ink;
  final Color inkDim;

  final Brightness brightness;

  const AppPalette({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.divider,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.mint,
    required this.mintSoft,
    required this.amber,
    required this.amberSoft,
    required this.coral,
    required this.coralSoft,
    required this.ink,
    required this.inkDim,
    required this.brightness,
  });

  factory AppPalette.light(AppAccent accent) => AppPalette(
        bg: const Color(0xFFF5F6FB),
        surface: const Color(0xFFFFFFFF),
        surfaceAlt: const Color(0xFFEEF0FC),
        divider: const Color(0xFFE7E9F5),
        primary: accent.seed,
        primaryDark: Color.alphaBlend(Colors.black.withOpacity(0.18), accent.seed),
        primarySoft: accent.seedSoftLight,
        mint: const Color(0xFF17C3B2),
        mintSoft: const Color(0xFFE3F9F6),
        amber: const Color(0xFFFFB238),
        amberSoft: const Color(0xFFFFF3E0),
        coral: const Color(0xFFFF6B6B),
        coralSoft: const Color(0xFFFFEBEB),
        ink: const Color(0xFF14162B),
        inkDim: const Color(0xFF8489A0),
        brightness: Brightness.light,
      );

  factory AppPalette.dark(AppAccent accent) => AppPalette(
        bg: const Color(0xFF121214),
        surface: const Color(0xFF1A1A1E),
        surfaceAlt: const Color(0xFF232329),
        divider: const Color(0xFF2E2E35),
        primary: accent.seed,
        primaryDark: Color.alphaBlend(Colors.white.withOpacity(0.14), accent.seed),
        primarySoft: accent.seedSoftDark,
        mint: const Color(0xFF2ED9C3),
        mintSoft: const Color(0xFF16332F),
        amber: const Color(0xFFFFC15E),
        amberSoft: const Color(0xFF3A2D14),
        coral: const Color(0xFFFF8080),
        coralSoft: const Color(0xFF3A1E1E),
        ink: const Color(0xFFF2F2F7),
        inkDim: const Color(0xFF9A9AA5),
        brightness: Brightness.dark,
      );
}
