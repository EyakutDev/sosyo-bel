import 'dart:math';

import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/auth/token_store.dart';
import 'package:sosyo_bel/core/branding/municipality_branding.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/action_selection/presentation/action_selection_page.dart';
import 'package:sosyo_bel/features/activity/data/device_household_photo_picker.dart';
import 'package:sosyo_bel/features/activity/presentation/application_completion_page.dart';
import 'package:sosyo_bel/features/activity/presentation/citizen_profile_page.dart';
import 'package:sosyo_bel/features/activity/presentation/family_information_page.dart';
import 'package:sosyo_bel/features/activity/presentation/household_status_page.dart';
import 'package:sosyo_bel/features/activity/presentation/models/application_completion_payload.dart';
import 'package:sosyo_bel/features/activity/presentation/models/citizen_profile_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/models/household_status_view_data.dart';
import 'package:sosyo_bel/features/application/domain/application_lifecycle_entry.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/domain/application_repository.dart';
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';
import 'package:sosyo_bel/features/application/presentation/new_application_page.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';
import 'package:sosyo_bel/features/application/presentation/widgets/application_exit_dialog.dart';
import 'package:sosyo_bel/features/auth/presentation/login_page.dart';
import 'package:sosyo_bel/features/auth/domain/auth_repository.dart';
import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';
import 'package:sosyo_bel/features/home/presentation/home_page.dart';
import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';

/// Sosyo-Bel'in şu anda uygulanmış ekranları arasındaki geçişleri tek yerde
/// birleştirir.
///
/// Sayfalar hedeflerini doğrudan tanımadığı için backend, kimlik doğrulama veya
/// yeni akışlar geldiğinde ekran widget'larını değiştirmeden navigasyon
/// güncellenebilir.
class AppFlow extends StatefulWidget {
  const AppFlow({
    required this.authRepository,
    required this.applicationRepository,
    required this.applicationReferenceRepository,
    required this.kpsProfileRepository,
    required this.workItemsRepository,
    this.initialMunicipalityBranding = MunicipalityBranding.demo,
    super.key,
  });

  final AuthRepository authRepository;
  final ApplicationRepository applicationRepository;
  final ApplicationReferenceRepository applicationReferenceRepository;
  final KpsProfileRepository kpsProfileRepository;
  final WorkItemsRepository workItemsRepository;

  /// Başarılı giriş cevabı gelene kadar tasarım önizlemesinde kullanılan kimlik.
  final MunicipalityBranding initialMunicipalityBranding;

  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  static const _actionSelectionRouteName = '/action-selection';
  static const _newApplicationRouteName = '/new-application';
  static final _householdPhotoPicker = DeviceHouseholdPhotoPicker();

  late ApplicationDraft _applicationDraft;
  late String _createDraftIdempotencyKey;
  late String _photoUploadIdempotencyKey;
  late String _submitIdempotencyKey;
  ApplicationLifecycleEntry? _remoteApplication;
  ApplicationReferenceCatalog? _applicationReferences;
  late MunicipalityBranding _municipalityBranding;
  bool _isRestoringSession = true;
  String? _restoreErrorMessage;

  @override
  void initState() {
    super.initState();
    _municipalityBranding = widget.initialMunicipalityBranding;
    _resetApplicationDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (loginContext) {
        return LoginPage(
          isRestoringSession: _isRestoringSession,
          externalErrorMessage: _restoreErrorMessage,
          onLogin: (email, password) =>
              _login(loginContext, email: email, password: password),
        );
      },
    );
  }

  Future<void> _restoreSession() async {
    try {
      final session = await widget.authRepository.restoreSession();
      if (!mounted) return;

      setState(() => _isRestoringSession = false);
      if (session != null) {
        _municipalityBranding = _brandingFromSession(session);
        _openActionSelection(context);
      }
    } on ApiException catch (error) {
      _finishRestoreWithError(error.message);
    } on TokenStorageException catch (error) {
      _finishRestoreWithError(error.message);
    } catch (_) {
      _finishRestoreWithError(
        'Kayıtlı oturum kontrol edilemedi. E-posta ve parolanızla giriş yapın.',
      );
    }
  }

  void _finishRestoreWithError(String message) {
    if (!mounted) return;
    setState(() {
      _isRestoringSession = false;
      _restoreErrorMessage = message;
    });
  }

  Future<void> _login(
    BuildContext context, {
    required String email,
    required String password,
  }) async {
    if (_restoreErrorMessage != null) {
      setState(() => _restoreErrorMessage = null);
    }
    final session = await widget.authRepository.login(
      email: email,
      password: password,
    );
    if (!mounted || !context.mounted) return;

    _municipalityBranding = _brandingFromSession(session);
    _openActionSelection(context);
  }

  MunicipalityBranding _brandingFromSession(AuthenticationSession session) {
    final user = session.user;
    return MunicipalityBranding(
      id:
          user.municipalityCode ??
          user.municipalityMembershipId?.toString() ??
          user.userId,
      displayName: user.municipalityName ?? 'Sosyo-Bel',
    );
  }

  void _openActionSelection(BuildContext context) {
    // Giriş rotası geçmişte tutulur; ekrandaki ve sistemdeki geri eylemi
    // kullanıcıyı güvenli biçimde giriş ekranına döndürür.
    Navigator.of(context).push(
      _pageRoute(
        _buildActionSelection,
        settings: const RouteSettings(name: _actionSelectionRouteName),
      ),
    );
  }

  Future<void> _openNewApplication(BuildContext context) async {
    final references = await _loadApplicationReferences(context);
    if (references == null || !context.mounted) return;
    _resetApplicationDraft();

    Navigator.of(context).push(
      _pageRoute(
        (formContext) => _guardApplicationExit(
          routeContext: formContext,
          child: NewApplicationPage(
            referenceCatalog: references,
            initialData: _applicationDraft.applicationForm,
            onContinue: (formData) =>
                _continueFromNewApplication(formContext, formData),
          ),
        ),
        settings: const RouteSettings(name: _newApplicationRouteName),
      ),
    );
  }

  Future<void> _continueFromNewApplication(
    BuildContext context,
    NewApplicationFormData formData,
  ) async {
    final kpsProfile = await widget.kpsProfileRepository.getProfile(
      identityNumber: formData.identityNumber,
      birthDate: formData.birthDate,
    );
    if (!mounted || !context.mounted) return;

    // KPS'den gelen kimlik alanları ile personelin formda girdiği manuel alanlar
    // aynı taslakta birleştirilir. Tasarım modeli HTTP cevabına bağımlı kalmaz.
    _applicationDraft = _applicationDraft.copyWith(
      applicationForm: formData,
      kpsProfile: kpsProfile,
      citizenProfile: _applicationDraft.citizenProfile.copyWith(
        fullName: kpsProfile.fullName,
        address: kpsProfile.fullAddress,
        identityNumber: kpsProfile.identityNumber,
        birthDate: kpsProfile.birthDate,
        phoneNumber: formData.phoneNumber,
        maritalStatus: kpsProfile.maritalStatus ?? 'Bilgi bulunmuyor',
        disabilityStatus: formData.disabilityStatus,
      ),
    );
    _openCitizenProfile(context);
  }

  void _openTasks(BuildContext context) {
    // Proje müdürü, Görevler seçeneğinin mevcut bekleyen/tamamlanmış liste
    // ekranını açacağını doğruladı.
    Navigator.of(context).push(
      _pageRoute(
        (tasksContext) => HomePage(
          onBack: () => Navigator.of(tasksContext).pop(),
          municipalityBranding: _municipalityBranding,
          workItemsRepository: widget.workItemsRepository,
          onOpenEditableDraft: (item) => _openSavedDraft(tasksContext, item),
        ),
      ),
    );
  }

  Future<void> _openSavedDraft(BuildContext context, WorkItem item) async {
    if (!item.isEditable || item.statusCode != 'TASLAK') return;

    final references = await _loadApplicationReferences(context);
    if (references == null || !context.mounted) return;

    final loaded = await widget.applicationRepository.getDraft(
      applicationPublicId: item.applicationPublicId,
      referenceCatalog: references,
    );
    // Liste ile ayrıntı arasında durum değiştiyse sunucunun güncel kilidi esas alınır.
    if (!loaded.entry.isEditable || loaded.entry.statusCode != 'TASLAK') {
      throw const ApiException(
        kind: ApiErrorKind.conflict,
        message: 'Bu başvuru artık düzenlenebilir bir taslak değil.',
      );
    }

    _applicationDraft = loaded.draft;
    _remoteApplication = loaded.entry;
    _createDraftIdempotencyKey = _newIdempotencyKey('create-draft');
    _photoUploadIdempotencyKey = _newIdempotencyKey('upload-photos');
    _submitIdempotencyKey = _newIdempotencyKey('submit-board');
    if (!mounted || !context.mounted) return;

    Navigator.of(context).push(
      _pageRoute(
        (formContext) => _guardApplicationExit(
          routeContext: formContext,
          child: NewApplicationPage(
            referenceCatalog: references,
            initialData: _applicationDraft.applicationForm,
            onContinue: (formData) =>
                _continueFromNewApplication(formContext, formData),
          ),
        ),
        settings: const RouteSettings(name: _newApplicationRouteName),
      ),
    );
  }

  void _openCitizenProfile(BuildContext context) {
    Navigator.of(context).push(
      _pageRoute(
        (profileContext) => CitizenProfilePage(
          onBack: () => _confirmAndReturnToApplicationForm(profileContext),
          onContinue: () => _openFamilyInformation(profileContext),
          data: _applicationDraft.citizenProfile,
        ),
      ),
    );
  }

  void _openFamilyInformation(BuildContext context) {
    Navigator.of(context).push(
      _pageRoute(
        (familyContext) => FamilyInformationPage(
          // Üst ok başvuru formuna uyarıyla döner; alttaki düğme yalnızca
          // Aktivite akışının bir önceki adımını açar.
          onHeaderBack: () => _confirmAndReturnToApplicationForm(familyContext),
          onBack: () => Navigator.of(familyContext).pop(),
          onContinue: () => _openHouseholdStatus(familyContext),
          referenceCatalog: _requiredApplicationReferences,
          data: _applicationDraft.familyInformation,
          onFamilyChanged: (data) {
            _applicationDraft = _applicationDraft.copyWith(
              familyInformation: data,
            );
          },
          // Kalıcı aile API'si geldiğinde ekleme ve kişi güncelleme çağrıları
          // bu iki entegrasyon sınırına bağlanacaktır.
          onUpdateInformation: () {},
          onEditMember: (_) {},
        ),
      ),
    );
  }

  void _openHouseholdStatus(BuildContext context) {
    Navigator.of(context).push(
      _pageRoute(
        (householdContext) => HouseholdStatusPage(
          onHeaderBack: () =>
              _confirmAndReturnToApplicationForm(householdContext),
          onBack: () => Navigator.of(householdContext).pop(),
          questions: _householdQuestions(_requiredApplicationReferences),
          initialDraft: _applicationDraft.householdStatus,
          onDraftChanged: (draft) {
            _applicationDraft = _applicationDraft.copyWith(
              householdStatus: draft,
            );
          },
          // Hane verisi Tamamla ekranına tek taslak halinde aktarılır; kalıcı
          // kayıt kararı Tamamla ekranındaki ayrı eylemlerde verilir.
          onContinue: (draft) {
            _applicationDraft = _applicationDraft.copyWith(
              householdStatus: draft,
            );
            _openApplicationCompletion(householdContext);
          },
          onCapturePhoto: _householdPhotoPicker.capturePhoto,
          onRecoverLostPhotos: _householdPhotoPicker.recoverLostPhotos,
        ),
      ),
    );
  }

  void _openApplicationCompletion(BuildContext context) {
    Navigator.of(context).push(
      _pageRoute(
        (completionContext) => ApplicationCompletionPage(
          applicationDraft: _applicationDraft,
          onNoteChanged: (note) {
            _applicationDraft = _applicationDraft.copyWith(
              completionNote: note,
            );
          },
          onBack: () => _confirmAndReturnToApplicationForm(completionContext),
          onSaveDraft: (payload) =>
              _saveDraftAndOpenPendingList(completionContext, payload),
          onSubmitToBoard: (payload) =>
              _submitAndOpenPendingList(completionContext, payload),
        ),
      ),
    );
  }

  Future<void> _saveDraftAndOpenPendingList(
    BuildContext context,
    ApplicationCompletionPayload payload,
  ) async {
    _applicationDraft = payload.applicationDraft;
    await _persistApplicationData();
    if (!mounted || !context.mounted) return;

    _resetApplicationDraft();
    _replaceApplicationFlowWithPendingList(context);
  }

  Future<void> _submitAndOpenPendingList(
    BuildContext context,
    ApplicationCompletionPayload payload,
  ) async {
    _applicationDraft = payload.applicationDraft;
    final draft = await _persistApplicationData();
    final submitted = await widget.applicationRepository.submitToBoard(
      applicationPublicId: draft.applicationPublicId,
      expectedRowVersion: draft.rowVersion,
      idempotencyKey: _submitIdempotencyKey,
    );
    _remoteApplication = submitted;
    if (!mounted || !context.mounted) return;

    _resetApplicationDraft();
    _replaceApplicationFlowWithPendingList(
      context,
      successMessage: 'Başvuru başarıyla kurula gönderildi.',
    );
  }

  Future<ApplicationLifecycleEntry> _ensureRemoteDraft() async {
    final existing = _remoteApplication;
    if (existing != null) return existing;

    final created = await widget.applicationRepository.createDraft(
      draft: _applicationDraft,
      idempotencyKey: _createDraftIdempotencyKey,
    );
    _remoteApplication = created;
    return created;
  }

  Future<ApplicationLifecycleEntry> _persistApplicationData() async {
    final isExistingDraft = _remoteApplication != null;
    var current = await _ensureRemoteDraft();

    if (isExistingDraft) {
      // Yeniden açılan taslakta kişi/talep ekranındaki değişiklikler de aile ve
      // hane verisinden önce aynı iyimser eşzamanlılık zincirine yazılır.
      current = await widget.applicationRepository.updateDraft(
        draft: _applicationDraft,
        applicationPublicId: current.applicationPublicId,
        expectedRowVersion: current.rowVersion,
      );
      _remoteApplication = current;
    }

    // Aile ve hane verileri ayri tablolarda basvurunun anlik kopyasi olarak
    // tutulur. Donen RowVersion bir sonraki yazma isleminin kilididir.
    current = await widget.applicationRepository.saveFieldData(
      draft: _applicationDraft,
      applicationPublicId: current.applicationPublicId,
      expectedRowVersion: current.rowVersion,
    );
    _remoteApplication = current;

    final hasUploadablePhotos =
        _applicationDraft.householdStatus?.photos.any(
          (photo) => photo.kind == HouseholdPhotoKind.file,
        ) ??
        false;
    final replacesRemotePhotos =
        _applicationDraft.householdStatus?.replaceRemotePhotosOnSave ?? false;
    if (hasUploadablePhotos || replacesRemotePhotos) {
      current = await widget.applicationRepository.uploadPhotos(
        draft: _applicationDraft,
        applicationPublicId: current.applicationPublicId,
        expectedRowVersion: current.rowVersion,
        idempotencyKey: _photoUploadIdempotencyKey,
      );
      _remoteApplication = current;
      // Basarili yuklemeden sonraki fotograf degisikligi yeni bir istek sayilir.
      // Cevap kaybolursa anahtar degismedigi icin sunucu ayni istegi replay eder.
      _photoUploadIdempotencyKey = _newIdempotencyKey('upload-photos');
    }

    return current;
  }

  void _replaceApplicationFlowWithPendingList(
    BuildContext context, {
    String? successMessage,
  }) {
    Navigator.of(context).pushAndRemoveUntil(
      _pageRoute(
        (homeContext) => HomePage(
          onBack: () => Navigator.of(homeContext).pop(),
          initialSuccessMessage: successMessage,
          municipalityBranding: _municipalityBranding,
          workItemsRepository: widget.workItemsRepository,
          onOpenEditableDraft: (item) => _openSavedDraft(homeContext, item),
        ),
      ),
      _keepApplicationEntryRoute,
    );
  }

  Widget _buildActionSelection(BuildContext selectionContext) {
    return ActionSelectionPage(
      onNewApplication: () => _openNewApplication(selectionContext),
      onTasks: () => _openTasks(selectionContext),
      onLogout: () => _logout(selectionContext),
    );
  }

  Future<ApplicationReferenceCatalog?> _loadApplicationReferences(
    BuildContext context,
  ) async {
    try {
      final catalog = await widget.applicationReferenceRepository.getCatalog();
      if (catalog.helpTypes.isEmpty ||
          catalog.disabilityStatuses.isEmpty ||
          catalog.relationships.isEmpty ||
          !catalog.relationships.any((option) => option.code == 'DIGER') ||
          catalog.employmentStatuses.isEmpty ||
          catalog.educationStatuses.isEmpty ||
          catalog.vitalStatuses.isEmpty ||
          !catalog.disabilityStatuses.any((option) => option.code == 'YOK') ||
          catalog.householdQuestions.isEmpty ||
          catalog.householdQuestions.any(
            (question) =>
                question.answerTypeCode != 'TEK_SECIM' ||
                question.options.isEmpty,
          )) {
        throw const ApiException(
          kind: ApiErrorKind.invalidResponse,
          message:
              'Başvuru formu seçenekleri eksik veya desteklenmeyen biçimde yapılandırılmış.',
        );
      }
      _applicationReferences = catalog;
      return catalog;
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return null;
    }
  }

  ApplicationReferenceCatalog get _requiredApplicationReferences =>
      _applicationReferences ??
      (throw StateError('Başvuru referansları yüklenmedi.'));

  List<HouseholdQuestionViewData> _householdQuestions(
    ApplicationReferenceCatalog catalog,
  ) {
    return catalog.householdQuestions
        .map(
          (question) => HouseholdQuestionViewData(
            id: question.code,
            label: question.label,
            isRequired: question.isRequired,
            options: question.options
                .map(
                  (option) => HouseholdQuestionOptionViewData(
                    code: option.code,
                    label: option.label,
                  ),
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _logout(BuildContext context) async {
    String? logoutNotice;
    try {
      await widget.authRepository.logout();
    } on ApiException {
      // Repository yerel kaydı temizledi; yalnız sunucu iptali tamamlanamadı.
      logoutNotice =
          'Sunucuya ulaşılamadı ancak bu cihazdaki oturum kapatıldı.';
    }
    if (!mounted || !context.mounted) return;

    widget.applicationReferenceRepository.clearCache();
    _applicationReferences = null;
    _resetApplicationDraft();
    setState(() {
      _municipalityBranding = widget.initialMunicipalityBranding;
      _restoreErrorMessage = logoutNotice;
    });
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _guardApplicationExit({
    required BuildContext routeContext,
    required Widget child,
  }) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _confirmAndCloseApplication(routeContext);
        }
      },
      child: child,
    );
  }

  Future<void> _confirmAndReturnToApplicationForm(BuildContext context) async {
    final shouldReturn = await showActivityReturnDialog(context);
    if (!context.mounted || !shouldReturn) return;

    // İlk form rotası geçmişte tutulduğu için yeni, boş bir form oluşturulmaz.
    // Hane taslağı da akış durumunda saklanır ve Aktiviteye yeniden girildiğinde
    // aynı cevaplar ile fotoğraflar tekrar yüklenir.
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == _newApplicationRouteName);
  }

  Future<void> _confirmAndCloseApplication(BuildContext context) async {
    final shouldClose = await showApplicationExitDialog(context);
    if (!context.mounted || !shouldClose) return;

    _resetApplicationDraft();

    // PopScope korumalı rotaları tek tek geri açmak yerine bütün başvuru akışı
    // kaldırılır; giriş rotası korunur ve temiz bir İşlem Seçimi rotası eklenir.
    Navigator.of(context).pushAndRemoveUntil(
      _pageRoute(
        _buildActionSelection,
        settings: const RouteSettings(name: _actionSelectionRouteName),
      ),
      (route) => route.isFirst,
    );
  }

  void _resetApplicationDraft() {
    _applicationDraft = _createInitialApplicationDraft();
    _remoteApplication = null;
    _createDraftIdempotencyKey = _newIdempotencyKey('create-draft');
    _photoUploadIdempotencyKey = _newIdempotencyKey('upload-photos');
    _submitIdempotencyKey = _newIdempotencyKey('submit-board');
  }

  String _newIdempotencyKey(String operation) {
    final random = Random.secure();
    final randomPart = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    return [
      operation,
      DateTime.now().microsecondsSinceEpoch.toString(),
      randomPart,
    ].join('-');
  }

  ApplicationDraft _createInitialApplicationDraft() {
    // Yeni başvuru gerçek KPS sorgusu yapılmadan örnek vatandaş bilgisi taşımaz.
    // Bu boş değerler ekranda yalnız başarılı sorgudan önce bellekte bulunur.
    return const ApplicationDraft(
      citizenProfile: CitizenProfileViewData(
        applicationNumber: '—',
        fullName: 'Bilgi bulunmuyor',
        address: 'Bilgi bulunmuyor',
        phoneNumber: 'Bilgi bulunmuyor',
        identityNumber: 'Bilgi bulunmuyor',
        birthDate: 'Bilgi bulunmuyor',
        maritalStatus: 'Bilgi bulunmuyor',
        childrenCount: 'Bilgi bulunmuyor',
        disabilityStatus: 'Bilgi bulunmuyor',
        employmentStatus: 'Bilgi bulunmuyor',
        educationStatus: 'Bilgi bulunmuyor',
      ),
      // MERNIS artik hane uyelerini vermiyor; yeni basvuru sahte aile
      // satirlariyla degil, personelin manuel ekleyecegi bos listeyle baslar.
      familyInformation: FamilyInformationViewData(members: []),
    );
  }

  bool _keepApplicationEntryRoute(Route<dynamic> route) {
    return route.settings.name == _actionSelectionRouteName || route.isFirst;
  }

  MaterialPageRoute<void> _pageRoute(
    WidgetBuilder builder, {
    RouteSettings? settings,
  }) {
    return MaterialPageRoute<void>(builder: builder, settings: settings);
  }
}
