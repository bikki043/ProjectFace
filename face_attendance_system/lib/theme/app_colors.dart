import 'package:flutter/material.dart';
import 'app_theme.dart';

/// Every screen reads its colors from here instead of hardcoding hex
/// values. These are now GETTERS backed by a mutable palette — when
/// the person changes theme/accent in Settings, [apply] swaps every
/// value at once.
///
/// IMPORTANT — because these are no longer compile-time constants:
///  - they can NOT appear inside a `const` widget anymore
///    (`const TextStyle(color: AppColors.ink)` will fail to compile —
///    drop the `const`).
///  - they can NOT be used as a constructor default parameter value
///    (`this.color = AppColors.ink`) — make the parameter nullable
///    and resolve the default inside build() instead.
/// Every file in this project has already been updated for this; keep
/// it in mind for any NEW widget you add later.
class AppColors {
  AppColors._();

  static AppPalette _p = AppPalette.dark(AppAccent.indigo);

  static void apply(AppPalette palette) => _p = palette;

  static Color get bg => _p.bg;
  static Color get surface => _p.surface;
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get divider => _p.divider;

  static Color get primary => _p.primary;
  static Color get primaryDark => _p.primaryDark;
  static Color get primarySoft => _p.primarySoft;

  static Color get mint => _p.mint;
  static Color get mintSoft => _p.mintSoft;
  static Color get amber => _p.amber;
  static Color get amberSoft => _p.amberSoft;
  static Color get coral => _p.coral;
  static Color get coralSoft => _p.coralSoft;

  static Color get ink => _p.ink;
  static Color get inkDim => _p.inkDim;

  // --- Backward-compat aliases (old dark-theme naming) --------------
  static Color get panel => surface;
  static Color get panelLine => divider;
  static Color get accent => primary;
  static Color get danger => coral;
}
