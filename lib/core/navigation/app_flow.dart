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
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/domain/application_repository.dart';
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';
import 'package:sosyo_bel/features/application/domain/local_application_draft_repository.dart';
import 'package:sosyo_bel/features/application/domain/submitted_application_details.dart';
import 'package:sosyo_bel/features/application/presentation/mappers/submitted_application_draft_mapper.dart';
import 'package:sosyo_bel/features/application/presentation/new_application_page.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';
import 'package:sosyo_bel/features/application/presentation/submitted_application_detail_page.dart';
import 'package:sosyo_bel/features/application/presentation/widgets/application_exit_dialog.dart';
import 'package:sosyo_bel/features/auth/presentation/login_page.dart';
import 'package:sosyo_bel/features/auth/domain/auth_repository.dart';
import 'package:sosyo_bel/features/auth/domain/authentication_session.dart';
import 'package:sosyo_bel/features/home/presentation/home_page.dart';
import 'package:sosyo_bel/features/home/data/local_draft_aware_work_items_repository.dart';
import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';
import 'package:sosyo_bel/features/splash/presentation/splash_page.dart';

/// Sosyo-Bel'in şu anda uygulanmış ekranları arasındaki geçişleri tek yerde
/// birleştirir.
///
/// Sayfalar hedeflerini doğrudan tanımadığı için backend, kimlik doğrulama veya
/// yeni akışlar geldiğinde ekran widget'larını değiştirmeden navigasyon
/// güncellenebilir.
class AppFlow extends StatefulWidget {
  static const defaultMinimumSplashDuration = Duration(milliseconds: 2000);

  const AppFlow({
    required this.authRepository,
    required this.applicationRepository,
    required this.applicationReferenceRepository,
    required this.kpsProfileRepository,
    required this.localApplicationDraftRepository,
    required this.workItemsRepository,
    this.initialMunicipalityBranding = MunicipalityBranding.demo,
    this.minimumSplashDuration = defaultMinimumSplashDuration,
    super.key,
  });

  final AuthRepository authRepository;
  final ApplicationRepository applicationRepository;
  final ApplicationReferenceRepository applicationReferenceRepository;
  final KpsProfileRepository kpsProfileRepository;
  final LocalApplicationDraftRepository localApplicationDraftRepository;
  final WorkItemsRepository workItemsRepository;
  final Duration minimumSplashDuration;

  /// Başarılı giriş cevabı gelene kadar tasarım önizlemesinde kullanılan kimlik.
  final MunicipalityBranding initialMunicipalityBranding;

  @override
  State<AppFlow> createState() => _AppFlowState();
}

class _AppFlowState extends State<AppFlow> {
  static const _actionSelectionRouteName = '/action-selection';
  static const _newApplicationRouteName = '/new-application';
  static const _editApplicationRouteName = '/edit-application';
  static final _householdPhotoPicker = DeviceHouseholdPhotoPicker();

  late ApplicationDraft _applicationDraft;
  late String _submitIdempotencyKey;
  String? _localDraftId;
  int? _editingSubmittedApplicationId;
  int _editingSubmittedPhotoCount = 0;
  ApplicationReferenceCatalog? _applicationReferences;
  String? _authenticatedUserId;
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
    if (_isRestoringSession) return const SplashPage();

    return Builder(
      builder: (loginContext) {
        return LoginPage(
          isRestoringSession: false,
          externalErrorMessage: _restoreErrorMessage,
          onLogin: (username, password) =>
              _login(loginContext, username: username, password: password),
        );
      },
    );
  }

  Future<void> _restoreSession() async {
    final stopwatch = Stopwatch()..start();
    try {
      final session = await widget.authRepository.restoreSession();
      await _waitForMinimumSplashDuration(stopwatch.elapsed);
      if (!mounted) return;

      setState(() => _isRestoringSession = false);
      if (session != null) {
        _authenticatedUserId = session.user.userId;
        _municipalityBranding = _brandingFromSession(session);
        _openActionSelection(context);
      }
    } on ApiException catch (error) {
      await _waitForMinimumSplashDuration(stopwatch.elapsed);
      _finishRestoreWithError(error.message);
    } on TokenStorageException catch (error) {
      await _waitForMinimumSplashDuration(stopwatch.elapsed);
      _finishRestoreWithError(error.message);
    } catch (_) {
      await _waitForMinimumSplashDuration(stopwatch.elapsed);
      _finishRestoreWithError(
        'Kayıtlı oturum kontrol edilemedi. Kullanıcı adı ve parolanızla giriş yapın.',
      );
    }
  }

  Future<void> _waitForMinimumSplashDuration(Duration elapsed) async {
    final remaining = widget.minimumSplashDuration - elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);
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
    required String username,
    required String password,
  }) async {
    if (_restoreErrorMessage != null) {
      setState(() => _restoreErrorMessage = null);
    }
    final session = await widget.authRepository.login(
      username: username,
      password: password,
    );
    if (!mounted || !context.mounted) return;

    _authenticatedUserId = session.user.userId;
    _municipalityBranding = _brandingFromSession(session);
    _openActionSelection(context);
  }

  // Uygulama tek belediyeye bağlıdır; Identity oturumu marka/tenant bilgisi
  // taşımaz. Yapılandırılmış belediye kimliği girişten sonra korunur.
  MunicipalityBranding _brandingFromSession(AuthenticationSession _) =>
      widget.initialMunicipalityBranding;

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

  Future<void> _continueFromSubmittedApplicationEdit(
    BuildContext context,
    NewApplicationFormData formData,
  ) async {
    if (_editingSubmittedApplicationId == null) {
      throw StateError('Düzenlenecek başvuru bulunamadı.');
    }
    _applicationDraft = _applicationDraft.copyWith(
      applicationForm: formData,
      citizenProfile: _applicationDraft.citizenProfile.copyWith(
        phoneNumber: formData.phoneNumber,
        disabilityStatus: formData.disabilityStatus,
      ),
    );
    if (!mounted || !context.mounted) return;
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
          workItemsRepository: _currentUserWorkItemsRepository(),
          onOpenEditableDraft: (item) => _openSavedDraft(tasksContext, item),
          onOpenSubmittedApplication: (item) =>
              _openSubmittedApplicationDetails(tasksContext, item),
          onDeleteLocalDraft: _deleteSavedDraft,
        ),
      ),
    );
  }

  Future<void> _openSavedDraft(BuildContext context, WorkItem item) async {
    // Taslaklar şirket veritabanına yazılmaz; yalnız oluşturuldukları cihazdan
    // açılabilir. Sunucudaki başvurular kurula gönderilmiş ve kilitli kayıtlardır.
    if (!item.isLocalDraft || !item.isEditable || item.statusCode != 'TASLAK') {
      return;
    }

    final references = await _loadApplicationReferences(context);
    if (references == null || !context.mounted) return;

    final localDraftId = item.localDraftId;
    if (localDraftId == null) return;
    final record = await widget.localApplicationDraftRepository.read(
      ownerUserId: _requiredAuthenticatedUserId,
      localDraftId: localDraftId,
    );
    if (record == null) {
      throw const ApiException(
        kind: ApiErrorKind.notFound,
        message: 'Bu cihazdaki taslak artık bulunamıyor.',
      );
    }

    _applicationDraft = record.draft;
    _localDraftId = record.localDraftId;
    _resetApplicationOperationKeys();
    if (!mounted || !context.mounted) return;
    _pushDraftForm(context, references);
  }

  Future<void> _openSubmittedApplicationDetails(
    BuildContext context,
    WorkItem item,
  ) async {
    final applicationId = item.applicationId;
    if (!item.isSubmittedApplication || applicationId == null) return;

    final references = await _loadApplicationReferences(context);
    if (references == null || !context.mounted) return;

    await Navigator.of(context).push(
      _pageRoute(
        (detailContext) => SubmittedApplicationDetailPage(
          applicationNumber: item.applicationNumber,
          referenceCatalog: references,
          loadDetails: () => widget.applicationRepository.getSubmittedDetails(
            applicationId: applicationId,
          ),
          onEdit: (details) => _openSubmittedApplicationEditor(
            detailContext,
            details,
            references,
          ),
          onDelete: (details) => widget.applicationRepository.deleteSubmitted(
            applicationId: details.applicationId,
          ),
          onBack: () => Navigator.of(detailContext).pop(),
        ),
      ),
    );
  }

  Future<bool> _openSubmittedApplicationEditor(
    BuildContext context,
    SubmittedApplicationDetails details,
    ApplicationReferenceCatalog references,
  ) async {
    if (!details.isOwnedByCurrentUser || !details.isEditable) return false;

    try {
      _applicationDraft = SubmittedApplicationDraftMapper.toDraft(
        details,
        references,
      );
    } on FormatException catch (error) {
      throw ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: error.message,
      );
    }
    _localDraftId = null;
    _editingSubmittedApplicationId = details.applicationId;
    _editingSubmittedPhotoCount = details.photos.length;

    try {
      final wasUpdated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          settings: const RouteSettings(name: _editApplicationRouteName),
          builder: (formContext) => NewApplicationPage(
            referenceCatalog: references,
            initialData: _applicationDraft.applicationForm,
            isEditingSubmittedApplication: true,
            onContinue: (formData) =>
                _continueFromSubmittedApplicationEdit(formContext, formData),
          ),
        ),
      );
      return wasUpdated ?? false;
    } finally {
      _resetApplicationDraft();
    }
  }

  Future<void> _deleteSavedDraft(WorkItem item) async {
    final localDraftId = item.localDraftId;
    if (!item.isLocalDraft || localDraftId == null) {
      throw StateError('Silinecek yerel taslak bulunamadı.');
    }

    await widget.localApplicationDraftRepository.delete(
      ownerUserId: _requiredAuthenticatedUserId,
      localDraftId: localDraftId,
    );
    if (_localDraftId == localDraftId) _resetApplicationDraft();
  }

  void _pushDraftForm(
    BuildContext context,
    ApplicationReferenceCatalog references,
  ) {
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
          allowPhotoChanges: true,
          existingPhotoCount: _editingSubmittedPhotoCount,
          onLoadRemotePhoto: (photoId) {
            final applicationId = _editingSubmittedApplicationId;
            if (applicationId == null) {
              throw StateError('Fotoğrafın bağlı olduğu başvuru bulunamadı.');
            }
            return widget.applicationRepository.getSubmittedPhoto(
              applicationId: applicationId,
              photoId: photoId,
            );
          },
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
          // Tamamla, Aktivite akışının son adımıdır; üst ok taslağı
          // kapatmadan yalnızca bir önceki Hane Durumu adımına döner.
          onBack: () => Navigator.of(completionContext).pop(),
          onSaveDraft: (payload) =>
              _saveDraftAndOpenPendingList(completionContext, payload),
          onSubmitToBoard: _submitApplication,
          onUpdateApplication: _editingSubmittedApplicationId == null
              ? null
              : _updateSubmittedApplication,
          onSubmissionConfirmed: _editingSubmittedApplicationId == null
              ? () => _openPendingListAfterSubmission(completionContext)
              : () => _finishSubmittedApplicationUpdate(completionContext),
        ),
      ),
    );
  }

  Future<void> _saveDraftAndOpenPendingList(
    BuildContext context,
    ApplicationCompletionPayload payload,
  ) async {
    _applicationDraft = payload.applicationDraft;
    final localDraftId = _localDraftId;
    final record = localDraftId == null
        ? await widget.localApplicationDraftRepository.create(
            ownerUserId: _requiredAuthenticatedUserId,
            draft: _applicationDraft,
          )
        : await widget.localApplicationDraftRepository.update(
            ownerUserId: _requiredAuthenticatedUserId,
            localDraftId: localDraftId,
            draft: _applicationDraft,
          );
    _applicationDraft = record.draft;
    _localDraftId = record.localDraftId;
    if (!mounted || !context.mounted) return;

    _resetApplicationDraft();
    _replaceApplicationFlowWithPendingList(context);
  }

  Future<void> _submitApplication(ApplicationCompletionPayload payload) async {
    _applicationDraft = payload.applicationDraft;
    await widget.applicationRepository.submitCompleted(
      draft: _applicationDraft,
      idempotencyKey: _submitIdempotencyKey,
    );
    // Yerel taslak yalnız sunucu kurula gönderme işlemini kesin olarak kabul
    // ettikten sonra silinir; ağ hatasında personelin taslağı kaybolmaz.
    final localDraftId = _localDraftId;
    if (localDraftId != null) {
      await widget.localApplicationDraftRepository.delete(
        ownerUserId: _requiredAuthenticatedUserId,
        localDraftId: localDraftId,
      );
      _localDraftId = null;
    }
  }

  Future<void> _updateSubmittedApplication(
    ApplicationCompletionPayload payload,
  ) async {
    final applicationId = _editingSubmittedApplicationId;
    if (applicationId == null) {
      throw StateError('Güncellenecek başvuru bulunamadı.');
    }
    _applicationDraft = payload.applicationDraft;
    await widget.applicationRepository.updateSubmitted(
      applicationId: applicationId,
      draft: _applicationDraft,
    );
  }

  void _finishSubmittedApplicationUpdate(BuildContext context) {
    if (!mounted || !context.mounted) return;
    final navigator = Navigator.of(context);
    navigator.popUntil(
      (route) => route.settings.name == _editApplicationRouteName,
    );
    navigator.pop(true);
  }

  void _openPendingListAfterSubmission(BuildContext context) {
    if (!mounted || !context.mounted) return;

    _resetApplicationDraft();
    _replaceApplicationFlowWithPendingList(context);
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
          workItemsRepository: _currentUserWorkItemsRepository(),
          onOpenEditableDraft: (item) => _openSavedDraft(homeContext, item),
          onOpenSubmittedApplication: (item) =>
              _openSubmittedApplicationDetails(homeContext, item),
          onDeleteLocalDraft: _deleteSavedDraft,
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
    _authenticatedUserId = null;
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
    final targetRouteName = _editingSubmittedApplicationId == null
        ? _newApplicationRouteName
        : _editApplicationRouteName;
    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == targetRouteName);
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
    _localDraftId = null;
    _editingSubmittedApplicationId = null;
    _editingSubmittedPhotoCount = 0;
    _resetApplicationOperationKeys();
  }

  void _resetApplicationOperationKeys() {
    _submitIdempotencyKey = _newIdempotencyKey('submit-board');
  }

  WorkItemsRepository _currentUserWorkItemsRepository() {
    return LocalDraftAwareWorkItemsRepository(
      remoteRepository: widget.workItemsRepository,
      localDraftRepository: widget.localApplicationDraftRepository,
      ownerUserId: _requiredAuthenticatedUserId,
    );
  }

  String get _requiredAuthenticatedUserId =>
      _authenticatedUserId ??
      (throw StateError('Yerel taslak işlemi için oturum bulunamadı.'));

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
