import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Yeni başvuru formundaki etiket ve giriş alanı ikilisini standartlaştırır.
class ApplicationFormField extends StatelessWidget {
  const ApplicationFormField({
    required this.label,
    required this.hintText,
    required this.controller,
    required this.prefixIcon,
    this.requiredField = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLines = 1,
    this.validator,
    super.key,
  });

  final String label;
  final String hintText;
  final TextEditingController controller;
  final IconData prefixIcon;
  final bool requiredField;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label: label, requiredField: requiredField),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: maxLines,
          autocorrect: maxLines > 1,
          cursorColor: AppColors.primary,
          style: const TextStyle(
            color: AppColors.neutralDark,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          decoration: applicationFormInputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            alignIconToTop: maxLines > 1,
          ),
          validator: validator,
        ),
      ],
    );
  }
}

/// Açılır alanların da metin alanlarıyla aynı kenarlık ve boşlukları
/// kullanabilmesi için ortak dekorasyon tek noktadan üretilir.
InputDecoration applicationFormInputDecoration({
  required String hintText,
  required IconData prefixIcon,
  bool alignIconToTop = false,
}) {
  const borderSide = BorderSide(color: AppColors.neutralBorder, width: 1);
  const borderRadius = BorderRadius.all(Radius.circular(15));

  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: AppColors.neutralSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    ),
    filled: true,
    fillColor: AppColors.white,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    prefixIcon: Padding(
      padding: EdgeInsets.only(top: alignIconToTop ? 11 : 0),
      child: Icon(prefixIcon, size: 19, color: const Color(0xFFA7A7B5)),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
    enabledBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: borderSide,
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.primary, width: 1),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.statusRejected, width: 1),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: AppColors.statusRejected, width: 1),
    ),
    errorStyle: const TextStyle(
      color: AppColors.statusRejected,
      fontSize: 11,
      height: 1.2,
    ),
  );
}

/// Zorunlu işaretini alan adından ayrı renklendirir.
class ApplicationFormFieldLabel extends StatelessWidget {
  const ApplicationFormFieldLabel({
    required this.label,
    this.requiredField = false,
    super.key,
  });

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return _FieldLabel(label: label, requiredField: requiredField);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, required this.requiredField});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: label,
        children: requiredField
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.statusRejected),
                ),
              ]
            : const [],
      ),
      style: const TextStyle(
        color: AppColors.neutralDark,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }
}
