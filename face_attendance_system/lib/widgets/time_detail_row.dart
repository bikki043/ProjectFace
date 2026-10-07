import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class TimeDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const TimeDetailRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.ink;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: resolvedColor, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: AppColors.inkDim, fontSize: 13)),
          ],
        ),
        Text(value, style: TextStyle(color: resolvedColor, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
