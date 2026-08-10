import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Uzun form içindeki bilgi gruplarını aynı görsel yapıyla ayırır.
class ApplicationFormSectionHeader extends StatelessWidget {
  const ApplicationFormSectionHeader({
    required this.icon,
    required this.title,
    super.key,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 21, color: AppColors.primarySecondary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.neutralDark,
                fontSize: 17,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: Color(0xFFECECF2)),
      ],
    );
  }
}
