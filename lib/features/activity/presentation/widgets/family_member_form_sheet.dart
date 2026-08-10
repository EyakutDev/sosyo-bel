import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/activity/presentation/models/family_information_view_data.dart';

/// Personelin aynı kavramlar için farklı ifadeler yazmasını engelleyen ortak
/// seçeneklerdir. Engel durumu seçenekleri şirket API'si geldiğinde ayrıca
/// sunucu kaynağına bağlanacaktır.
abstract final class FamilyMemberFormOptions {
  static const otherRelationship = 'Diğer';

  static const relationships = [
    'Eş',
    'Anne',
    'Baba',
    'Çocuk',
    'Kardeş',
    'Büyükanne',
    'Büyükbaba',
    'Torun',
    'Gelin',
    'Damat',
    'Kayınvalide',
    'Kayınpeder',
    otherRelationship,
  ];

  static const employmentStatuses = ['Çalışıyor', 'Çalışmıyor', 'Emekli'];
  static const educationStatuses = [
    'Okuryazar Değil',
    'Okuryazar',
    'İlkokul',
    'İlk Öğretim Terk',
    'Ortaokul',
    'Lise',
    'Ön Lisans',
    'Lisans',
    'Yüksek Lisans',
    'Doktora',
  ];
  static const vitalStatuses = ['Sağ', 'Ölü'];
}

/// Yeni yakın ekleme ve mevcut yakını düzenleme işlemlerinde aynı formu açar.
///
/// Form yalnızca sunum modelini döndürür. Backend hazır olduğunda kalıcı kayıt
/// çağrısı bu sonucu alan akış/repository katmanında yapılacaktır.
Future<FamilyMemberViewData?> showFamilyMemberFormSheet(
  BuildContext context, {
  FamilyMemberViewData? initialMember,
}) {
  return showModalBottomSheet<FamilyMemberViewData>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        _FamilyMemberFormSheet(initialMember: initialMember),
  );
}

class _FamilyMemberFormSheet extends StatefulWidget {
  const _FamilyMemberFormSheet({this.initialMember});

  final FamilyMemberViewData? initialMember;

  @override
  State<_FamilyMemberFormSheet> createState() => _FamilyMemberFormSheetState();
}

class _FamilyMemberFormSheetState extends State<_FamilyMemberFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _otherRelationshipController;
  late final TextEditingController _ageController;
  late final TextEditingController _disabilityController;
  late final FocusNode _otherRelationshipFocusNode;

  String? _selectedRelationship;
  String? _selectedEmploymentStatus;
  String? _selectedEducationStatus;
  String? _selectedVitalStatus;
  String? _openOptionsId;

  bool get _isEditing => widget.initialMember != null;

  @override
  void initState() {
    super.initState();
    final member = widget.initialMember;
    final details = member?.details;
    _fullNameController = TextEditingController(text: member?.fullName ?? '');
    final relationship = member?.relationship;
    final hasStandardRelationship =
        relationship != null &&
        FamilyMemberFormOptions.relationships.contains(relationship);
    _selectedRelationship = relationship == null
        ? null
        : hasStandardRelationship
        ? relationship
        : FamilyMemberFormOptions.otherRelationship;
    _otherRelationshipController = TextEditingController(
      text: hasStandardRelationship ? '' : relationship ?? '',
    );
    _otherRelationshipFocusNode = FocusNode();
    _ageController = TextEditingController(text: member?.age ?? '');
    _disabilityController = TextEditingController(
      text: details?.disabilityStatus ?? '',
    );
    final employmentStatus = details?.employmentStatus;
    _selectedEmploymentStatus =
        FamilyMemberFormOptions.employmentStatuses.contains(employmentStatus)
        ? employmentStatus
        : null;
    final educationStatus = details?.educationStatus;
    _selectedEducationStatus =
        FamilyMemberFormOptions.educationStatuses.contains(educationStatus)
        ? educationStatus
        : null;
    final vitalStatus = details?.vitalStatus;
    _selectedVitalStatus =
        FamilyMemberFormOptions.vitalStatuses.contains(vitalStatus)
        ? vitalStatus
        : null;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _otherRelationshipController.dispose();
    _otherRelationshipFocusNode.dispose();
    _ageController.dispose();
    _disabilityController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan zorunludur.';
    }
    return null;
  }

  /// Bir liste açıldığında diğerini kapatır. Listeler formun içinde
  /// genişlediği için alttaki alanlar menünün arkasında kalmaz.
  void _toggleOptions(String id) {
    FocusScope.of(context).unfocus();
    setState(() => _openOptionsId = _openOptionsId == id ? null : id);
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final relationship =
        _selectedRelationship == FamilyMemberFormOptions.otherRelationship
        ? _otherRelationshipController.text.trim()
        : _selectedRelationship!;

    Navigator.of(context).pop(
      FamilyMemberViewData(
        fullName: _fullNameController.text.trim(),
        relationship: relationship,
        age: _ageController.text.trim(),
        details: FamilyMemberDetailsViewData(
          disabilityStatus: _disabilityController.text.trim(),
          employmentStatus: _selectedEmploymentStatus!,
          educationStatus: _selectedEducationStatus!,
          vitalStatus: _selectedVitalStatus!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: DecoratedBox(
        key: const Key('family-member-form-sheet'),
        decoration: const BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutralBorder,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: Color(0x173629B7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.group_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditing
                          ? 'Yakın Bilgisini Güncelle'
                          : 'Yeni Yakın Ekle',
                      style: const TextStyle(
                        color: AppColors.neutralDark,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('family-member-form-close-button'),
                    tooltip: 'Kapat',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.neutralSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + bottomInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _FamilyFormField(
                        fieldKey: const Key('family-member-full-name-field'),
                        label: 'Ad Soyad',
                        hint: 'Yakının adını ve soyadını yazın',
                        controller: _fullNameController,
                        validator: _requiredValidator,
                        textCapitalization: TextCapitalization.words,
                      ),
                      if (_selectedRelationship ==
                          FamilyMemberFormOptions.otherRelationship)
                        _EditableRelationshipField(
                          fieldKey: const Key(
                            'family-member-relationship-field',
                          ),
                          label: 'Yakınlık',
                          hint: 'Yakınlık durumunu yazın',
                          controller: _otherRelationshipController,
                          focusNode: _otherRelationshipFocusNode,
                          validator: _requiredValidator,
                          isOptionsOpen: _openOptionsId == 'relationship',
                          onToggleOptions: () => _toggleOptions('relationship'),
                          onRelationshipSelected: (value) {
                            setState(() {
                              _openOptionsId = null;
                              _selectedRelationship = value;
                              if (value !=
                                  FamilyMemberFormOptions.otherRelationship) {
                                _otherRelationshipController.clear();
                              }
                            });
                          },
                        )
                      else
                        _FamilyDropdownField(
                          fieldKey: const Key(
                            'family-member-relationship-field',
                          ),
                          label: 'Yakınlık',
                          hint: 'Yakınlık durumunu seçin',
                          value: _selectedRelationship,
                          items: FamilyMemberFormOptions.relationships,
                          isOpen: _openOptionsId == 'relationship',
                          onToggle: () => _toggleOptions('relationship'),
                          optionsKey: const Key(
                            'family-member-relationship-options',
                          ),
                          onChanged: (value) {
                            setState(() {
                              _openOptionsId = null;
                              _selectedRelationship = value;
                              if (value !=
                                  FamilyMemberFormOptions.otherRelationship) {
                                _otherRelationshipController.clear();
                              }
                            });
                            if (value ==
                                FamilyMemberFormOptions.otherRelationship) {
                              // Alan metin girişine dönüştükten sonra personel
                              // ek bir dokunuşa gerek kalmadan yazabilsin.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _otherRelationshipFocusNode.requestFocus();
                                }
                              });
                            }
                          },
                        ),
                      _FamilyFormField(
                        fieldKey: const Key('family-member-age-field'),
                        label: 'Yaş',
                        hint: 'Yaş bilgisini yazın',
                        controller: _ageController,
                        validator: _requiredValidator,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                      ),
                      _FamilyFormField(
                        fieldKey: const Key('family-member-disability-field'),
                        label: 'Engel Durumu',
                        hint: 'Engel durumunu yazın',
                        controller: _disabilityController,
                        validator: _requiredValidator,
                      ),
                      _FamilyDropdownField(
                        fieldKey: const Key('family-member-employment-field'),
                        label: 'Çalışma Durumu',
                        hint: 'Çalışma durumunu seçin',
                        value: _selectedEmploymentStatus,
                        items: FamilyMemberFormOptions.employmentStatuses,
                        isOpen: _openOptionsId == 'employment',
                        onToggle: () => _toggleOptions('employment'),
                        optionsKey: const Key(
                          'family-member-employment-options',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _openOptionsId = null;
                            _selectedEmploymentStatus = value;
                          });
                        },
                      ),
                      _FamilyDropdownField(
                        fieldKey: const Key('family-member-education-field'),
                        label: 'Eğitim Durumu',
                        hint: 'Eğitim durumunu seçin',
                        value: _selectedEducationStatus,
                        items: FamilyMemberFormOptions.educationStatuses,
                        isOpen: _openOptionsId == 'education',
                        onToggle: () => _toggleOptions('education'),
                        optionsKey: const Key(
                          'family-member-education-options',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _openOptionsId = null;
                            _selectedEducationStatus = value;
                          });
                        },
                      ),
                      _FamilyDropdownField(
                        fieldKey: const Key('family-member-vital-field'),
                        label: 'Ölü / Sağ',
                        hint: 'Yaşam durumunu seçin',
                        value: _selectedVitalStatus,
                        items: FamilyMemberFormOptions.vitalStatuses,
                        isOpen: _openOptionsId == 'vital',
                        onToggle: () => _toggleOptions('vital'),
                        optionsKey: const Key('family-member-vital-options'),
                        onChanged: (value) {
                          setState(() {
                            _openOptionsId = null;
                            _selectedVitalStatus = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              key: const Key('family-member-cancel-button'),
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: AppColors.primarySecondary,
                                side: const BorderSide(
                                  color: AppColors.primaryMuted,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text('Vazgeç'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const Key('family-member-save-button'),
                              onPressed: _save,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(_isEditing ? 'Güncelle' : 'Ekle'),
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _FamilyDropdownField extends StatelessWidget {
  const _FamilyDropdownField({
    required this.fieldKey,
    required this.optionsKey,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.isOpen,
    required this.onToggle,
    required this.onChanged,
  });

  final Key fieldKey;
  final Key optionsKey;
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final bool isOpen;
  final VoidCallback onToggle;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FormField<String>(
        initialValue: value,
        validator: (selectedValue) {
          if (selectedValue == null || selectedValue.isEmpty) {
            return 'Bu alan zorunludur.';
          }
          return null;
        },
        builder: (field) {
          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: fieldKey,
                  onTap: onToggle,
                  borderRadius: BorderRadius.circular(15),
                  child: InputDecorator(
                    isEmpty: field.value == null,
                    decoration:
                        _familyInputDecoration(
                          label: label,
                          errorText: field.errorText,
                        ).copyWith(
                          // Seçim alanında ipucu da bulunduğu için başlığı
                          // üstte sabitleriz.
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            field.value ?? hint,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: field.value == null
                                  ? AppColors.neutralPlaceholder
                                  : AppColors.neutralDark,
                              fontSize: field.value == null ? 13 : 14,
                              fontWeight: field.value == null
                                  ? FontWeight.w400
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: isOpen ? 0.5 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.primarySecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: isOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _FamilyInlineOptionsMenu(
                          menuKey: optionsKey,
                          items: items,
                          selectedValue: field.value,
                          onSelected: (selectedValue) {
                            field.didChange(selectedValue);
                            onChanged(selectedValue);
                          },
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Açılır seçenekleri form akışının içinde gösterir.
///
/// Menü tam alan genişliğini kullanır ve normal yerleşime katıldığı için
/// kendisinden sonraki metin alanlarını aşağı iter; hiçbir alan menünün altında
/// kalmaz.
class _FamilyInlineOptionsMenu extends StatelessWidget {
  const _FamilyInlineOptionsMenu({
    required this.menuKey,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  final Key menuKey;
  final List<String> items;
  final String? selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final contentHeight = items.length * 46.0 + 8;
    final menuHeight = contentHeight > 260 ? 260.0 : contentHeight;

    return Container(
      key: menuKey,
      width: double.infinity,
      height: menuHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.neutralBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x163629B7),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: AppColors.white,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: items.length,
          itemExtent: 46,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = item == selectedValue;
            return InkWell(
              onTap: () => onSelected(item),
              child: ColoredBox(
                color: isSelected ? const Color(0x123629B7) : AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.neutralDark,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Aile formundaki metin ve seçim alanlarının aynı görsel dili kullanmasını
/// sağlar. Hata metni seçim alanındaki FormField durumundan buraya aktarılır.
InputDecoration _familyInputDecoration({
  required String label,
  String? hint,
  String? errorText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    filled: true,
    fillColor: AppColors.white,
    labelStyle: const TextStyle(color: AppColors.primarySecondary),
    hintStyle: const TextStyle(
      color: AppColors.neutralPlaceholder,
      fontSize: 13,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    suffixIcon: suffixIcon,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.neutralBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.statusRejected),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.statusRejected, width: 1.4),
    ),
  );
}

/// Diğer seçildiğinde yakınlık alanını aynı konumda yazılabilir tutar.
///
/// Sağdaki ok personelin standart seçeneklere geri dönebilmesini sağlar.
/// Menü de form içinde genişleyerek sonraki alanları aşağı iter.
class _EditableRelationshipField extends StatelessWidget {
  const _EditableRelationshipField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.validator,
    required this.isOptionsOpen,
    required this.onToggleOptions,
    required this.onRelationshipSelected,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FormFieldValidator<String> validator;
  final bool isOptionsOpen;
  final VoidCallback onToggleOptions;
  final ValueChanged<String> onRelationshipSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FamilyFormField(
          fieldKey: fieldKey,
          label: label,
          hint: hint,
          controller: controller,
          focusNode: focusNode,
          validator: validator,
          textCapitalization: TextCapitalization.words,
          bottomPadding: isOptionsOpen ? 0 : 14,
          suffixIcon: IconButton(
            key: const Key('family-member-relationship-menu-button'),
            tooltip: 'Yakınlık seçeneklerini aç',
            onPressed: onToggleOptions,
            icon: AnimatedRotation(
              turns: isOptionsOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.primarySecondary,
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: isOptionsOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 14),
                  child: _FamilyInlineOptionsMenu(
                    menuKey: const Key('family-member-relationship-options'),
                    items: FamilyMemberFormOptions.relationships,
                    selectedValue: FamilyMemberFormOptions.otherRelationship,
                    onSelected: onRelationshipSelected,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _FamilyFormField extends StatelessWidget {
  const _FamilyFormField({
    required this.fieldKey,
    required this.label,
    required this.hint,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.inputFormatters,
    this.focusNode,
    this.suffixIcon,
    this.bottomPadding = 14,
  });

  final Key fieldKey;
  final String label;
  final String hint;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final Widget? suffixIcon;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        validator: validator,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        textInputAction: TextInputAction.next,
        inputFormatters: inputFormatters,
        style: const TextStyle(
          color: AppColors.neutralDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: _familyInputDecoration(
          label: label,
          hint: hint,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
