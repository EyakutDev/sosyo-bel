import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/widgets/activity_step_tabs.dart';

typedef HouseholdPhotoCapture = Future<HouseholdPhotoViewData?> Function();
typedef HouseholdLostPhotoRecovery =
    Future<List<HouseholdPhotoViewData>> Function();

enum HouseholdStatusStage { questions, photos }

/// Figma'daki Hane Durumu soru (2021:24845) ve fotoğraf (2024:25104)
/// ekranlarının Flutter karşılığı.
///
/// Saha cevapları ile çekilen fotoğraflar bu sayfada bir taslakta birikir.
/// Backend geldiğinde [onContinue] üzerinden aynı taslak API katmanına
/// aktarılabilir; sayfa herhangi bir sunucu sağlayıcısına bağlı değildir.
class HouseholdStatusPage extends StatefulWidget {
  const HouseholdStatusPage({
    required this.onBack,
    required this.onContinue,
    required this.onCapturePhoto,
    required this.questions,
    this.onHeaderBack,
    this.onDraftChanged,
    this.onRecoverLostPhotos,
    this.initialPhotos = const [],
    this.initialDraft,
    this.initialStage = HouseholdStatusStage.questions,
    this.allowPhotoChanges = true,
    this.existingPhotoCount = 0,
    super.key,
  }) : assert(existingPhotoCount >= 0);

  /// Soru aşamasında alt `Geri Dön` düğmesinin açacağı önceki Aktivite adımı.
  final VoidCallback onBack;

  /// Üst Aktivite okunun uyarılı dönüşü alt düğmeden ayrı tutulur.
  final VoidCallback? onHeaderBack;
  final ValueChanged<HouseholdStatusDraft> onContinue;
  final ValueChanged<HouseholdStatusDraft>? onDraftChanged;
  final HouseholdPhotoCapture onCapturePhoto;
  final HouseholdLostPhotoRecovery? onRecoverLostPhotos;
  final List<HouseholdQuestionViewData> questions;
  final List<HouseholdPhotoViewData> initialPhotos;
  final HouseholdStatusDraft? initialDraft;
  final HouseholdStatusStage initialStage;
  final bool allowPhotoChanges;
  final int existingPhotoCount;

  @override
  State<HouseholdStatusPage> createState() => _HouseholdStatusPageState();
}

class _HouseholdStatusPageState extends State<HouseholdStatusPage> {
  static const _referenceWidth = 375.0;
  static const _referenceHeight = 812.0;

  final Map<String, String> _answers = {};
  late final List<HouseholdPhotoViewData> _photos;
  late HouseholdStatusStage _stage;
  bool _saveToBeneficiaryDirectory = false;
  bool _replaceRemotePhotosOnSave = false;
  bool _isCapturingPhoto = false;

  @override
  void initState() {
    super.initState();
    _stage = widget.initialStage;
    _answers.addAll(widget.initialDraft?.answers ?? const {});
    _photos = (widget.initialDraft?.photos ?? widget.initialPhotos)
        .take(HouseholdPhotoPolicy.maxPhotoCount)
        .toList();
    _saveToBeneficiaryDirectory =
        widget.initialDraft?.saveToBeneficiaryDirectory ?? false;
    _replaceRemotePhotosOnSave =
        widget.initialDraft?.replaceRemotePhotosOnSave ?? false;

    if (widget.allowPhotoChanges && widget.onRecoverLostPhotos != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recoverLostPhotos());
    }
  }

  HouseholdStatusDraft get _currentDraft => HouseholdStatusDraft(
    answers: Map.unmodifiable(_answers),
    photos: List.unmodifiable(_photos),
    saveToBeneficiaryDirectory: _saveToBeneficiaryDirectory,
    replaceRemotePhotosOnSave: _replaceRemotePhotosOnSave,
  );

  void _notifyDraftChanged() {
    widget.onDraftChanged?.call(_currentDraft);
  }

  Future<void> _recoverLostPhotos() async {
    try {
      final recovered = await widget.onRecoverLostPhotos!.call();
      if (!mounted || recovered.isEmpty) {
        return;
      }

      final availableSlots =
          HouseholdPhotoPolicy.maxPhotoCount - _photos.length;
      if (availableSlots <= 0) {
        return;
      }
      setState(() {
        _photos.addAll(recovered.take(availableSlots));
      });
      _notifyDraftChanged();
    } catch (_) {
      if (mounted) {
        _showMessage('Kamera işlemi kurtarılamadı. Lütfen tekrar deneyin.');
      }
    }
  }

  void _goBack() {
    if (_stage == HouseholdStatusStage.photos) {
      // Alt düğme sayfadan çıkmadan önce fotoğraf aşamasından sorulara döner.
      setState(() => _stage = HouseholdStatusStage.questions);
      return;
    }

    widget.onBack();
  }

  void _continue() {
    if (_stage == HouseholdStatusStage.questions) {
      // Zorunluluk API referans kataloğından gelir. Kod ve seçenek birlikte
      // doğrulanarak eski veya artık aktif olmayan bir taslak cevabı kabul edilmez.
      final missingQuestion = widget.questions
          .where((question) => question.isRequired)
          .where(
            (question) => !question.options.any(
              (option) => option.code == _answers[question.id],
            ),
          )
          .firstOrNull;
      if (missingQuestion != null) {
        _showMessage('Lütfen "${missingQuestion.label}" sorusunu cevaplayın.');
        return;
      }

      if (!widget.allowPhotoChanges) {
        widget.onContinue(_currentDraft);
        return;
      }
      setState(() => _stage = HouseholdStatusStage.photos);
      return;
    }

    widget.onContinue(_currentDraft);
  }

  Future<void> _capturePhoto() async {
    if (!widget.allowPhotoChanges) return;
    // İş kuralı tek noktada uygulanır; kullanıcı arayüzü veya ilerideki API
    // yanlışlıkla on altıncı fotoğrafı ekleyemez.
    if (_photos.length >= HouseholdPhotoPolicy.maxPhotoCount) {
      _showMessage(HouseholdPhotoPolicy.maxPhotoMessage);
      return;
    }
    if (_isCapturingPhoto) {
      return;
    }

    setState(() => _isCapturingPhoto = true);
    try {
      final photo = await widget.onCapturePhoto();
      if (!mounted || photo == null) {
        return;
      }

      if (_photos.length < HouseholdPhotoPolicy.maxPhotoCount) {
        setState(() => _photos.add(photo));
        _notifyDraftChanged();
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Fotoğraf alınamadı. Lütfen tekrar deneyin.');
      }
    } finally {
      if (mounted) {
        setState(() => _isCapturingPhoto = false);
      }
    }
  }

  void _removePhoto(int index) {
    if (!widget.allowPhotoChanges) return;
    if (index < 0 || index >= _photos.length) return;

    // Sınır liste uzunluğundan hesaplandığı için silinen fotoğraf yeni çekime
    // otomatik olarak yer açar.
    setState(() => _photos.removeAt(index));
    _notifyDraftChanged();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.primary),
      );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final topSafeArea = MediaQuery.paddingOf(context).top;
    final scale = screenSize.width / _referenceWidth;
    final contentHeight = math.max(screenSize.height, _referenceHeight * scale);
    final isQuestions = _stage == HouseholdStatusStage.questions;

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
                  left: 0,
                  right: 0,
                  top: 202 * scale,
                  bottom: 0,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x0D000000),
                          offset: Offset(0, -2),
                          blurRadius: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 169.5 * scale,
                  top: 208 * scale,
                  width: 36 * scale,
                  height: 4 * scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x80BCBCBC),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
                Positioned(
                  left: 24 * scale,
                  top: 116 * scale,
                  child: ActivityStepTabs(
                    selectedStep: ActivityStep.household,
                    scale: scale,
                  ),
                ),
                Positioned(
                  left: 36 * scale,
                  top: 238 * scale,
                  width: 137 * scale,
                  height: 44 * scale,
                  child: _SectionTab(
                    tabKey: const Key('household-questions-tab'),
                    label: 'Sorular',
                    isSelected: isQuestions,
                    scale: scale,
                    onTap: () =>
                        setState(() => _stage = HouseholdStatusStage.questions),
                  ),
                ),
                Positioned(
                  left: 208 * scale,
                  top: 238 * scale,
                  width: 132 * scale,
                  height: 44 * scale,
                  child: _SectionTab(
                    tabKey: const Key('household-photos-tab'),
                    label: 'Fotoğraflar',
                    isSelected: !isQuestions,
                    scale: scale,
                    onTap: () =>
                        setState(() => _stage = HouseholdStatusStage.photos),
                  ),
                ),
                Positioned(
                  left: 24 * scale,
                  top: 299 * scale,
                  width: 327 * scale,
                  height: 404 * scale,
                  child: isQuestions
                      ? _QuestionsCard(
                          questions: widget.questions,
                          answers: _answers,
                          scale: scale,
                          onChanged: (questionId, value) {
                            setState(() => _answers[questionId] = value);
                            _notifyDraftChanged();
                          },
                        )
                      : _PhotosCard(
                          photos: _photos,
                          scale: scale,
                          allowChanges: widget.allowPhotoChanges,
                          existingPhotoCount: widget.existingPhotoCount,
                          isCapturing: _isCapturingPhoto,
                          saveToBeneficiaryDirectory:
                              _saveToBeneficiaryDirectory,
                          onCapture: _capturePhoto,
                          onRemovePhoto: _removePhoto,
                          onToggleSave: () {
                            setState(
                              () => _saveToBeneficiaryDirectory =
                                  !_saveToBeneficiaryDirectory,
                            );
                            _notifyDraftChanged();
                          },
                        ),
                ),
                Positioned(
                  left: (isQuestions ? 34 : 27) * scale,
                  top: (isQuestions ? 716 : 717) * scale,
                  width: 143 * scale,
                  height: 36 * scale,
                  child: _BottomActionButton(
                    buttonKey: const Key('household-back-button'),
                    label: 'Geri Dön',
                    backgroundColor: AppColors.primaryMuted,
                    isBack: true,
                    scale: scale,
                    onTap: _goBack,
                  ),
                ),
                Positioned(
                  left: (isQuestions ? 208 : 201) * scale,
                  top: (isQuestions ? 716 : 717) * scale,
                  width: 143 * scale,
                  height: 36 * scale,
                  child: _BottomActionButton(
                    buttonKey: const Key('household-continue-button'),
                    label: 'Devam Et',
                    backgroundColor: AppColors.primary,
                    scale: scale,
                    onTap: _continue,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  // Üst geri düğmesi durum çubuğu ve kamera çentiğinin
                  // dokunma alanıyla çakışmamalıdır.
                  top: topSafeArea,
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
                            key: const Key('household-header-back-button'),
                            padding: EdgeInsets.zero,
                            tooltip: 'Geri',
                            onPressed: widget.onHeaderBack ?? widget.onBack,
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
                            'Aktivite',
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

class _SectionTab extends StatelessWidget {
  const _SectionTab({
    required this.tabKey,
    required this.label,
    required this.isSelected,
    required this.scale,
    required this.onTap,
  });

  final Key tabKey;
  final String label;
  final bool isSelected;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.primarySecondary : AppColors.primarySurface,
      borderRadius: BorderRadius.circular(15 * scale),
      child: InkWell(
        key: tabKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(15 * scale),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? AppColors.primarySurface
                  : AppColors.neutralPlaceholder,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w500,
              height: 24 / 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionsCard extends StatelessWidget {
  const _QuestionsCard({
    required this.questions,
    required this.answers,
    required this.scale,
    required this.onChanged,
  });

  final List<HouseholdQuestionViewData> questions;
  final Map<String, String> answers;
  final double scale;
  final void Function(String questionId, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return _HouseholdCard(
      scale: scale,
      child: Stack(
        children: [
          for (var index = 0; index < questions.length; index++)
            Positioned(
              left: 16 * scale,
              top: (24 + (index * 68)) * scale,
              width: 295 * scale,
              height: 44 * scale,
              child: _QuestionDropdown(
                question: questions[index],
                value: answers[questions[index].id],
                scale: scale,
                onChanged: (value) => onChanged(questions[index].id, value),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionDropdown extends StatelessWidget {
  const _QuestionDropdown({
    required this.question,
    required this.value,
    required this.scale,
    required this.onChanged,
  });

  final HouseholdQuestionViewData question;
  final String? value;
  final double scale;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.neutralBorder),
        borderRadius: BorderRadius.circular(15 * scale),
      ),
      padding: EdgeInsets.only(left: 12 * scale, right: 21 * scale),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          key: Key('household-question-${question.id}'),
          value: value,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(15 * scale),
          dropdownColor: AppColors.white,
          hint: Text(
            question.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.neutralSecondary,
              fontSize: 14 * scale,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          icon: Text(
            'v',
            style: TextStyle(
              color: const Color(0xFFBFBFBF),
              fontSize: 14 * scale,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          style: TextStyle(
            color: AppColors.neutralDark,
            fontSize: 14 * scale,
            fontWeight: FontWeight.w500,
            height: 1.5,
          ),
          items: [
            for (final option in question.options)
              DropdownMenuItem(value: option.code, child: Text(option.label)),
          ],
          onChanged: (selectedValue) {
            if (selectedValue != null) {
              onChanged(selectedValue);
            }
          },
        ),
      ),
    );
  }
}

class _PhotosCard extends StatelessWidget {
  const _PhotosCard({
    required this.photos,
    required this.scale,
    required this.allowChanges,
    required this.existingPhotoCount,
    required this.isCapturing,
    required this.saveToBeneficiaryDirectory,
    required this.onCapture,
    required this.onRemovePhoto,
    required this.onToggleSave,
  });

  final List<HouseholdPhotoViewData> photos;
  final double scale;
  final bool allowChanges;
  final int existingPhotoCount;
  final bool isCapturing;
  final bool saveToBeneficiaryDirectory;
  final VoidCallback onCapture;
  final ValueChanged<int> onRemovePhoto;
  final VoidCallback onToggleSave;

  @override
  Widget build(BuildContext context) {
    return _HouseholdCard(
      scale: scale,
      child: Stack(
        children: [
          if (!allowChanges)
            Positioned.fill(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28 * scale),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 46 * scale,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 16 * scale),
                    Text(
                      existingPhotoCount == 0
                          ? 'Bu başvuruda kayıtlı hane fotoğrafı bulunmuyor.'
                          : '${existingPhotoCount.toString()} kayıtlı hane '
                                'fotoğrafı korunacak.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.neutralDark,
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: 8 * scale),
                    Text(
                      'Fotoğraflar bu düzenleme işleminde değiştirilemez.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.neutralSecondary,
                        fontSize: 12 * scale,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (allowChanges) ...[
            Positioned(
              left: 8 * scale,
              top: 22 * scale,
              width: 312 * scale,
              height: 217 * scale,
              child: GridView.builder(
                key: const Key('household-photo-grid'),
                padding: EdgeInsets.zero,
                physics: photos.length > 6
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: photos.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6 * scale,
                  mainAxisSpacing: 5 * scale,
                  mainAxisExtent: 106 * scale,
                ),
                itemBuilder: (context, index) {
                  return _PhotoTile(
                    key: Key('household-photo-$index'),
                    photo: photos[index],
                    photoNumber: index + 1,
                    scale: scale,
                    onRemove: () => onRemovePhoto(index),
                  );
                },
              ),
            ),
            Positioned(
              left: 246 * scale,
              top: 272 * scale,
              width: 54 * scale,
              height: 78 * scale,
              child: Semantics(
                button: true,
                label: 'Kamera ile fotoğraf ekle',
                child: GestureDetector(
                  key: const Key('household-camera-button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: isCapturing ? null : onCapture,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        width: 54 * scale,
                        height: 54 * scale,
                        child: SvgPicture.asset(
                          AppAssets.householdCameraCircle,
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned(
                        left: 15 * scale,
                        top: 15 * scale,
                        width: 24 * scale,
                        height: 24 * scale,
                        child: SvgPicture.asset(
                          AppAssets.householdCamera,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        top: 54 * scale,
                        width: 54 * scale,
                        height: 24 * scale,
                        child: Text(
                          'Kamera',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF525BCE),
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w500,
                            height: 24 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16 * scale,
              top: 363 * scale,
              width: 270 * scale,
              height: 24 * scale,
              child: Semantics(
                checked: saveToBeneficiaryDirectory,
                label: 'Hak sahibinin klasörüne kaydet',
                child: GestureDetector(
                  key: const Key('household-save-directory-checkbox'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleSave,
                  child: Row(
                    children: [
                      Container(
                        width: 24 * scale,
                        height: 24 * scale,
                        decoration: BoxDecoration(
                          color: saveToBeneficiaryDirectory
                              ? AppColors.primary
                              : AppColors.white,
                          border: Border.all(color: const Color(0xFFBFBFBF)),
                          borderRadius: BorderRadius.circular(4 * scale),
                        ),
                        child: saveToBeneficiaryDirectory
                            ? Icon(
                                Icons.check,
                                size: 16 * scale,
                                color: AppColors.white,
                              )
                            : null,
                      ),
                      SizedBox(width: 12 * scale),
                      Expanded(
                        child: Text(
                          'Hak sahibinin klasörüne kaydet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.neutralStatusLabel,
                            fontSize: 14 * scale,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({required this.scale, required this.child});

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15 * scale),
        boxShadow: const [
          BoxShadow(
            color: Color(0x123629B7),
            offset: Offset(0, 4),
            blurRadius: 30,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.photoNumber,
    required this.scale,
    required this.onRemove,
    super.key,
  });

  final HouseholdPhotoViewData photo;
  final int photoNumber;
  final double scale;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final image = switch (photo.kind) {
      HouseholdPhotoKind.asset => Image.asset(
        photo.path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
      HouseholdPhotoKind.file => Image.file(
        File(photo.path),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) => const ColoredBox(
          color: AppColors.primarySurface,
          child: Icon(Icons.broken_image_outlined, color: AppColors.primary),
        ),
      ),
    };

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(15 * scale),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  offset: Offset(0, 5),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                4 * scale,
                7 * scale,
                5 * scale,
                8 * scale,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(7 * scale),
                child: image,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          width: 28 * scale,
          height: 28 * scale,
          child: Semantics(
            button: true,
            label: '$photoNumber. fotoğrafı sil',
            child: Tooltip(
              message: 'Fotoğrafı sil',
              child: GestureDetector(
                key: Key('household-photo-remove-${photoNumber - 1}'),
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 18 * scale,
                    height: 18 * scale,
                    decoration: const BoxDecoration(
                      color: AppColors.statusRejected,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 12 * scale,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.buttonKey,
    required this.label,
    required this.backgroundColor,
    required this.scale,
    required this.onTap,
    this.isBack = false,
  });

  final Key buttonKey;
  final String label;
  final Color backgroundColor;
  final double scale;
  final VoidCallback onTap;
  final bool isBack;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(15 * scale),
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(15 * scale),
        child: Stack(
          children: [
            Center(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16 * scale,
                  fontWeight: FontWeight.w500,
                  height: 24 / 16,
                ),
              ),
            ),
            Positioned(
              left: isBack ? 8 * scale : null,
              right: isBack ? null : 9 * scale,
              top: 12 * scale,
              width: 6 * scale,
              height: 11 * scale,
              child: Transform.rotate(
                angle: isBack ? math.pi : 0,
                child: SvgPicture.asset(
                  AppAssets.activityContinueArrow,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
