import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

enum AppNoticeTone { info, success, error }

void showAppNotice(
  BuildContext context, {
  required String message,
  AppNoticeTone tone = AppNoticeTone.info,
  Key? key,
  Duration duration = const Duration(milliseconds: 2400),
  EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(24, 0, 24, 88),
}) {
  final appearance = switch (tone) {
    AppNoticeTone.info => const _NoticeAppearance(
      color: AppColors.primary,
      icon: Icons.info_outline_rounded,
    ),
    AppNoticeTone.success => const _NoticeAppearance(
      color: AppColors.statusApproved,
      icon: Icons.check_rounded,
    ),
    AppNoticeTone.error => const _NoticeAppearance(
      color: AppColors.statusRejected,
      icon: Icons.error_outline_rounded,
    ),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: key,
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.white,
        elevation: 8,
        duration: duration,
        margin: margin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: appearance.color.withValues(alpha: 0.16)),
        ),
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: appearance.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(appearance.icon, color: appearance.color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.neutralDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

class _NoticeAppearance {
  const _NoticeAppearance({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
