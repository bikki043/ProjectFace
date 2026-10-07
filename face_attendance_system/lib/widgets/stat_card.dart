import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A single metric card: colored icon chip, big number, small label.
/// [accentColor]/[accentSoft] are nullable and resolved at build time
/// (they used to default straight to AppColors.primary, but AppColors
/// is no longer `const`-safe now that it supports theme switching).
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final Color? accentSoft;
  final bool isWarn; // kept for backward compatibility; forces coral accent

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor,
    this.accentSoft,
    this.isWarn = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color chipColor = isWarn ? AppColors.coral : (accentColor ?? AppColors.primary);
    final Color chipSoft = isWarn ? AppColors.coralSoft : (accentSoft ?? AppColors.primarySoft);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: chipSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: chipColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value, style: AppText.statNumber),
          const SizedBox(height: 2),
          Text(title, style: AppText.bodyDim),
        ],
      ),
    );
  }
}
