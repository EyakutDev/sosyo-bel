import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/widgets/family_member_form_sheet.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';

/// Kalemli genel eylemin açtığı manuel aile bilgileri yönetim ekranı.
///
/// Bu ekran ekleme ve düzenleme yapar; silme iş kuralı onaylanmadığı için
/// özellikle sunulmaz. Her değişiklik [onChanged] ile üst akışa bildirilir.
class FamilyInformationEditorPage extends StatefulWidget {
  const FamilyInformationEditorPage({
    required this.data,
    required this.onChanged,
    required this.referenceCatalog,
    super.key,
  });

  final FamilyInformationViewData data;
  final ValueChanged<FamilyInformationViewData> onChanged;
  final ApplicationReferenceCatalog referenceCatalog;

  @override
  State<FamilyInformationEditorPage> createState() =>
      _FamilyInformationEditorPageState();
}

class _FamilyInformationEditorPageState
    extends State<FamilyInformationEditorPage> {
  late final List<FamilyMemberViewData> _members;

  @override
  void initState() {
    super.initState();
    _members = List.of(widget.data.members);
  }

  void _publishChanges() {
    widget.onChanged(
      FamilyInformationViewData(members: List.unmodifiable(_members)),
    );
  }

  Future<void> _addMember() async {
    final member = await showFamilyMemberFormSheet(
      context,
      referenceCatalog: widget.referenceCatalog,
    );
    if (!mounted || member == null) return;

    setState(() => _members.add(member));
    _publishChanges();
    _showSavedMessage('Yakın bilgisi eklendi.');
  }

  Future<void> _editMember(int index) async {
    final updatedMember = await showFamilyMemberFormSheet(
      context,
      referenceCatalog: widget.referenceCatalog,
      initialMember: _members[index],
    );
    if (!mounted || updatedMember == null) return;

    setState(() => _members[index] = updatedMember);
    _publishChanges();
    _showSavedMessage('Yakın bilgisi güncellendi.');
  }

  void _showSavedMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.primary,
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        key: const Key('family-information-editor-page'),
        backgroundColor: AppColors.primarySurface,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leadingWidth: 52,
          leading: IconButton(
            key: const Key('family-editor-back-button'),
            tooltip: 'Geri',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.neutralDark,
            ),
          ),
          titleSpacing: 0,
          title: const Text(
            'Aile Bilgilerini Yönet',
            style: TextStyle(
              color: AppColors.neutralDark,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: AppColors.white,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: const Text(
                  'Yakınların sınırlı bilgilerini elle ekleyebilir veya '
                  'mevcut kayıtları güncelleyebilirsiniz.',
                  style: TextStyle(
                    color: AppColors.neutralSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                  itemCount: _members.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _EditableMemberCard(
                      index: index,
                      member: _members[index],
                      onEdit: () => _editMember(index),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: ColoredBox(
            color: AppColors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton.icon(
                key: const Key('family-editor-add-member-button'),
                onPressed: _addMember,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                label: const Text(
                  'Yeni Yakın Ekle',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EditableMemberCard extends StatelessWidget {
  const _EditableMemberCard({
    required this.index,
    required this.member,
    required this.onEdit,
  });

  final int index;
  final FamilyMemberViewData member;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final details = member.details;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x143629B7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D3629B7),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0x173629B7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: const TextStyle(
                          color: AppColors.neutralDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${member.relationship} • ${member.age} yaş',
                        style: const TextStyle(
                          color: AppColors.neutralSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  key: Key('family-editor-edit-member-$index'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Düzenle'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primarySecondary,
                  ),
                ),
              ],
            ),
            if (details != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.neutralDisabled),
              ),
              _CompactDetail(label: 'Engel', value: details.disabilityStatus),
              _CompactDetail(label: 'Çalışma', value: details.employmentStatus),
              _CompactDetail(label: 'Eğitim', value: details.educationStatus),
              _CompactDetail(label: 'Durum', value: details.vitalStatus),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Ayrıntı bilgileri henüz girilmemiş.',
                    style: TextStyle(
                      color: AppColors.statusBoard,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactDetail extends StatelessWidget {
  const _CompactDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.primarySecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.neutralDark,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
