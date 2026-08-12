import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/application/domain/application_reference_catalog.dart';
import 'package:sosyo_bel/features/application/presentation/formatters/day_month_year_input_formatter.dart';
import 'package:sosyo_bel/features/application/presentation/formatters/phone_number_input_formatter.dart';
import 'package:sosyo_bel/features/application/presentation/models/application_draft.dart';
import 'package:sosyo_bel/features/application/presentation/widgets/application_form_field.dart';
import 'package:sosyo_bel/features/application/presentation/widgets/application_form_section_header.dart';

/// Vatandaş adına yeni yardım başvurusu başlatılan form ekranı.
///
/// Bu katman yalnızca kullanıcı girdisini toplar ve temel zorunlu alan
/// kontrollerini yapar. MERNİS sorgusu, veri kaydı ve sayfa yönlendirmesi bu
/// ekranın dışında kurulacak entegrasyon katmanlarının sorumluluğundadır.
class NewApplicationPage extends StatefulWidget {
  const NewApplicationPage({
    required this.onContinue,
    required this.referenceCatalog,
    this.initialData,
    super.key,
  });

  /// Form geçerli olduğunda bütün kişi ve talep alanlarını üst akışa taşır.
  final Future<void> Function(NewApplicationFormData) onContinue;
  final ApplicationReferenceCatalog referenceCatalog;

  /// Aktivite adımlarından forma dönüldüğünde daha önce girilen veriyi yükler.
  final NewApplicationFormData? initialData;

  @override
  State<NewApplicationPage> createState() => _NewApplicationPageState();
}

class _NewApplicationPageState extends State<NewApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identityNumberController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _phoneController;
  late final TextEditingController _descriptionController;

  late String _selectedDisabilityStatusCode;
  late String? _selectedHelpTypeCode;
  bool _isHelpTypeOptionsOpen = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final initialData = widget.initialData;

    // Controller'lar yalnızca sayfa kurulurken taslaktan beslenir. Böylece
    // sonraki widget yenilemeleri personelin yazmakta olduğu metni sıfırlamaz.
    _identityNumberController = TextEditingController(
      text: initialData?.identityNumber ?? '',
    );
    _birthDateController = TextEditingController(
      text: initialData?.birthDate ?? '',
    );
    _phoneController = TextEditingController(
      text: initialData?.phoneNumber ?? '',
    );
    _descriptionController = TextEditingController(
      text: initialData?.description ?? '',
    );
    if (widget.referenceCatalog.disabilityStatuses.isEmpty) {
      throw const FormatException('Engel durumu seçenekleri bulunamadı.');
    }
    _selectedDisabilityStatusCode =
        initialData?.disabilityStatusCode ??
        widget.referenceCatalog.disabilityStatuses.first.code;
    _selectedHelpTypeCode = initialData?.helpTypeCode;
  }

  @override
  void dispose() {
    _identityNumberController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (_formKey.currentState?.validate() ?? false) {
      final disabilityStatus = _requiredOption(
        widget.referenceCatalog.disabilityStatuses,
        _selectedDisabilityStatusCode,
      );
      final helpType = _requiredOption(
        widget.referenceCatalog.helpTypes,
        _selectedHelpTypeCode,
      );
      setState(() => _isSubmitting = true);
      try {
        await widget.onContinue(
          NewApplicationFormData(
            identityNumber: _identityNumberController.text,
            birthDate: _birthDateController.text,
            disabilityStatusCode: disabilityStatus.code,
            disabilityStatus: disabilityStatus.label,
            phoneNumber: _phoneController.text,
            helpTypeCode: helpType.code,
            helpType: helpType.label,
            description: _descriptionController.text,
          ),
        );
      } catch (error) {
        _showKpsError(error);
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  void _showKpsError(Object error) {
    if (!mounted) return;
    final message = error is ApiException
        ? error.message
        : 'KPS bilgileri alınamadı. Lütfen tekrar deneyin.';

    // Başarısız sorguda form kapatılmaz ve personelin girdiği alanlar korunur.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const Key('new-application-kps-error-notice'),
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
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.neutralDark),
                ),
              ),
            ],
          ),
        ),
      );
  }

  ApplicationReferenceOption _requiredOption(
    List<ApplicationReferenceOption> options,
    String? code,
  ) {
    return options.firstWhere(
      (option) => option.code == code,
      orElse: () => throw const FormatException(
        'Seçilen form seçeneği artık kullanılamıyor.',
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan zorunludur.';
    }
    return null;
  }

  String? _identityNumberValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }
    if (value!.length != 11) {
      return 'T.C. kimlik numarası 11 rakam olmalıdır.';
    }
    return null;
  }

  String? _birthDateValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) return requiredError;

    final match = RegExp(
      r'^(\d{2})[./](\d{2})[./](\d{4})$',
    ).firstMatch(value!.trim());
    if (match == null) return 'Geçerli bir doğum tarihi girilmelidir.';

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return 'Geçerli bir doğum tarihi girilmelidir.';
    }
    return null;
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
        backgroundColor: AppColors.primarySurface,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          toolbarHeight: 58,
          leadingWidth: 52,
          leading: IconButton(
            key: const Key('new-application-back-button'),
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: AppColors.neutralDark,
            ),
            tooltip: 'Geri',
          ),
          titleSpacing: 0,
          title: const Text(
            'Yeni Başvuru',
            style: TextStyle(
              color: AppColors.neutralDark,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F3629B7),
                        blurRadius: 18,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const ApplicationFormSectionHeader(
                            icon: Icons.person_outline_rounded,
                            title: 'Kişi Bilgileri',
                          ),
                          const SizedBox(height: 20),
                          ApplicationFormField(
                            key: const Key('new-application-tckn-field'),
                            label: 'T.C. Kimlik Numarası',
                            hintText: '11 haneli T.C. kimlik numarası',
                            controller: _identityNumberController,
                            prefixIcon: Icons.badge_outlined,
                            requiredField: true,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            validator: _identityNumberValidator,
                          ),
                          const SizedBox(height: 20),
                          ApplicationFormField(
                            key: const Key('new-application-birth-date-field'),
                            label: 'Doğum Tarihi',
                            hintText: 'GG/AA/YYYY',
                            controller: _birthDateController,
                            prefixIcon: Icons.calendar_today_outlined,
                            requiredField: true,
                            keyboardType: TextInputType.datetime,
                            textInputAction: TextInputAction.next,
                            inputFormatters: const [
                              DayMonthYearInputFormatter(),
                            ],
                            validator: _birthDateValidator,
                          ),
                          const SizedBox(height: 20),
                          _buildDropdown(
                            key: const Key(
                              'new-application-disability-dropdown',
                            ),
                            label: 'Engel Durumu',
                            hintText: 'Seçiniz',
                            prefixIcon: Icons.accessible_rounded,
                            value: _selectedDisabilityStatusCode,
                            items: widget.referenceCatalog.disabilityStatuses,
                            onChanged: (value) {
                              if (value != null) {
                                setState(
                                  () => _selectedDisabilityStatusCode = value,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 66),
                          const ApplicationFormSectionHeader(
                            icon: Icons.description_outlined,
                            title: 'Talep Bilgileri',
                          ),
                          const SizedBox(height: 20),
                          ApplicationFormField(
                            key: const Key('new-application-phone-field'),
                            label: 'Telefon Numarası',
                            hintText: '+90 (5XX)-XXX-XXXX',
                            controller: _phoneController,
                            prefixIcon: Icons.phone_rounded,
                            requiredField: true,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: const [
                              PhoneNumberInputFormatter(),
                            ],
                            validator: _requiredValidator,
                          ),
                          const SizedBox(height: 20),
                          _buildInlineDropdown(
                            key: const Key('new-application-help-dropdown'),
                            controlKey: const Key(
                              'new-application-help-dropdown-control',
                            ),
                            optionsKey: const Key(
                              'new-application-help-dropdown-options',
                            ),
                            label: 'Talep Edilen Yardım Türü',
                            hintText: 'Seçiniz',
                            prefixIcon: Icons.volunteer_activism_outlined,
                            value: _selectedHelpTypeCode,
                            items: widget.referenceCatalog.helpTypes,
                            isOpen: _isHelpTypeOptionsOpen,
                            onToggle: () {
                              FocusScope.of(context).unfocus();
                              setState(
                                () => _isHelpTypeOptionsOpen =
                                    !_isHelpTypeOptionsOpen,
                              );
                            },
                            onChanged: (value) {
                              setState(() {
                                _selectedHelpTypeCode = value;
                                _isHelpTypeOptionsOpen = false;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          ApplicationFormField(
                            key: const Key('new-application-description-field'),
                            label: 'Talep Açıklaması',
                            hintText:
                                'Talebinizi ve gerekçelerinizi buraya '
                                'yazabilirsiniz...',
                            controller: _descriptionController,
                            prefixIcon: Icons.notes_rounded,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              key: const Key('new-application-continue-button'),
                              onPressed: _isSubmitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                elevation: 0,
                                backgroundColor: AppColors.primary,
                                disabledBackgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                disabledForegroundColor: AppColors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox.square(
                                      key: Key(
                                        'new-application-kps-loading-indicator',
                                      ),
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Devam Et',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required Key key,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    required String? value,
    required List<ApplicationReferenceOption> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ApplicationFormFieldLabel(label: label, requiredField: true),
        const SizedBox(height: 8),
        FormField<String>(
          initialValue: value,
          validator: (selectedValue) {
            if (selectedValue == null || selectedValue.isEmpty) {
              return 'Bu alan zorunludur.';
            }
            return null;
          },
          builder: (field) {
            return InputDecorator(
              isEmpty: field.value == null,
              decoration:
                  applicationFormInputDecoration(
                    hintText: hintText,
                    prefixIcon: prefixIcon,
                  ).copyWith(
                    // İpucu DropdownButton içinde çizildiği için iki kez
                    // görünmesini engelleriz.
                    hintText: null,
                    errorText: field.errorText,
                  ),
              child: LayoutBuilder(
                builder: (context, menuConstraints) {
                  return DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: field.value,
                      isExpanded: true,
                      isDense: true,
                      menuWidth: menuConstraints.maxWidth,
                      menuMaxHeight: 320,
                      itemHeight: 48,
                      elevation: 4,
                      dropdownColor: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.neutralDark,
                      ),
                      hint: Text(
                        hintText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.neutralSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      style: const TextStyle(
                        color: AppColors.neutralDark,
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      items: items
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.code,
                              child: SizedBox(
                                width: double.infinity,
                                child: Text(
                                  item.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (selectedValue) {
                        field.didChange(selectedValue);
                        onChanged(selectedValue);
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  /// Yardım türü seçeneklerini alanın altında, form akışının içinde gösterir.
  ///
  /// Liste normal yerleşime katıldığı için açıklama alanının üzerine binmez;
  /// açıldığında sonraki alanları aşağı iter ve giriş alanıyla aynı genişliği
  /// kullanır.
  Widget _buildInlineDropdown({
    required Key key,
    required Key controlKey,
    required Key optionsKey,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    required String? value,
    required List<ApplicationReferenceOption> items,
    required bool isOpen,
    required VoidCallback onToggle,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApplicationFormFieldLabel(label: label, requiredField: true),
        const SizedBox(height: 8),
        FormField<String>(
          initialValue: value,
          validator: (selectedValue) {
            if (selectedValue == null || selectedValue.isEmpty) {
              return 'Bu alan zorunludur.';
            }
            return null;
          },
          builder: (field) {
            final selectedLabel = items
                .where((item) => item.code == field.value)
                .map((item) => item.label)
                .firstOrNull;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: controlKey,
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(15),
                    child: InputDecorator(
                      isEmpty: field.value == null,
                      decoration: applicationFormInputDecoration(
                        hintText: hintText,
                        prefixIcon: prefixIcon,
                      ).copyWith(hintText: null, errorText: field.errorText),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedLabel ?? hintText,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selectedLabel == null
                                    ? AppColors.neutralSecondary
                                    : AppColors.neutralDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          AnimatedRotation(
                            turns: isOpen ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.neutralDark,
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
                          child: _ApplicationInlineOptionsMenu(
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
      ],
    );
  }
}

/// Yeni başvuru formundaki satır içi seçenek listesinin ortak görünümü.
class _ApplicationInlineOptionsMenu extends StatelessWidget {
  const _ApplicationInlineOptionsMenu({
    required this.menuKey,
    required this.items,
    required this.selectedValue,
    required this.onSelected,
  });

  final Key menuKey;
  final List<ApplicationReferenceOption> items;
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
            final isSelected = item.code == selectedValue;
            return InkWell(
              onTap: () => onSelected(item.code),
              child: ColoredBox(
                color: isSelected ? const Color(0x123629B7) : AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
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
