import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/activity/presentation/models/application_completion_payload.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';

typedef ApplicationCompletionAction =
    Future<void> Function(ApplicationCompletionPayload payload);

/// Figma'daki Tamamla ekranının (2024:26137) Flutter karşılığı.
///
/// Ekran yalnızca başvuru verisini toplar. Taslak kaydetme, kurul gönderimi ve
/// sonraki rota kararları callback'lerle uygulama akışında tutulur.
class ApplicationCompletionPage extends StatefulWidget {
  const ApplicationCompletionPage({
    required this.applicationDraft,
    required this.onBack,
    required this.onSaveDraft,
    required this.onSubmitToBoard,
    this.onNoteChanged,
    this.initiallySubmitted = false,
    this.showSubmittedConfirmation = false,
    super.key,
  }) : assert(
         !showSubmittedConfirmation || initiallySubmitted,
         'Gönderim bildirimi yalnızca kilitli ekranda gösterilebilir.',
       );

  final ApplicationDraft applicationDraft;
  final VoidCallback onBack;
  final ApplicationCompletionAction onSaveDraft;
  final ApplicationCompletionAction onSubmitToBoard;

  /// Üst okla forma dönülürse yazılmış notun yeniden yüklenmesini sağlar.
  final ValueChanged<String>? onNoteChanged;
  final bool initiallySubmitted;
  final bool showSubmittedConfirmation;

  @override
  State<ApplicationCompletionPage> createState() =>
      _ApplicationCompletionPageState();
}

class _ApplicationCompletionPageState extends State<ApplicationCompletionPage> {
  static const _referenceWidth = 375.0;
  static const _referenceHeight = 812.0;
  static const _draftColor = Color(0xFFF3B24A);
  static const _submitColor = Color(0xFFE97435);

  late final TextEditingController _noteController;
  late bool _isSubmitted;
  _CompletionAction? _activeAction;

  bool get _isBusy => _activeAction != null;

  @override
  void initState() {
    super.initState();
    assert(
      widget.applicationDraft.householdStatus != null,
      'Tamamla ekranı açılmadan önce hane taslağı tamamlanmalıdır.',
    );
    _noteController = TextEditingController(
      text: widget.applicationDraft.completionNote,
    );
    _isSubmitted = widget.initiallySubmitted;

    if (widget.showSubmittedConfirmation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Başvuru kurula gönderildi. Artık düzenlenemez.'),
              backgroundColor: AppColors.primary,
            ),
          );
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  ApplicationCompletionPayload _payload() {
    return ApplicationCompletionPayload(
      applicationDraft: widget.applicationDraft.copyWith(
        completionNote: _noteController.text,
      ),
    );
  }

  Future<void> _saveDraft() async {
    if (_isSubmitted || _isBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _activeAction = _CompletionAction.saveDraft);

    try {
      await widget.onSaveDraft(_payload());
    } catch (error) {
      _showActionError(error);
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  Future<void> _submitToBoard() async {
    if (_isSubmitted || _isBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _activeAction = _CompletionAction.submitToBoard);

    try {
      await widget.onSubmitToBoard(_payload());
      if (mounted) setState(() => _isSubmitted = true);
    } catch (error) {
      _showActionError(error);
    } finally {
      if (mounted) setState(() => _activeAction = null);
    }
  }

  void _showActionError(Object error) {
    if (!mounted) return;
    final message = error is ApiException
        ? error.message
        : 'Başvuru kaydedilemedi. Lütfen tekrar deneyin.';

    // Başarısız istekte rota kapatılmaz; personel verisini kaybetmeden aynı
    // ekranda düzeltme yapabilir veya idempotent anahtarla tekrar deneyebilir.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('completion-action-error-notice'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.white,
          elevation: 8,
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Color(0x22E85D75)),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.statusRejected,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.neutralDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final scale = screenSize.width / _referenceWidth;
    final contentHeight = math.max(screenSize.height, _referenceHeight * scale);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SingleChildScrollView(
          child: SizedBox(
            width: screenSize.width,
            height: contentHeight,
            child: Stack(
              children: [
                Positioned(
                  left: 17 * scale,
                  top: 142 * scale,
                  width: 342 * scale,
                  height: 188 * scale,
                  child: Image.asset(
                    // Varlık yolu merkezidir; doğrudan Figma dışa aktarımı
                    // geldiğinde ekran koduna dokunmadan görsel değiştirilebilir.
                    AppAssets.completionIllustration,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned(
                  left: 24 * scale,
                  right: 24 * scale,
                  top: 375 * scale,
                  height: 24 * scale,
                  child: Text(
                    'Haneye Ait Ekstra Notunuz',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primarySecondary,
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w500,
                      height: 24 / 14,
                    ),
                  ),
                ),
                Positioned(
                  left: 24 * scale,
                  top: 423 * scale,
                  width: 327 * scale,
                  height: 63 * scale,
                  child: Text(
                    'Girdiğiniz Bilgileri Kontrol Edin\n'
                    'Ve İletmek İstediğiniz Not Varsa Paylaşın',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.neutralDark,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      height: 21 / 12,
                    ),
                  ),
                ),
                Positioned(
                  left: 48 * scale,
                  top: 501 * scale,
                  width: 295 * scale,
                  height: 175 * scale,
                  child: TextField(
                    key: const Key('completion-note-field'),
                    controller: _noteController,
                    onChanged: widget.onNoteChanged,
                    readOnly: _isSubmitted || _isBusy,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      color: AppColors.neutralDark,
                      fontSize: 14 * scale,
                      fontWeight: FontWeight.w400,
                      height: 21 / 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Notunuzu Bu Alana Girebilirsiniz',
                      hintStyle: TextStyle(
                        color: AppColors.neutralPlaceholder,
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w400,
                        height: 21 / 14,
                      ),
                      contentPadding: EdgeInsets.fromLTRB(
                        16 * scale,
                        9 * scale,
                        16 * scale,
                        9 * scale,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15 * scale),
                        borderSide: const BorderSide(
                          color: AppColors.neutralBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15 * scale),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 34 * scale,
                  top: 704 * scale,
                  width: 153 * scale,
                  height: 48 * scale,
                  child: _CompletionActionButton(
                    buttonKey: const Key('completion-save-draft-button'),
                    label: 'Taslağı Kaydet',
                    color: _draftColor,
                    scale: scale,
                    isEnabled: !_isSubmitted && !_isBusy,
                    isLoading: _activeAction == _CompletionAction.saveDraft,
                    onTap: _saveDraft,
                  ),
                ),
                Positioned(
                  left: 199 * scale,
                  top: 704 * scale,
                  width: 152 * scale,
                  height: 48 * scale,
                  child: _CompletionActionButton(
                    buttonKey: const Key('completion-submit-board-button'),
                    label: 'Kurula Gönder',
                    color: _submitColor,
                    scale: scale,
                    isEnabled: !_isSubmitted && !_isBusy,
                    isLoading: _activeAction == _CompletionAction.submitToBoard,
                    onTap: _submitToBoard,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 65 * scale,
                  child: ColoredBox(
                    color: AppColors.white,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 12 * scale,
                          top: 19 * scale,
                          width: 40 * scale,
                          height: 40 * scale,
                          child: IconButton(
                            key: const Key('completion-header-back-button'),
                            padding: EdgeInsets.zero,
                            tooltip: 'Geri',
                            onPressed: _isBusy ? null : widget.onBack,
                            icon: Transform.rotate(
                              angle: math.pi / 2,
                              child: SvgPicture.asset(
                                AppAssets.activityBackArrow,
                                width: 16 * scale,
                                height: 9 * scale,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 56 * scale,
                          top: 29 * scale,
                          child: Text(
                            'Tamamla',
                            style: TextStyle(
                              color: AppColors.neutralDark,
                              fontSize: 20 * scale,
                              fontWeight: FontWeight.w600,
                              height: 28 / 20,
                            ),
                          ),
                        ),
                      ],
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
}

class _CompletionActionButton extends StatelessWidget {
  const _CompletionActionButton({
    required this.buttonKey,
    required this.label,
    required this.color,
    required this.scale,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  final Key buttonKey;
  final String label;
  final Color color;
  final double scale;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isEnabled ? 1 : 0.55,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(15 * scale),
        child: InkWell(
          key: buttonKey,
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(15 * scale),
          child: Center(
            child: isLoading
                ? SizedBox(
                    key: const Key('completion-action-loading-indicator'),
                    width: 18 * scale,
                    height: 18 * scale,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 12 * scale,
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

enum _CompletionAction { saveDraft, submitToBoard }
