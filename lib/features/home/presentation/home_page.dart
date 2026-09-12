import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sosyo_bel/core/branding/municipality_branding.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/core/widgets/app_notice.dart';
import 'package:sosyo_bel/core/widgets/municipality_logo.dart';
import 'package:sosyo_bel/features/application/presentation/widgets/application_exit_dialog.dart';
import 'package:sosyo_bel/features/home/domain/work_item.dart';
import 'package:sosyo_bel/features/home/domain/work_items_repository.dart';
import 'package:sosyo_bel/features/home/presentation/mappers/work_item_card_mapper.dart';
import 'package:sosyo_bel/features/home/presentation/models/application_card_view_data.dart';
import 'package:sosyo_bel/features/home/presentation/widgets/application_summary_card.dart';
import 'package:sosyo_bel/features/home/presentation/widgets/home_list_tabs.dart';

/// Figma'daki bekleyen (2:22909) ve tamamlanmış (2014:24020) ana ekranları.
///
/// Bekleyen ve tamamlanmış işler birleşik iş listesi API'sinden yüklenir.
class HomePage extends StatefulWidget {
  const HomePage({
    required this.workItemsRepository,
    this.initialFilter = HomeListFilter.pending,
    this.onBack,
    this.initialSuccessMessage,
    this.onOpenEditableDraft,
    this.onOpenSubmittedApplication,
    this.onDeleteLocalDraft,
    this.municipalityBranding = MunicipalityBranding.demo,
    super.key,
  });

  final HomeListFilter initialFilter;
  final WorkItemsRepository workItemsRepository;
  final VoidCallback? onBack;
  final String? initialSuccessMessage;
  final Future<void> Function(WorkItem item)? onOpenEditableDraft;
  final Future<void> Function(WorkItem item)? onOpenSubmittedApplication;
  final Future<void> Function(WorkItem item)? onDeleteLocalDraft;
  final MunicipalityBranding municipalityBranding;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _referenceWidth = 375.0;

  late HomeListFilter _selectedFilter;
  List<WorkItem> _workItems = const [];
  bool _isLoading = true;
  bool _showOnlyOwnedApplications = false;
  String? _loadErrorMessage;
  String? _openingDraftId;
  int? _openingApplicationId;
  String? _deletingDraftId;

  Future<void> _openSubmittedApplication(WorkItem item) async {
    final callback = widget.onOpenSubmittedApplication;
    final applicationId = item.applicationId;
    if (callback == null ||
        !item.isSubmittedApplication ||
        applicationId == null ||
        _openingApplicationId != null) {
      return;
    }
    setState(() => _openingApplicationId = applicationId);
    try {
      await callback(item);
      if (mounted) await _loadWorkItems(keepCurrentContent: true);
    } on ApiException catch (error) {
      _showOpenError(error.message);
    } catch (_) {
      _showOpenError('Başvuru detayları açılamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _openingApplicationId = null);
    }
  }

  Future<void> _openEditableDraft(WorkItem item) async {
    final callback = widget.onOpenEditableDraft;
    final draftId = item.localDraftId ?? item.applicationPublicId;
    if (callback == null ||
        !item.isEditable ||
        draftId == null ||
        _openingDraftId != null) {
      return;
    }
    setState(() => _openingDraftId = draftId);
    try {
      await callback(item);
    } on ApiException catch (error) {
      _showOpenError(error.message);
    } catch (_) {
      _showOpenError('Taslak açılamadı. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _openingDraftId = null);
    }
  }

  void _showOpenError(String message) {
    if (!mounted) return;
    showAppNotice(context, message: message, tone: AppNoticeTone.error);
  }

  void _toggleOwnedApplicationsFilter() {
    final willEnable = !_showOnlyOwnedApplications;
    setState(() => _showOnlyOwnedApplications = willEnable);
    if (!willEnable) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          key: Key('home-owned-filter-message'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          content: _OwnedFilterNotice(),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1600),
          margin: EdgeInsets.fromLTRB(24, 0, 24, 82),
        ),
      );
  }

  Future<void> _deleteLocalDraft(WorkItem item) async {
    final callback = widget.onDeleteLocalDraft;
    final draftId = item.localDraftId;
    if (callback == null ||
        !item.isLocalDraft ||
        draftId == null ||
        _deletingDraftId != null) {
      return;
    }

    final isConfirmed = await showLocalDraftDeleteDialog(context);
    if (!mounted || !isConfirmed) return;

    setState(() => _deletingDraftId = draftId);
    try {
      await callback(item);
      if (!mounted) return;
      setState(() {
        _workItems = _workItems
            .where((workItem) => workItem.localDraftId != draftId)
            .toList(growable: false);
      });
      showAppNotice(
        context,
        message: 'Yerel taslak silindi.',
        tone: AppNoticeTone.success,
      );
    } on ApiException catch (error) {
      _showOpenError(error.message);
    } catch (_) {
      _showOpenError('Yerel taslak silinemedi. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _deletingDraftId = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _loadWorkItems();

    if (widget.initialSuccessMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showInitialSuccessMessage();
      });
    }
  }

  Future<void> _loadWorkItems({bool keepCurrentContent = false}) async {
    if (!keepCurrentContent) {
      setState(() {
        _isLoading = true;
        _loadErrorMessage = null;
      });
    }
    try {
      final workItems = await widget.workItemsRepository.getMyWorkItems();
      if (!mounted) return;
      setState(() {
        _workItems = workItems;
        _isLoading = false;
        _loadErrorMessage = null;
      });
    } on ApiException catch (error) {
      if (keepCurrentContent) {
        _showOpenError(error.message);
      } else {
        _finishLoadingWithError(error.message);
      }
    } catch (_) {
      const message = 'İşler yüklenemedi. Lütfen tekrar deneyin.';
      if (keepCurrentContent) {
        _showOpenError(message);
      } else {
        _finishLoadingWithError(message);
      }
    }
  }

  void _finishLoadingWithError(String message) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _loadErrorMessage = message;
    });
  }

  void _showInitialSuccessMessage() {
    if (!mounted || widget.initialSuccessMessage == null) return;

    // Mesaj hedef sayfanın Scaffold'u kurulduktan sonra gösterilir; böylece
    // Tamamla rotası kapatılırken bildirim kaybolmaz.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('submission-success-notice'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.white,
          elevation: 8,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Color(0x143629B7)),
          ),
          content: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0x1A52D5BA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.statusApproved,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.initialSuccessMessage!,
                  style: const TextStyle(
                    color: AppColors.neutralDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 20 / 13,
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final scale = screenWidth / _referenceWidth;
    final bottomControlsOffset = math.max(14 * scale, bottomInset + 6);
    final listBottomPadding = bottomControlsOffset + (76 * scale);
    final statusFilteredWorkItems = _workItems.where((item) {
      return _selectedFilter == HomeListFilter.completed
          ? item.isCompleted
          : !item.isCompleted;
    });
    final listedWorkItems = statusFilteredWorkItems
        .where(
          (item) =>
              !_showOnlyOwnedApplications ||
              item.isOwnedByCurrentUser ||
              item.isLocalDraft,
        )
        .toList(growable: false);
    final applications = listedWorkItems
        .map(WorkItemCardMapper.toViewData)
        .toList(growable: false);
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
              ),
            ),
            Positioned(
              left: 31 * scale,
              top: 59 * scale,
              width: 87 * scale,
              height: 88 * scale,
              child: ClipOval(
                child: MunicipalityLogo(
                  key: const Key('home-municipality-logo'),
                  branding: widget.municipalityBranding,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned(
              left: 132 * scale,
              right: 24 * scale,
              top: 82 * scale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hoş geldiniz',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 17 * scale,
                      fontWeight: FontWeight.w600,
                      height: 23 / 17,
                    ),
                  ),
                  SizedBox(height: 2 * scale),
                  Text(
                    'Görevlerinizi görüntüleyin',
                    style: TextStyle(
                      color: const Color(0xCCFFFFFF),
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w400,
                      height: 18 / 12,
                    ),
                  ),
                ],
              ),
            ),
            // Geri düğmesi logodan sonra çizilir; aşağı taşındığında şeffaf logo
            // sınırının dokunma alanını kapatması böylece engellenir.
            if (widget.onBack != null)
              Positioned(
                left: 12 * scale,
                top: 39 * scale,
                width: 40 * scale,
                height: 40 * scale,
                child: IconButton(
                  key: const Key('home-back-button'),
                  padding: EdgeInsets.zero,
                  tooltip: 'Geri',
                  onPressed: widget.onBack,
                  icon: Transform.rotate(
                    angle: math.pi / 2,
                    child: SvgPicture.asset(
                      AppAssets.activityBackArrow,
                      width: 16 * scale,
                      height: 9 * scale,
                      colorFilter: const ColorFilter.mode(
                        AppColors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 24 * scale,
              right: 24 * scale,
              top: 233 * scale,
              bottom: 0,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _buildTaskContent(
                      listedWorkItems,
                      applications,
                      scale,
                      listBottomPadding,
                    ),
                  ),
                  Positioned(
                    key: const Key('home-bottom-controls'),
                    left: 0,
                    right: 0,
                    bottom: bottomControlsOffset,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: HomeListTabs(
                            selectedFilter: _selectedFilter,
                            scale: scale,
                            onChanged: (filter) {
                              setState(() => _selectedFilter = filter);
                            },
                          ),
                        ),
                        SizedBox(width: 12 * scale),
                        _OwnApplicationsFilter(
                          isActive: _showOnlyOwnedApplications,
                          scale: scale,
                          onToggle: _toggleOwnedApplicationsFilter,
                        ),
                      ],
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

  Widget _buildTaskContent(
    List<WorkItem> listedWorkItems,
    List<ApplicationCardViewData> applications,
    double scale,
    double bottomPadding,
  ) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('home-loading-indicator'),
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    final errorMessage = _loadErrorMessage;
    if (errorMessage != null) {
      return _HomeListMessage(
        key: const Key('home-error-state'),
        icon: Icons.cloud_off_rounded,
        title: 'İşler yüklenemedi',
        message: errorMessage,
        actionLabel: 'Tekrar Dene',
        onAction: _loadWorkItems,
        scale: scale,
      );
    }

    if (applications.isEmpty) {
      final completed = _selectedFilter == HomeListFilter.completed;
      if (_showOnlyOwnedApplications) {
        return _HomeListMessage(
          key: const Key('home-empty-owned-state'),
          icon: Icons.person_search_outlined,
          title: completed
              ? 'Tamamlanan başvurunuz bulunmuyor'
              : 'Bekleyen başvurunuz bulunmuyor',
          message:
              'Filtreyi kaldırarak diğer başvuru ve görevleri görebilirsiniz.',
          scale: scale,
        );
      }
      return _HomeListMessage(
        key: const Key('home-empty-state'),
        icon: completed ? Icons.task_alt_rounded : Icons.assignment_outlined,
        title: completed
            ? 'Tamamlanmış iş bulunmuyor'
            : 'Bekleyen iş bulunmuyor',
        message: completed
            ? 'Tamamlanan başvuru ve görevler burada listelenecek.'
            : 'Başvurularınız ve size atanan görevler burada görünecek.',
        scale: scale,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadWorkItems,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottomPadding),
        itemCount: applications.length,
        separatorBuilder: (context, index) => SizedBox(height: 20 * scale),
        itemBuilder: (context, index) {
          final item = listedWorkItems[index];
          final localDraftId = item.localDraftId;
          final canDelete =
              item.isLocalDraft &&
              localDraftId != null &&
              widget.onDeleteLocalDraft != null;
          final canOpenSubmittedApplication =
              item.isSubmittedApplication &&
              item.applicationId != null &&
              widget.onOpenSubmittedApplication != null;
          final canOpenEditableDraft =
              item.isEditable &&
              !canOpenSubmittedApplication &&
              widget.onOpenEditableDraft != null;
          return ApplicationSummaryCard(
            data: applications[index],
            scale: scale,
            onTap:
                _deletingDraftId == null &&
                    _openingApplicationId == null &&
                    (canOpenSubmittedApplication || canOpenEditableDraft)
                ? () {
                    if (canOpenSubmittedApplication) {
                      _openSubmittedApplication(item);
                    } else {
                      _openEditableDraft(item);
                    }
                  }
                : null,
            onDelete: canDelete ? () => _deleteLocalDraft(item) : null,
            isDeleting: localDraftId == _deletingDraftId,
            deleteButtonKey: localDraftId == null
                ? null
                : ValueKey('delete-local-draft-$localDraftId'),
          );
        },
      ),
    );
  }
}

class _OwnedFilterNotice extends StatelessWidget {
  const _OwnedFilterNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-owned-filter-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x263629B7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x243629B7),
            offset: Offset(0, 6),
            blurRadius: 18,
          ),
        ],
      ),
      child: const Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.person_search_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Yalnızca başvurularınız gösteriliyor',
              style: TextStyle(
                color: AppColors.neutralDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnApplicationsFilter extends StatelessWidget {
  const _OwnApplicationsFilter({
    required this.isActive,
    required this.scale,
    required this.onToggle,
  });

  final bool isActive;
  final double scale;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: isActive
          ? 'Başvurularım filtresini kaldır'
          : 'Yalnızca başvurularımı göster',
      child: Tooltip(
        message: isActive
            ? 'Başvurularım filtresini kaldır'
            : 'Başvurularımı göster',
        child: Container(
          width: 52 * scale,
          height: 52 * scale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.14),
                offset: Offset(0, 4 * scale),
                blurRadius: 12 * scale,
              ),
            ],
          ),
          child: Material(
            color: isActive ? AppColors.primary : AppColors.white,
            shape: CircleBorder(
              side: BorderSide(
                color: AppColors.primary,
                width: isActive ? 0 : 1.25,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const Key('home-owned-filter-button'),
              onTap: onToggle,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: RotationTransition(
                      turns: Tween<double>(begin: 0.88, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: child,
                    ),
                  ),
                  child: isActive
                      ? Icon(
                          Icons.close_rounded,
                          key: const Key('home-owned-filter-clear'),
                          color: AppColors.white,
                          size: 25 * scale,
                        )
                      : _PersonFilterIcon(scale: scale),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonFilterIcon extends StatelessWidget {
  const _PersonFilterIcon({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: const Key('home-owned-filter-person-icon'),
      dimension: 30 * scale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: const Alignment(-0.2, -0.1),
            child: Icon(
              Icons.person_outline_rounded,
              color: AppColors.primary,
              size: 26 * scale,
            ),
          ),
          Positioned(
            right: -1 * scale,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(3 * scale),
                child: Icon(
                  Icons.filter_alt_rounded,
                  color: AppColors.white,
                  size: 10 * scale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeListMessage extends StatelessWidget {
  const _HomeListMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.scale,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final double scale;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28 * scale),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56 * scale,
              height: 56 * scale,
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 28 * scale),
            ),
            SizedBox(height: 16 * scale),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.neutralDark,
                fontSize: 15 * scale,
                fontWeight: FontWeight.w600,
                height: 22 / 15,
              ),
            ),
            SizedBox(height: 6 * scale),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.neutralSecondary,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w400,
                height: 18 / 12,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 18 * scale),
              TextButton(
                key: const Key('home-retry-button'),
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primarySurface,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * scale,
                    vertical: 10 * scale,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15 * scale),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
