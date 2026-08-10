import 'package:flutter/services.dart';

/// Türkiye cep telefonu numarasını yazım sırasında (5XX)-XXX-XXXX biçimine
/// dönüştürür.
///
/// Kullanıcı yalnızca 10 haneli numarayı yazabilir; baştaki 0 veya yapıştırılan
/// +90 ülke kodu ayıklanır. Ülke kodu arayüzdeki ipucu metninde gösterilir.
final class PhoneNumberInputFormatter extends TextInputFormatter {
  const PhoneNumberInputFormatter();

  static const _maximumDigitCount = 10;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = _nationalDigits(newValue.text);
    final oldDigits = _nationalDigits(oldValue.text);

    // Otomatik eklenen parantez veya tire silinmek istendiğinde önceki rakamı
    // da kaldırırız; aksi hâlde biçimlendirici aynı işareti tekrar ekler.
    final removedOnlyFormattingCharacter =
        newValue.text.length < oldValue.text.length &&
        oldDigits == digits &&
        digits.isNotEmpty;
    if (removedOnlyFormattingCharacter) {
      digits = digits.substring(0, digits.length - 1);
    }

    final formatted = _formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _nationalDigits(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    final includesCountryCode =
        value.trimLeft().startsWith('+90') ||
        (digits.startsWith('90') && digits.length > _maximumDigitCount);

    if (includesCountryCode && digits.startsWith('90')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > _maximumDigitCount) {
      digits = digits.substring(0, _maximumDigitCount);
    }
    return digits;
  }

  String _formatDigits(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer('(');
    final operatorEnd = digits.length < 3 ? digits.length : 3;
    buffer.write(digits.substring(0, operatorEnd));
    if (digits.length >= 3) buffer.write(')-');

    if (digits.length > 3) {
      final firstGroupEnd = digits.length < 6 ? digits.length : 6;
      buffer.write(digits.substring(3, firstGroupEnd));
      if (digits.length >= 6) buffer.write('-');
    }

    if (digits.length > 6) {
      buffer.write(digits.substring(6));
    }
    return buffer.toString();
  }
}
