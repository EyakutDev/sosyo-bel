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

  // Figma ekranının kaynak ölçüsü. Konumlar farklı telefon boyutlarına bu
  // referans üzerinden ölçeklenir; böylece tasarım oranları korunur.
  static const _referenceWidth = 375.0;
  static const _referenceHeight = 812.0;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final scaleX = screenSize.width / _referenceWidth;
    final scaleY = screenSize.height / _referenceHeight;
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
        resizeToAvoidBottomInset: false,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 108 * scaleY,
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
                  left: 164 * scaleX,
                  top: 65 * scaleY,
                  child: Text(
                    'Giriş',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 20 * scaleX,
                      fontWeight: FontWeight.w600,
                      height: 28 / 20,
                    ),
                  ),
                ),
                Positioned(
                  left: 24 * scaleX,
                  top: 128 * scaleY,
                  child: Text(
                    'Sosyo-Bel',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 24 * scaleX,
                      fontWeight: FontWeight.w600,
                      height: 28 / 24,
                    ),
                  ),
                ),
                Positioned(
                  left: 25 * scaleX,
                  top: 162 * scaleY,
                  child: Text(
                    'Saha Ekipleri Modülü',
                    style: TextStyle(
                      color: AppColors.neutralDark,
                      fontSize: 12 * scaleX,
                      fontWeight: FontWeight.w500,
                      height: 16 / 12,
                    ),
                  ),
                ),
                Positioned(
                  left: 116 * scaleX,
                  top: 227 * scaleY,
                  width: 150 * scaleX,
                  height: 150 * scaleX,
                  child: Image.asset(
                    AppAssets.logo,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned(
                  left: 24 * scaleX,
                  top: 409 * scaleY,
                  width: 327 * scaleX,
                  height: 44 * scaleX,
                  child: _LoginTextField(
                    fieldKey: const Key('login-username-field'),
                    controller: _usernameController,
                    hintText: 'Kullanıcı Adı',
                    scale: scaleX,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username],
                    enabled: !_isBusy,
                  ),
                ),
                Positioned(
                  left: 24 * scaleX,
                  top: 473 * scaleY,
                  width: 327 * scaleX,
                  height: 44 * scaleX,
                  child: _LoginTextField(
                    fieldKey: const Key('login-password-field'),
                    controller: _passwordController,
                    hintText: 'Parola',
                    scale: scaleX,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    enabled: !_isBusy,
                    suffixIcon: IconButton(
                      key: const Key('login-password-visibility-toggle'),
                      tooltip: _obscurePassword
                          ? 'Parolayı göster'
                          : 'Parolayı gizle',
                      onPressed: _isBusy
                          ? null
                          : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.neutralPlaceholder,
                        size: 18 * scaleX,
                      ),
                    ),
                  ),
                ),
                if (visibleErrorMessage case final message?)
                  Positioned(
                    left: 24 * scaleX,
                    top: 528 * scaleY,
                    width: 327 * scaleX,
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        key: const Key('login-error-message'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.statusRejected,
                          fontSize: 11 * scaleX,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 24 * scaleX,
                  top: 585 * scaleY,
                  width: 327 * scaleX,
                  height: 44 * scaleX,
                  child: Semantics(
                    button: true,
                    enabled: !_isBusy,
                    label: 'Giriş',
                    child: Material(
                      color: _isBusy
                          ? AppColors.primaryMuted
                          : AppColors.primarySecondary,
                      borderRadius: BorderRadius.circular(15 * scaleX),
                      child: InkWell(
                        key: const Key('login-submit-button'),
                        onTap: _isBusy ? null : _submit,
                        borderRadius: BorderRadius.circular(15 * scaleX),
                        child: Center(
                          child: _isBusy
                              ? SizedBox.square(
                                  dimension: 20 * scaleX,
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
                                    fontSize: 16 * scaleX,
                                    fontWeight: FontWeight.w500,
                                    height: 24 / 16,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 741 * scaleY,
                  child: Text(
                    'Cats Yazılım San. Tic. Ltd. Şti.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.neutralDark,
                      fontSize: 12 * scaleX,
                      fontWeight: FontWeight.w400,
                      height: 16 / 12,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 762 * scaleY,
                  child: Text(
                    'Sosyo-Bel App',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12 * scaleX,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ],
            ),
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

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.hintText,
    required this.scale,
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
      borderRadius: BorderRadius.circular(15 * scale),
      borderSide: const BorderSide(color: AppColors.neutralBorder, width: 1),
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
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppColors.neutralPlaceholder,
          fontSize: 14 * scale,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        isDense: true,
        filled: true,
        fillColor: AppColors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 12 * scale,
          vertical: 10 * scale,
        ),
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.primary, width: 1),
        ),
        // Etkileşimli parola ikonu, alanın sağındaki 46x44 bölgenin tamamını
        // dokunma hedefi olarak kullanır.
        suffixIcon: suffixIcon,
        suffixIconConstraints: BoxConstraints.tightFor(
          width: 46 * scale,
          height: 44 * scale,
        ),
      ),
    );
  }
}
