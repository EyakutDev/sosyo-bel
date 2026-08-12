import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/family_information_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/family_information_editor_page.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/widgets/activity_step_tabs.dart';
import 'package:sosyo_bel/features/activity/presentation/widgets/family_member_form_sheet.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';

/// Figma'daki `Aile Bilgileri` ekranlarının (2015:24213 ve 2020:24542)
/// Flutter karşılığı.
///
/// Liste ve açılır kişi ayrıntısı tamamen sunum verisiyle çalışır. Gerçek aile
/// kayıtlarının hangi API'den geleceği bu ekranın sorumluluğu değildir.
class FamilyInformationPage extends StatefulWidget {
  const FamilyInformationPage({
    required this.onBack,
    required this.onContinue,
    required this.onUpdateInformation,
    required this.onEditMember,
    required this.referenceCatalog,
    this.onHeaderBack,
    this.onFamilyChanged,
    this.data = FamilyInformationDesignFixture.family,
    super.key,
  });

  /// Alt `Geri Dön` düğmesi yalnızca önceki Aktivite adımını açar.
  final VoidCallback onBack;

  /// Üst ok farklı bir hedefe gidebildiği için alt düğmeden ayrı tutulur.
  final VoidCallback? onHeaderBack;
  final VoidCallback onContinue;
  final VoidCallback onUpdateInformation;
  final ValueChanged<FamilyMemberViewData> onEditMember;
  final ApplicationReferenceCatalog referenceCatalog;
  final ValueChanged<FamilyInformationViewData>? onFamilyChanged;
  final FamilyInformationViewData data;

  @override
  State<FamilyInformationPage> createState() => _FamilyInformationPageState();
}

class _FamilyInformationPageState extends State<FamilyInformationPage> {
  static const _referenceWidth = 375.0;
  static const _referenceHeight = 812.0;
  static const _firstRowTop = 301.0;
  static const _rowSpacing = 50.0;
  static const _expandedOffset = 129.0;
  static const _designMemberCount = 5;

  late final List<FamilyMemberViewData> _members;
  int? _expandedMemberIndex;

  @override
  void initState() {
    super.initState();
    _members = List.of(widget.data.members);
  }

  FamilyInformationViewData get _currentData =>
      FamilyInformationViewData(members: List.unmodifiable(_members));

  void _publishFamilyChanges() {
    widget.onFamilyChanged?.call(_currentData);
  }

  void _toggleMember(int index) {
    final member = _members[index];

    // Figma yalnızca Emel YILMAZ için ayrıntı değerleri veriyor. Diğer kişilere
    // veri uydurmak yerine eksik ayrıntıyı açıkça bildiriyoruz.
    if (member.details == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Aile üyesinin ayrıntı bilgisi bulunamadı.'),
            backgroundColor: AppColors.primary,
          ),
        );
      return;
    }

    setState(() {
      _expandedMemberIndex = _expandedMemberIndex == index ? null : index;
    });
  }

  Future<void> _openFamilyEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (editorContext) => FamilyInformationEditorPage(
          data: _currentData,
          referenceCatalog: widget.referenceCatalog,
          onChanged: (updatedData) {
            if (!mounted) return;
            setState(() {
              _members
                ..clear()
                ..addAll(updatedData.members);
              _expandedMemberIndex = null;
            });
            _publishFamilyChanges();
            widget.onUpdateInformation();
          },
        ),
      ),
    );
  }

  Future<void> _editMember(int index) async {
    final updatedMember = await showFamilyMemberFormSheet(
      context,
      referenceCatalog: widget.referenceCatalog,
      initialMember: _members[index],
    );
    if (!mounted || updatedMember == null) return;

    setState(() => _members[index] = updatedMember);
    _publishFamilyChanges();
    widget.onEditMember(updatedMember);
  }

  double _rowTop(int index) {
    var top = _firstRowTop + (index * _rowSpacing);
    final expandedIndex = _expandedMemberIndex;
    if (expandedIndex != null && index > expandedIndex) {
      top += _expandedOffset;
    }
    return top;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final scale = screenSize.width / _referenceWidth;
    // Figma beş satır gösteriyor. Manuel eklenen her yakın için ekran uzatılır;
    // böylece yeni satırlar kalem ve alt eylem düğmeleriyle çakışmaz.
    final extraMemberCount = math.max(0, _members.length - _designMemberCount);
    final dynamicOffset = extraMemberCount * _rowSpacing;
    final contentHeight = math.max(
      screenSize.height,
      (_referenceHeight + dynamicOffset) * scale,
    );
    final expandedIndex = _expandedMemberIndex;

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
                    selectedStep: ActivityStep.family,
                    scale: scale,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 245 * scale,
                  height: 37 * scale,
                  child: _FamilyTableHeader(scale: scale),
                ),
                for (var index = 0; index < _members.length; index++)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _rowTop(index) * scale,
                    height: 37 * scale,
                    child: _FamilyMemberRow(
                      index: index,
                      member: _members[index],
                      isExpanded: expandedIndex == index,
                      scale: scale,
                      onTap: () => _toggleMember(index),
                    ),
                  ),
                if (expandedIndex != null)
                  _MemberDetails(
                    member: _members[expandedIndex],
                    rowTop: _rowTop(expandedIndex),
                    scale: scale,
                    onEdit: () => _editMember(expandedIndex),
                  ),
                if (expandedIndex == null)
                  Positioned(
                    left: 260 * scale,
                    top: (585 + dynamicOffset) * scale,
                    width: 95 * scale,
                    height: 90 * scale,
                    child: _UpdateInformationAction(
                      scale: scale,
                      onTap: _openFamilyEditor,
                    ),
                  ),
                Positioned(
                  left: 34 * scale,
                  top: (716 + dynamicOffset) * scale,
                  width: 143 * scale,
                  height: 36 * scale,
                  child: _BottomActionButton(
                    buttonKey: const Key('family-information-back-button'),
                    label: 'Geri Dön',
                    backgroundColor: AppColors.primaryMuted,
                    isBack: true,
                    scale: scale,
                    onTap: widget.onBack,
                  ),
                ),
                Positioned(
                  left: 208 * scale,
                  top: (716 + dynamicOffset) * scale,
                  width: 143 * scale,
                  height: 36 * scale,
                  child: _BottomActionButton(
                    buttonKey: const Key('family-information-continue-button'),
                    label: 'Devam Et',
                    backgroundColor: AppColors.primary,
                    scale: scale,
                    onTap: widget.onContinue,
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
                            key: const Key(
                              'family-information-header-back-button',
                            ),
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

class _FamilyTableHeader extends StatelessWidget {
  const _FamilyTableHeader({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _HeaderCell(left: 24, width: 143, label: 'Ad Soyad', scale: scale),
        _HeaderCell(
          left: 167,
          width: 99,
          label: 'Yakınlık',
          rightInset: 20,
          scale: scale,
        ),
        _HeaderCell(
          left: 270,
          width: 99,
          label: 'Yaş',
          rightInset: 20,
          scale: scale,
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.left,
    required this.width,
    required this.label,
    required this.scale,
    this.rightInset,
  });

  final double left;
  final double width;
  final String label;
  final double scale;
  final double? rightInset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left * scale,
      top: 0,
      width: width * scale,
      height: 36 * scale,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: (rightInset ?? 0) * scale,
            top: 0,
            child: Text(
              label,
              textAlign: rightInset == null ? TextAlign.left : TextAlign.right,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w500,
                height: 24 / 14,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: math.max(0.5, 0.5 * scale),
            child: const ColoredBox(color: AppColors.neutralDisabled),
          ),
        ],
      ),
    );
  }
}

class _FamilyMemberRow extends StatelessWidget {
  const _FamilyMemberRow({
    required this.index,
    required this.member,
    required this.isExpanded,
    required this.scale,
    required this.onTap,
  });

  final int index;
  final FamilyMemberViewData member;
  final bool isExpanded;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 8 * scale,
          top: -4 * scale,
          width: 31 * scale,
          height: 31 * scale,
          child: Semantics(
            button: true,
            label:
                '${member.fullName} ayrıntısını ${isExpanded ? 'kapat' : 'aç'}',
            child: GestureDetector(
              key: Key('family-member-toggle-$index'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Center(
                child: SizedBox(
                  width: 15 * scale,
                  height: 15 * scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SvgPicture.asset(
                        isExpanded
                            ? AppAssets.activityFamilyCollapseCircle
                            : AppAssets.activityFamilyExpandCircle,
                        width: 15 * scale,
                        height: 15 * scale,
                      ),
                      if (isExpanded)
                        Text(
                          'v',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 6 * scale,
                            fontWeight: FontWeight.w500,
                            height: 1,
                          ),
                        )
                      else
                        SvgPicture.asset(
                          AppAssets.activityFamilyExpandPlus,
                          width: 7 * scale,
                          height: 7 * scale,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 39 * scale,
          top: 0,
          width: 143 * scale,
          child: _MemberText(
            value: member.fullName,
            alignment: TextAlign.left,
            scale: scale,
          ),
        ),
        Positioned(
          left: 177 * scale,
          top: 0,
          width: 103 * scale,
          child: _MemberText(
            value: member.relationship,
            alignment: TextAlign.center,
            scale: scale,
          ),
        ),
        Positioned(
          left: 270 * scale,
          right: 26 * scale,
          top: 0,
          child: _MemberText(
            value: member.age,
            alignment: TextAlign.right,
            scale: scale,
          ),
        ),
        _RowDivider(left: 39, width: 143, scale: scale),
        _RowDivider(left: 177, width: 103, scale: scale),
        _RowDivider(left: 270, width: 103, scale: scale),
      ],
    );
  }
}

class _MemberText extends StatelessWidget {
  const _MemberText({
    required this.value,
    required this.alignment,
    required this.scale,
  });

  final String value;
  final TextAlign alignment;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: alignment,
      style: TextStyle(
        color: AppColors.neutralStatusLabel,
        fontSize: 14 * scale,
        fontWeight: FontWeight.w500,
        height: 24 / 14,
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider({
    required this.left,
    required this.width,
    required this.scale,
  });

  final double left;
  final double width;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left * scale,
      bottom: 0,
      width: width * scale,
      height: math.max(0.5, 0.5 * scale),
      child: const ColoredBox(color: AppColors.neutralDisabled),
    );
  }
}

class _MemberDetails extends StatelessWidget {
  const _MemberDetails({
    required this.member,
    required this.rowTop,
    required this.scale,
    required this.onEdit,
  });

  final FamilyMemberViewData member;
  final double rowTop;
  final double scale;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final details = member.details;
    if (details == null) {
      return const SizedBox.shrink();
    }

    final detailsTop = rowTop + 46;
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: 37 * scale,
            top: detailsTop * scale,
            width: 261 * scale,
            height: 110 * scale,
            child: Stack(
              children: [
                _DetailRow(
                  top: 0,
                  label: 'Engel Durumu',
                  value: details.disabilityStatus,
                  scale: scale,
                ),
                _DetailRow(
                  top: 18,
                  label: 'Çalışma Durumu',
                  value: details.employmentStatus,
                  scale: scale,
                ),
                _DetailRow(
                  top: 37,
                  label: 'Eğitim Durumu',
                  value: details.educationStatus,
                  scale: scale,
                ),
                _DetailRow(
                  top: 55,
                  label: 'Ölü / Sağ',
                  value: details.vitalStatus,
                  scale: scale,
                ),
                Positioned(
                  left: 0,
                  top: 85 * scale,
                  width: 104 * scale,
                  height: 25 * scale,
                  child: Material(
                    color: AppColors.primarySecondary,
                    borderRadius: BorderRadius.circular(5 * scale),
                    child: InkWell(
                      key: const Key('family-member-edit-button'),
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(5 * scale),
                      child: Center(
                        child: Text(
                          'Bilgi Güncelle',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 10 * scale,
                            fontWeight: FontWeight.w500,
                            height: 24 / 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: (rowTop + 171) * scale,
            height: math.max(1, scale),
            child: Image.asset(
              AppAssets.activityFamilyExpandedDivider,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.top,
    required this.label,
    required this.value,
    required this.scale,
  });

  final double top;
  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: top * scale,
      width: 261 * scale,
      height: 16 * scale,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.primarySecondary,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
                height: 16 / 12,
              ),
            ),
          ),
          Positioned(
            left: 165 * scale,
            top: 0,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.neutralDark,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w600,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateInformationAction extends StatelessWidget {
  const _UpdateInformationAction({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bilgi Güncelle',
      child: GestureDetector(
        key: const Key('family-information-update-button'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          children: [
            Positioned(
              left: 21 * scale,
              top: 8 * scale,
              width: 54 * scale,
              height: 54 * scale,
              child: SvgPicture.asset(AppAssets.activityFamilyEditCircle),
            ),
            Positioned(
              left: 36 * scale,
              top: 23 * scale,
              width: 24 * scale,
              height: 24 * scale,
              child: SvgPicture.asset(AppAssets.activityFamilyEditPencil),
            ),
            Positioned(
              left: 6 * scale,
              top: 62 * scale,
              width: 82 * scale,
              height: 24 * scale,
              child: Text(
                'Bilgi Güncelle',
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
