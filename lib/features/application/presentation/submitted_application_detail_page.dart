import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/core/widgets/app_notice.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/domain/submitted_application_details.dart';

typedef SubmittedApplicationDetailsLoader =
    Future<SubmittedApplicationDetails> Function();
typedef SubmittedApplicationPhotoLoader =
    Future<Uint8List> Function(int photoId);
typedef SubmittedApplicationEditor =
    Future<bool> Function(SubmittedApplicationDetails details);

/// Kurula gönderilmiş bir başvuruyu değiştirmeden görüntüler.
class SubmittedApplicationDetailPage extends StatefulWidget {
  const SubmittedApplicationDetailPage({
    required this.applicationNumber,
    required this.referenceCatalog,
    required this.loadDetails,
    required this.loadPhoto,
    required this.onBack,
    this.onEdit,
    super.key,
  });

  final String applicationNumber;
  final ApplicationReferenceCatalog referenceCatalog;
  final SubmittedApplicationDetailsLoader loadDetails;
  final SubmittedApplicationPhotoLoader loadPhoto;
  final VoidCallback onBack;
  final SubmittedApplicationEditor? onEdit;

  @override
  State<SubmittedApplicationDetailPage> createState() =>
      _SubmittedApplicationDetailPageState();
}

class _SubmittedApplicationDetailPageState
    extends State<SubmittedApplicationDetailPage> {
  SubmittedApplicationDetails? _details;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isOpeningEditor = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final details = await widget.loadDetails();
      if (!mounted) return;
      setState(() {
        _details = details;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _finishWithError(error.message);
    } catch (_) {
      _finishWithError('Başvuru detayları yüklenemedi. Lütfen tekrar deneyin.');
    }
  }

  void _finishWithError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  Future<void> _openEditor() async {
    final details = _details;
    final editor = widget.onEdit;
    if (details == null ||
        editor == null ||
        !details.isOwnedByCurrentUser ||
        !details.isEditable ||
        _isOpeningEditor) {
      return;
    }
    setState(() => _isOpeningEditor = true);
    try {
      final wasUpdated = await editor(details);
      if (wasUpdated && mounted) await _load();
    } on ApiException catch (error) {
      _showEditError(error.message);
    } catch (_) {
      _showEditError(
        'Başvuru düzenleme ekranı açılamadı. Lütfen tekrar deneyin.',
      );
    } finally {
      if (mounted) setState(() => _isOpeningEditor = false);
    }
  }

  void _showEditError(String message) {
    if (!mounted) return;
    showAppNotice(context, message: message, tone: AppNoticeTone.error);
  }

  @override
  Widget build(BuildContext context) {
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
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _DetailHeader(
                applicationNumber: widget.applicationNumber,
                onBack: widget.onBack,
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('application-detail-loading'),
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }
    final errorMessage = _errorMessage;
    if (errorMessage != null) {
      return _DetailErrorState(message: errorMessage, onRetry: _load);
    }
    return _DetailContent(
      details: _details!,
      catalog: widget.referenceCatalog,
      onRefresh: _load,
      loadPhoto: widget.loadPhoto,
      onEdit:
          widget.onEdit != null &&
              _details!.isOwnedByCurrentUser &&
              _details!.isEditable
          ? _openEditor
          : null,
      isOpeningEditor: _isOpeningEditor,
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.applicationNumber, required this.onBack});

  final String applicationNumber;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 116,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 24, 18),
        child: Row(
          children: [
            IconButton(
              key: const Key('application-detail-back'),
              tooltip: 'Geri',
              onPressed: onBack,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Başvuru Detayı',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    applicationNumber,
                    style: const TextStyle(
                      color: Color(0xCCFFFFFF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DetailSectionType {
  citizen,
  request,
  family,
  household,
  photos,
  cancellation,
}

class _DetailContent extends StatefulWidget {
  const _DetailContent({
    required this.details,
    required this.catalog,
    required this.onRefresh,
    required this.loadPhoto,
    required this.onEdit,
    required this.isOpeningEditor,
  });

  final SubmittedApplicationDetails details;
  final ApplicationReferenceCatalog catalog;
  final Future<void> Function() onRefresh;
  final SubmittedApplicationPhotoLoader loadPhoto;
  final VoidCallback? onEdit;
  final bool isOpeningEditor;

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  final Set<_DetailSectionType> _expandedSections = {
    _DetailSectionType.citizen,
  };

  void _toggleSection(_DetailSectionType section) {
    setState(() {
      if (!_expandedSections.remove(section)) {
        _expandedSections.add(section);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final catalog = widget.catalog;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: widget.onRefresh,
      child: ListView(
        key: const Key('application-detail-content'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 36),
        children: [
          _ApplicationSummary(details: details),
          const SizedBox(height: 18),
          _Section(
            toggleKey: const Key('application-detail-section-citizen'),
            icon: Icons.person_outline_rounded,
            title: 'Vatandaş Bilgileri',
            isExpanded: _expandedSections.contains(_DetailSectionType.citizen),
            onToggle: () => _toggleSection(_DetailSectionType.citizen),
            children: [
              _Row('Ad Soyad', '${details.firstName} ${details.lastName}'),
              _Row('T.C. Kimlik Numarası', details.identityNumber),
              _Row('Doğum Tarihi', _formatDate(details.birthDate)),
              _Row('Telefon', _formatPhone(details.phoneNumber)),
              _Row('Cinsiyet', details.gender),
              _Row('Doğum Yeri', details.birthPlace),
              _Row('Medeni Hal', details.maritalStatus),
              _Row('Adres', details.address),
            ],
          ),
          const SizedBox(height: 14),
          _Section(
            toggleKey: const Key('application-detail-section-request'),
            icon: Icons.volunteer_activism_outlined,
            title: 'Talep Bilgileri',
            isExpanded: _expandedSections.contains(_DetailSectionType.request),
            onToggle: () => _toggleSection(_DetailSectionType.request),
            children: [
              _Row(
                'Yardım Türü',
                _optionLabel(catalog.helpTypes, details.helpTypeCode),
              ),
              _Row(
                'Engel Durumu',
                details.hasDisability
                    ? _optionLabel(
                        catalog.disabilityStatuses,
                        details.disabilityTypeCode,
                      )
                    : _optionLabel(catalog.disabilityStatuses, 'YOK'),
              ),
              if (details.disabilityRate != null)
                _Row('Engel Oranı', '%${details.disabilityRate}'),
              _Row('Talep Açıklaması', details.description),
              _Row('Saha Notu', details.fieldInspectionNote),
            ],
          ),
          const SizedBox(height: 14),
          _FamilySection(
            members: details.familyMembers,
            catalog: catalog,
            isExpanded: _expandedSections.contains(_DetailSectionType.family),
            onToggle: () => _toggleSection(_DetailSectionType.family),
          ),
          const SizedBox(height: 14),
          _HouseholdSection(
            answers: details.householdAnswers,
            catalog: catalog,
            isExpanded: _expandedSections.contains(
              _DetailSectionType.household,
            ),
            onToggle: () => _toggleSection(_DetailSectionType.household),
          ),
          const SizedBox(height: 14),
          _PhotoSection(
            photos: details.photos,
            loadPhoto: widget.loadPhoto,
            isExpanded: _expandedSections.contains(_DetailSectionType.photos),
            onToggle: () => _toggleSection(_DetailSectionType.photos),
          ),
          if (details.cancellationDescription != null ||
              details.cancellationDate != null) ...[
            const SizedBox(height: 14),
            _Section(
              toggleKey: const Key('application-detail-section-cancellation'),
              icon: Icons.cancel_outlined,
              title: 'İptal Bilgileri',
              isExpanded: _expandedSections.contains(
                _DetailSectionType.cancellation,
              ),
              onToggle: () => _toggleSection(_DetailSectionType.cancellation),
              children: [
                _Row('İptal Tarihi', _formatDateTime(details.cancellationDate)),
                _Row('İptal Açıklaması', details.cancellationDescription),
              ],
            ),
          ],
          if (widget.onEdit != null) ...[
            const SizedBox(height: 22),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('application-detail-edit-button'),
                onPressed: widget.isOpeningEditor ? null : widget.onEdit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primaryMuted,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: widget.isOpeningEditor
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.edit_outlined, size: 19),
                label: const Text(
                  'Düzenle',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ApplicationSummary extends StatelessWidget {
  const _ApplicationSummary({required this.details});

  final SubmittedApplicationDetails details;

  @override
  Widget build(BuildContext context) {
    final status = _statusView(details.statusCode);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x143629B7)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: AppColors.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.applicationNumber,
                  style: const TextStyle(
                    color: AppColors.neutralDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDateTime(details.applicationDate),
                  style: const TextStyle(
                    color: AppColors.neutralSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.label,
              style: TextStyle(
                color: status.color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilySection extends StatefulWidget {
  const _FamilySection({
    required this.members,
    required this.catalog,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<SubmittedApplicationFamilyMember> members;
  final ApplicationReferenceCatalog catalog;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  State<_FamilySection> createState() => _FamilySectionState();
}

class _FamilySectionState extends State<_FamilySection> {
  int? _expandedMemberIndex;

  void _toggleMember(int index) {
    setState(() {
      _expandedMemberIndex = _expandedMemberIndex == index ? null : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      toggleKey: const Key('application-detail-section-family'),
      icon: Icons.groups_2_outlined,
      title: 'Aile Bilgileri (${widget.members.length})',
      isExpanded: widget.isExpanded,
      onToggle: widget.onToggle,
      children: widget.members.isEmpty
          ? const [_EmptyValue('Kayıtlı aile ferdi bulunmuyor.')]
          : [
              for (var index = 0; index < widget.members.length; index++)
                _FamilyCard(
                  member: widget.members[index],
                  catalog: widget.catalog,
                  index: index,
                  isExpanded: _expandedMemberIndex == index,
                  onTap: () => _toggleMember(index),
                ),
            ],
    );
  }
}

class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.member,
    required this.catalog,
    required this.index,
    required this.isExpanded,
    required this.onTap,
  });

  final SubmittedApplicationFamilyMember member;
  final ApplicationReferenceCatalog catalog;
  final int index;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final relationship = member.relationshipCode == 'DIGER'
        ? member.otherRelationshipDescription
        : _optionLabel(catalog.relationships, member.relationshipCode);
    return Padding(
      key: ValueKey<String>('application-family-card-$index'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey<String>('application-family-toggle-$index'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            style: const TextStyle(
                              color: AppColors.neutralDark,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$relationship • ${member.age} yaş',
                            style: const TextStyle(
                              color: AppColors.neutralSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: isExpanded
                      ? Column(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1),
                            ),
                            _CompactRow(
                              'Engel',
                              member.hasDisability
                                  ? _optionLabel(
                                      catalog.disabilityStatuses,
                                      member.disabilityTypeCode,
                                    )
                                  : _optionLabel(
                                      catalog.disabilityStatuses,
                                      'YOK',
                                    ),
                            ),
                            _CompactRow(
                              'Çalışma',
                              _optionLabel(
                                catalog.employmentStatuses,
                                member.employmentStatusCode,
                              ),
                            ),
                            _CompactRow(
                              'Eğitim',
                              _optionLabel(
                                catalog.educationStatuses,
                                member.educationStatusCode,
                              ),
                            ),
                            _CompactRow(
                              'Yaşam Durumu',
                              _optionLabel(
                                catalog.vitalStatuses,
                                member.vitalStatusCode,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HouseholdSection extends StatelessWidget {
  const _HouseholdSection({
    required this.answers,
    required this.catalog,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<SubmittedApplicationHouseholdAnswer> answers;
  final ApplicationReferenceCatalog catalog;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _Section(
      toggleKey: const Key('application-detail-section-household'),
      icon: Icons.home_outlined,
      title: 'Hane Bilgileri',
      isExpanded: isExpanded,
      onToggle: onToggle,
      children: answers.isEmpty
          ? const [_EmptyValue('Kayıtlı hane cevabı bulunmuyor.')]
          : [
              for (final answer in answers)
                _Row(
                  _householdQuestionLabel(catalog, answer.questionCode),
                  _householdOptionLabel(catalog, answer),
                ),
            ],
    );
  }
}

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photos,
    required this.loadPhoto,
    required this.isExpanded,
    required this.onToggle,
  });

  final List<SubmittedApplicationPhoto> photos;
  final SubmittedApplicationPhotoLoader loadPhoto;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return _Section(
      toggleKey: const Key('application-detail-section-photos'),
      icon: Icons.photo_library_outlined,
      title: 'Hane Fotoğrafları (${photos.length})',
      isExpanded: isExpanded,
      onToggle: onToggle,
      children: photos.isEmpty
          ? const [_EmptyValue('Kayıtlı hane fotoğrafı bulunmuyor.')]
          : [
              GridView.builder(
                key: const Key('application-photo-grid'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: photos.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) => _PhotoThumbnail(
                  key: ValueKey(photos[index].photoId),
                  photo: photos[index],
                  index: index,
                  loadPhoto: loadPhoto,
                ),
              ),
            ],
    );
  }
}

class _PhotoThumbnail extends StatefulWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.index,
    required this.loadPhoto,
    super.key,
  });

  final SubmittedApplicationPhoto photo;
  final int index;
  final SubmittedApplicationPhotoLoader loadPhoto;

  @override
  State<_PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<_PhotoThumbnail> {
  late Future<Uint8List> _photoBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PhotoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.photoId != widget.photo.photoId) _load();
  }

  void _load() {
    _photoBytes = widget.loadPhoto(widget.photo.photoId);
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final label =
        widget.photo.description ?? 'Hane fotoğrafı ${widget.index + 1}';
    return FutureBuilder<Uint8List>(
      future: _photoBytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _PhotoFrame(
            child: Center(
              child: SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary.withValues(alpha: 0.75),
                ),
              ),
            ),
          );
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          return _PhotoFrame(
            child: InkWell(
              key: Key('application-photo-retry-${widget.photo.photoId}'),
              onTap: _retry,
              child: const Center(
                child: Icon(
                  Icons.refresh_rounded,
                  color: AppColors.neutralSecondary,
                  size: 26,
                ),
              ),
            ),
          );
        }
        return Semantics(
          button: true,
          label: '$label fotoğrafını büyüt',
          child: _PhotoFrame(
            child: InkWell(
              key: Key('application-photo-thumbnail-${widget.photo.photoId}'),
              onTap: () => _showPhotoPreview(context, bytes, label),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.neutralSecondary,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB3000000)],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 14, 28, 6),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 6,
                    top: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x99000000),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.zoom_out_map_rounded,
                          color: AppColors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPhotoPreview(
    BuildContext context,
    Uint8List bytes,
    String label,
  ) {
    return showDialog<void>(
      context: context,
      barrierColor: const Color(0xE6000000),
      builder: (dialogContext) => Dialog(
        key: Key('application-photo-preview-${widget.photo.photoId}'),
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(),
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 64, 12, 72),
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.white,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Color(0x66000000),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    key: const Key('application-photo-preview-close'),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.white,
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 24,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primarySurface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.toggleKey,
    required this.icon,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  final Key toggleKey;
  final IconData icon;
  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x1F3629B7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A3629B7),
            offset: Offset(0, 5),
            blurRadius: 20,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: toggleKey,
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.neutralDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: isExpanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.neutralSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _displayValue(value),
            style: const TextStyle(
              color: AppColors.neutralDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.neutralSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _displayValue(value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppColors.neutralDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyValue extends StatelessWidget {
  const _EmptyValue(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: const TextStyle(
          color: AppColors.neutralSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.statusRejected,
              size: 42,
            ),
            const SizedBox(height: 14),
            const Text(
              'Başvuru yüklenemedi',
              style: TextStyle(
                color: AppColors.neutralDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.neutralSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              key: const Key('application-detail-retry'),
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Tekrar Dene'),
            ),
          ],
        ),
      ),
    );
  }
}

String _optionLabel(List<ApplicationReferenceOption> options, String? code) {
  if (code == null || code.trim().isEmpty) return 'Bilgi bulunmuyor';
  for (final option in options) {
    if (option.code == code) return option.label;
  }
  return _humanizeCode(code);
}

String _householdQuestionLabel(
  ApplicationReferenceCatalog catalog,
  String code,
) {
  for (final question in catalog.householdQuestions) {
    if (question.code == code) return question.label;
  }
  return _humanizeCode(code);
}

String _householdOptionLabel(
  ApplicationReferenceCatalog catalog,
  SubmittedApplicationHouseholdAnswer answer,
) {
  for (final question in catalog.householdQuestions) {
    if (question.code != answer.questionCode) continue;
    for (final option in question.options) {
      if (option.code == answer.optionCode) return option.label;
    }
  }
  return _humanizeCode(answer.optionCode);
}

String _displayValue(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? 'Bilgi bulunmuyor' : trimmed;
}

String _humanizeCode(String code) {
  return code
      .trim()
      .toLowerCase()
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Bilgi bulunmuyor';
  return [
    value.day.toString().padLeft(2, '0'),
    value.month.toString().padLeft(2, '0'),
    value.year.toString().padLeft(4, '0'),
  ].join('.');
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Bilgi bulunmuyor';
  final local = value.toLocal();
  return '${_formatDate(local)} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

String _formatPhone(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final normalized = digits.startsWith('90') && digits.length == 12
      ? digits.substring(2)
      : digits.startsWith('0') && digits.length == 11
      ? digits.substring(1)
      : digits;
  if (normalized.length != 10) return value;
  return '(${normalized.substring(0, 3)}) '
      '${normalized.substring(3, 6)} '
      '${normalized.substring(6, 8)} '
      '${normalized.substring(8)}';
}

_StatusView _statusView(String code) {
  return switch (code.toUpperCase()) {
    'KURUL_BEKLIYOR' => const _StatusView('Beklemede', AppColors.statusBoard),
    'TAMAMLANDI' ||
    'ONAYLANDI' => const _StatusView('Tamamlandı', AppColors.statusApproved),
    'REDDEDILDI' => const _StatusView('Reddedildi', AppColors.statusRejected),
    'IPTAL' ||
    'IPTAL_EDILDI' => const _StatusView('İptal', AppColors.statusRejected),
    'ISLEMDE' => const _StatusView('İşlemde', AppColors.statusDraft),
    _ => _StatusView(_humanizeCode(code), AppColors.statusBoard),
  };
}

final class _StatusView {
  const _StatusView(this.label, this.color);

  final String label;
  final Color color;
}
