import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/core/widgets/app_notice.dart';
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
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

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
                right: 24 * scale,
                top: 70 * scale,
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12 * scale),
                      child: Image.asset(
                        'assets/images/sosyo_bel_header_logo.png',
                        key: const Key('action-selection-brand-logo'),
                        width: 48 * scale,
                        height: 48 * scale,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sosyo-Bel',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 24 * scale,
                              fontWeight: FontWeight.w600,
                              height: 28 / 24,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          Text(
                            'Yapmak istediğiniz işlemi seçiniz',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 14 * scale,
                              fontWeight: FontWeight.w400,
                              height: 21 / 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    SizedBox(height: 40 * scale),
                    _ActionCard(
                      title: 'Başvuru Yap',
                      description: 'Yeni sosyal yardım başvurusu oluşturun.',
                      icon: Icons.description_outlined,
                      onTap: _isLoggingOut ? null : widget.onNewApplication,
                      scale: scale,
                    ),
                    SizedBox(height: 14 * scale),
                    _ActionCard(
                      title: 'Görevler',
                      description: 'Görevlerinizi görüntüleyin ve yönetin.',
                      icon: Icons.assignment_outlined,
                      onTap: _isLoggingOut ? null : widget.onTasks,
                      scale: scale,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: (28 * scale) + bottomSafeArea,
                child: Center(
                  child: _LogoutButton(
                    isLoading: _isLoggingOut,
                    scale: scale,
                    onTap: _isLoggingOut ? null : _confirmAndLogout,
                  ),
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
      showAppNotice(
        context,
        message: 'Çıkış yapılamadı. Lütfen tekrar deneyin.',
        tone: AppNoticeTone.error,
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
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13 * scale),
        side: BorderSide(color: AppColors.statusRejected, width: 1.25 * scale),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('action-selection-logout-button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(13 * scale),
        child: SizedBox(
          width: 150 * scale,
          height: 44 * scale,
          child: Center(
            child: isLoading
                ? SizedBox.square(
                    dimension: 18 * scale,
                    child: const CircularProgressIndicator(
                      key: Key('action-selection-logout-loading'),
                      color: AppColors.statusRejected,
                      strokeWidth: 2,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: AppColors.statusRejected,
                        size: 18 * scale,
                      ),
                      SizedBox(width: 7 * scale),
                      Text(
                        'Çıkış Yap',
                        style: TextStyle(
                          color: AppColors.statusRejected,
                          fontSize: 13 * scale,
                          fontWeight: FontWeight.w600,
                          height: 20 / 13,
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
      elevation: 1.5,
      shadowColor: AppColors.primary.withValues(alpha: 0.10),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17 * scale),
        side: const BorderSide(color: Color(0xFFE3E0F4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17 * scale),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 14 * scale,
          ),
          child: Row(
            children: [
              Container(
                width: 48 * scale,
                height: 48 * scale,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14 * scale),
                ),
                child: Icon(icon, color: AppColors.white, size: 24 * scale),
              ),
              SizedBox(width: 14 * scale),
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
              Container(
                width: 30 * scale,
                height: 30 * scale,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 21 * scale,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
