import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Oturumu kapatan işlemin yanlışlıkla çalışmasını önleyen onay penceresi.
Future<bool> showLogoutConfirmationDialog(BuildContext context) async {
  final isConfirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope<void>(
        canPop: false,
        child: Dialog(
          key: const Key('logout-confirmation-dialog'),
          backgroundColor: AppColors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEFF2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.statusRejected,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Çıkış Yap',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.neutralDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 24 / 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Oturumunuzu kapatıp giriş ekranına dönmek istediğinizden '
                  'emin misiniz?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.neutralSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 20 / 13,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _DialogButton(
                        buttonKey: const Key('logout-cancel-button'),
                        label: 'Vazgeç',
                        backgroundColor: AppColors.primarySurface,
                        foregroundColor: AppColors.primarySecondary,
                        onTap: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogButton(
                        buttonKey: const Key('logout-confirm-button'),
                        label: 'Çıkış Yap',
                        backgroundColor: AppColors.statusRejected,
                        foregroundColor: AppColors.white,
                        onTap: () => Navigator.of(dialogContext).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  return isConfirmed ?? false;
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.buttonKey,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: foregroundColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 18 / 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
