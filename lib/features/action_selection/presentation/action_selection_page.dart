import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/auth/presentation/widgets/logout_confirmation_dialog.dart';

/// Kullanıcının girişten sonra yapacağı işlemi seçtiği ara ekran.
///
/// Bu ekran hedef sayfaları doğrudan tanımaz. Böylece başvuru ve görev
/// akışlarının yönlendirme kararı, uygulamanın navigasyon katmanında kalır.
class ActionSelectionPage extends StatefulWidget {
  const ActionSelectionPage({
    required this.onNewApplication,
    required this.onTasks,
    required this.onLogout,
    super.key,
  });

  final VoidCallback onNewApplication;
  final VoidCallback onTasks;
  final Future<void> Function() onLogout;

  @override
  State<ActionSelectionPage> createState() => _ActionSelectionPageState();
}

class _ActionSelectionPageState extends State<ActionSelectionPage> {
  bool _isLoggingOut = false;

  static const _referenceWidth = 375.0;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _referenceWidth;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: PopScope<void>(
        // Giriş ekranına dönmek oturumu kapatmalıdır; sistem geri eylemi bu
        // güvenlik adımını atlayamaz.
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.primary,
          body: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 183 * scale,
                bottom: 0,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24 * scale,
                top: 76 * scale,
                child: Text(
                  'Sosyo-Bel',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 24 * scale,
                    fontWeight: FontWeight.w600,
                    height: 28 / 24,
                  ),
                ),
              ),
              Positioned(
                left: 24 * scale,
                top: 119 * scale,
                child: Text(
                  'Yapmak istediğiniz işlemi seçiniz',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 14 * scale,
                    fontWeight: FontWeight.w400,
                    height: 21 / 14,
                  ),
                ),
              ),
              Positioned(
                left: 24 * scale,
                right: 24 * scale,
                top: 229 * scale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'İşlem Seçimi',
                      style: TextStyle(
                        color: AppColors.neutralDark,
                        fontSize: 20 * scale,
                        fontWeight: FontWeight.w600,
                        height: 28 / 20,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      'Devam etmek istediğiniz alanı seçin.',
                      style: TextStyle(
                        color: AppColors.neutralSecondary,
                        fontSize: 13 * scale,
                        fontWeight: FontWeight.w400,
                        height: 20 / 13,
                      ),
                    ),
                    SizedBox(height: 32 * scale),
                    _ActionCard(
                      title: 'Başvuru Yap',
                      description:
                          'Yeni bir sosyal yardım başvurusu oluşturun.',
                      icon: Icons.description_outlined,
                      onTap: _isLoggingOut ? null : widget.onNewApplication,
                      scale: scale,
                    ),
                    SizedBox(height: 20 * scale),
                    _ActionCard(
                      title: 'Görevler',
                      description:
                          'Bekleyen ve tamamlanmış görevlerinizi görüntüleyin.',
                      icon: Icons.assignment_outlined,
                      onTap: _isLoggingOut ? null : widget.onTasks,
                      scale: scale,
                    ),
                    SizedBox(height: 32 * scale),
                    _LogoutButton(
                      isLoading: _isLoggingOut,
                      scale: scale,
                      onTap: _isLoggingOut ? null : _confirmAndLogout,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showLogoutConfirmationDialog(context);
    if (!mounted || !shouldLogout) return;

    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çıkış yapılamadı. Lütfen tekrar deneyin.'),
          backgroundColor: AppColors.statusRejected,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.isLoading,
    required this.scale,
    required this.onTap,
  });

  final bool isLoading;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.statusRejected,
      borderRadius: BorderRadius.circular(15 * scale),
      child: InkWell(
        key: const Key('action-selection-logout-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(15 * scale),
        child: SizedBox(
          height: 48 * scale,
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: 20 * scale,
                    child: const CircularProgressIndicator(
                      key: Key('action-selection-logout-loading'),
                      color: AppColors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: AppColors.white,
                        size: 20 * scale,
                      ),
                      SizedBox(width: 8 * scale),
                      Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 14 * scale,
                          fontWeight: FontWeight.w600,
                          height: 20 / 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Seçeneklerin görsel ve dokunma davranışını tek yerde tutan ortak kart.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    required this.scale,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(15 * scale),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15 * scale),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 20 * scale,
          ),
          child: Row(
            children: [
              Container(
                width: 52 * scale,
                height: 52 * scale,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(15 * scale),
                ),
                child: Icon(icon, color: AppColors.white, size: 26 * scale),
              ),
              SizedBox(width: 16 * scale),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.neutralDark,
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w600,
                        height: 24 / 16,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.neutralSecondary,
                        fontSize: 12 * scale,
                        fontWeight: FontWeight.w400,
                        height: 18 / 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 24 * scale,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
