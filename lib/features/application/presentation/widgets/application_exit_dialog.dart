import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Tamamlanmamış başvurudan çıkarken aynı uyarı tasarımını bütün ekranlarda
/// kullanır. `true` sonucu başvurunun tamamen kapatılmasını onaylar.
Future<bool> showApplicationExitDialog(BuildContext context) async {
  return _showApplicationWarningDialog(
    context,
    dialogKey: const Key('application-exit-dialog'),
    title: 'Başvuru Tamamlanmadı',
    message:
        'Başvuruyu kapatırsanız girdiğiniz bilgiler kaybolacak. '
        'Devam etmek istiyor musunuz?',
    stayButtonKey: const Key('application-exit-stay-button'),
    confirmButtonKey: const Key('application-exit-confirm-button'),
    confirmLabel: 'Başvuruyu Kapat',
  );
}

/// Aktivite başlığındaki geri okuna özel uyarıdır. Bu işlem başvuruyu kapatmaz;
/// mevcut form ve saha taslağı korunarak ilk başvuru ekranına dönülür.
Future<bool> showActivityReturnDialog(BuildContext context) {
  return _showApplicationWarningDialog(
    context,
    dialogKey: const Key('activity-return-dialog'),
    title: 'Başvuru Ekranına Dön',
    message:
        'Aktivite adımlarından ayrılıp başvuru ekranına dönmek '
        'istediğinizden emin misiniz? Girdiğiniz bilgiler korunacak.',
    stayButtonKey: const Key('activity-return-stay-button'),
    confirmButtonKey: const Key('activity-return-confirm-button'),
    confirmLabel: 'Başvuruya Dön',
  );
}

/// Kullanıcının yalnız bu cihazda saklanan bir taslağı yanlışlıkla silmesini
/// önler. Onaylandığında çağıran katman taslağı ve yerel fotoğraf kopyalarını
/// depodan kaldırır.
Future<bool> showLocalDraftDeleteDialog(BuildContext context) {
  return _showApplicationWarningDialog(
    context,
    dialogKey: const Key('local-draft-delete-dialog'),
    title: 'Yerel taslak silinsin mi?',
    message:
        'Taslak ve taslağa eklenen fotoğrafların yerel kopyaları bu cihazdan '
        'silinecek. Bu işlem geri alınamaz.',
    stayButtonKey: const Key('local-draft-delete-cancel-button'),
    confirmButtonKey: const Key('local-draft-delete-confirm-button'),
    confirmLabel: 'Taslağı Sil',
    icon: Icons.delete_outline_rounded,
    iconBackgroundColor: const Color(0xFFFFEEF2),
    iconColor: AppColors.statusRejected,
    confirmBackgroundColor: AppColors.statusRejected,
  );
}

Future<bool> _showApplicationWarningDialog(
  BuildContext context, {
  required Key dialogKey,
  required String title,
  required String message,
  required Key stayButtonKey,
  required Key confirmButtonKey,
  required String confirmLabel,
  IconData icon = Icons.warning_amber_rounded,
  Color iconBackgroundColor = const Color(0xFFFFF3EB),
  Color iconColor = AppColors.statusBoard,
  Color confirmBackgroundColor = AppColors.primary,
}) async {
  final isConfirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope<void>(
        canPop: false,
        child: Dialog(
          key: dialogKey,
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
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 30),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.neutralDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 24 / 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
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
                      child: _DialogActionButton(
                        buttonKey: stayButtonKey,
                        label: 'Vazgeç',
                        backgroundColor: AppColors.primarySurface,
                        foregroundColor: AppColors.primarySecondary,
                        onTap: () => Navigator.of(dialogContext).pop(false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DialogActionButton(
                        buttonKey: confirmButtonKey,
                        label: confirmLabel,
                        backgroundColor: confirmBackgroundColor,
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

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
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
              textAlign: TextAlign.center,
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
