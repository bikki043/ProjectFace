import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Two-family type system: Kanit for display/headings (geometric,
/// slightly rounded — common in Thai fintech apps) and Sarabun for body
/// copy (designed for long-form Thai readability).
///
/// Requires the `google_fonts` package. Add to pubspec.yaml:
///   dependencies:
///     google_fonts: ^6.2.1
class AppText {
  AppText._();

  static TextStyle get displayLg => GoogleFonts.kanit(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
        height: 1.2,
      );

  static TextStyle get displayMd => GoogleFonts.kanit(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      );

  static TextStyle get statNumber => GoogleFonts.kanit(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        height: 1.0,
      );

  static TextStyle get body => GoogleFonts.sarabun(
        fontSize: 14,
        color: AppColors.ink,
        height: 1.4,
      );

  static TextStyle get bodyDim => GoogleFonts.sarabun(
        fontSize: 13,
        color: AppColors.inkDim,
        height: 1.4,
      );

  static TextStyle get label => GoogleFonts.sarabun(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.inkDim,
      );

  static TextStyle get button => GoogleFonts.kanit(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );
}