import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

typedef LoginCallback = Future<void> Function(String username, String password);

/// Figma'daki `Sign in` (54:21278) ekranının Flutter karşılığı.
///
/// Görsel ölçüler Figma ile aynı kalırken girişin yüklenme ve hata durumlarını
/// da yönetir.
class LoginPage extends StatefulWidget {
  const LoginPage({
    required this.onLogin,
    this.isRestoringSession = false,
    this.externalErrorMessage,
    super.key,
  });

  /// Callback yalnızca geçerli kullanıcı girdileriyle çağrılır; API hataları
  /// aynı ekran üzerinde kullanıcıya gösterilir.
  final LoginCallback onLogin;

  /// Uygulama açılışında güvenli kayıt kontrol edilirken formu geçici kapatır.
  final bool isRestoringSession;

  /// Oturum geri yükleme başarısızsa mevcut hata alanında gösterilir.
  final String? externalErrorMessage;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  bool get _isBusy => _isLoading || widget.isRestoringSession;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleErrorMessage = _errorMessage ?? widget.externalErrorMessage;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.primary,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = (constraints.maxWidth / 375)
                  .clamp(0.88, 1.12)
                  .toDouble();

              return Column(
                children: [
                  SizedBox(
                    height: 68 * scale,
                    child: Center(
                      child: Text(
                        'Giriş',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, contentConstraints) {
                          return SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: EdgeInsets.fromLTRB(
                              24 * scale,
                              24 * scale,
                              24 * scale,
                              16 * scale,
                            ),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight:
                                    (contentConstraints.maxHeight - 40 * scale)
                                        .clamp(0.0, double.infinity)
                                        .toDouble(),
                              ),
                              child: IntrinsicHeight(
                                child: AutofillGroup(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _LoginBrand(scale: scale),
                                      SizedBox(height: 34 * scale),
                                      const _FormLabel('Kullanıcı Adı'),
                                      SizedBox(height: 8 * scale),
                                      SizedBox(
                                        height: 52 * scale,
                                        child: _LoginTextField(
                                          fieldKey: const Key(
                                            'login-username-field',
                                          ),
                                          controller: _usernameController,
                                          hintText: 'Kullanıcı adınızı girin',
                                          scale: scale,
                                          prefixIcon:
                                              Icons.person_outline_rounded,
                                          keyboardType: TextInputType.text,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.username,
                                          ],
                                          enabled: !_isBusy,
                                        ),
                                      ),
                                      SizedBox(height: 18 * scale),
                                      const _FormLabel('Parola'),
                                      SizedBox(height: 8 * scale),
                                      SizedBox(
                                        height: 52 * scale,
                                        child: _LoginTextField(
                                          fieldKey: const Key(
                                            'login-password-field',
                                          ),
                                          controller: _passwordController,
                                          hintText: 'Parolanızı girin',
                                          scale: scale,
                                          prefixIcon:
                                              Icons.lock_outline_rounded,
                                          obscureText: _obscurePassword,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          onSubmitted: (_) => _submit(),
                                          enabled: !_isBusy,
                                          suffixIcon: IconButton(
                                            key: const Key(
                                              'login-password-visibility-toggle',
                                            ),
                                            tooltip: _obscurePassword
                                                ? 'Parolayı göster'
                                                : 'Parolayı gizle',
                                            onPressed: _isBusy
                                                ? null
                                                : () => setState(
                                                    () => _obscurePassword =
                                                        !_obscurePassword,
                                                  ),
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons
                                                        .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: AppColors.neutralSecondary,
                                              size: 20 * scale,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (visibleErrorMessage
                                          case final message?) ...[
                                        SizedBox(height: 14 * scale),
                                        _LoginErrorMessage(
                                          message: message,
                                          scale: scale,
                                        ),
                                      ],
                                      SizedBox(height: 24 * scale),
                                      _LoginButton(
                                        isBusy: _isBusy,
                                        scale: scale,
                                        onPressed: _submit,
                                      ),
                                      const Spacer(),
                                      SizedBox(height: 28 * scale),
                                      Text(
                                        'Cats Yazılım San. Tic. Ltd. Şti.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.neutralSecondary,
                                          fontSize: 11 * scale,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      SizedBox(height: 4 * scale),
                                      Text(
                                        'Sosyo-Bel App',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 11 * scale,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 10 * scale),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isBusy) return;

    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final validationMessage = _validate(username: username, password: password);
    if (validationMessage != null) {
      setState(() => _errorMessage = validationMessage);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onLogin(username, password);
      TextInput.finishAutofillContext();
    } on ApiException catch (error) {
      _showError(error.message);
    } on TokenStorageException {
      _showError('Oturum bilgisi güvenli biçimde kaydedilemedi.');
    } catch (_) {
      _showError('Giriş tamamlanamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validate({required String username, required String password}) {
    if (username.isEmpty) return 'Kullanıcı adınızı girin.';
    if (password.isEmpty) return 'Parolanızı girin.';
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _errorMessage = message);
  }
}

class _LoginBrand extends StatelessWidget {
  const _LoginBrand({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox.square(
          dimension: 84 * scale,
          child: Image.asset(
            AppAssets.splashLogo,
            key: const Key('login-brand-logo'),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
        SizedBox(height: 14 * scale),
        Text(
          'Sosyo-Bel',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 24 * scale,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        SizedBox(height: 5 * scale),
        Text(
          'Saha Ekipleri Modülü',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.neutralSecondary,
            fontSize: 12 * scale,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.neutralDark,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.3,
      ),
    );
  }
}

class _LoginErrorMessage extends StatelessWidget {
  const _LoginErrorMessage({required this.message, required this.scale});

  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.statusRejected.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12 * scale),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12 * scale,
            vertical: 10 * scale,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: AppColors.statusRejected,
                size: 18 * scale,
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  message,
                  key: const Key('login-error-message'),
                  style: TextStyle(
                    color: AppColors.statusRejected,
                    fontSize: 11 * scale,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({
    required this.isBusy,
    required this.scale,
    required this.onPressed,
  });

  final bool isBusy;
  final double scale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50 * scale,
      child: Semantics(
        button: true,
        enabled: !isBusy,
        label: 'Giriş',
        child: Material(
          color: isBusy ? AppColors.primaryMuted : AppColors.primary,
          borderRadius: BorderRadius.circular(14 * scale),
          child: InkWell(
            key: const Key('login-submit-button'),
            onTap: isBusy ? null : onPressed,
            borderRadius: BorderRadius.circular(14 * scale),
            child: Center(
              child: isBusy
                  ? SizedBox.square(
                      dimension: 20 * scale,
                      child: const CircularProgressIndicator(
                        key: Key('login-loading-indicator'),
                        color: AppColors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Giriş',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16 * scale,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.hintText,
    required this.scale,
    required this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.autofillHints,
    this.onSubmitted,
    this.fieldKey,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hintText;
  final double scale;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14 * scale),
      borderSide: const BorderSide(color: Color(0xFFE4E1EF), width: 1),
    );

    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      onSubmitted: onSubmitted,
      autocorrect: false,
      cursorColor: AppColors.primary,
      style: TextStyle(
        color: AppColors.neutralDark,
        fontSize: 14 * scale,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.neutralPlaceholder,
          fontSize: 14 * scale,
          fontWeight: FontWeight.w400,
          height: 1.3,
        ),
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8F7FC),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14 * scale,
          vertical: 14 * scale,
        ),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        disabledBorder: border,
        prefixIcon: Icon(
          prefixIcon,
          color: AppColors.neutralSecondary,
          size: 20 * scale,
        ),
        prefixIconConstraints: BoxConstraints.tightFor(
          width: 48 * scale,
          height: 52 * scale,
        ),
        suffixIcon: suffixIcon,
        suffixIconConstraints: BoxConstraints.tightFor(
          width: 48 * scale,
          height: 52 * scale,
        ),
      ),
    );
  }
}
