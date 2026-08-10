import 'package:flutter/services.dart';

/// Rakam olarak girilen doğum tarihini yazım sırasında GG/AA/YYYY biçimine
/// dönüştürür.
///
/// Örneğin 03112002 girişi 03/11/2002, ilk iki rakam olan 03 ise
/// doğrudan 03/ olur. Sunucuya gönderilmeden önce gerçek takvim tarihi
/// doğrulaması ayrıca form doğrulayıcısı veya backend katmanında yapılmalıdır.
final class DayMonthYearInputFormatter extends TextInputFormatter {
  const DayMonthYearInputFormatter();

  static const _maximumDigitCount = 8;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > _maximumDigitCount) {
      digits = digits.substring(0, _maximumDigitCount);
    }

    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');
    final removedOnlyAutomaticSeparator =
        newValue.text.length < oldValue.text.length &&
        oldDigits == digits &&
        oldValue.text.endsWith('/');

    // Otomatik eklenen / silinmek istendiğinde bir önceki rakamı da geri
    // alırız; aksi hâlde biçimlendirici aynı / işaretini tekrar ekler ve
    // kullanıcı alanı geri silemez.
    if (removedOnlyAutomaticSeparator && digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    final formatted = _formatDigits(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _formatDigits(String digits) {
    if (digits.isEmpty) return '';

    final buffer = StringBuffer();
    final dayLength = digits.length < 2 ? digits.length : 2;
    buffer.write(digits.substring(0, dayLength));
    if (digits.length >= 2) buffer.write('/');

    if (digits.length > 2) {
      final monthEnd = digits.length < 4 ? digits.length : 4;
      buffer.write(digits.substring(2, monthEnd));
      if (digits.length >= 4) buffer.write('/');
    }

    if (digits.length > 4) {
      buffer.write(digits.substring(4));
    }
    return buffer.toString();
  }
}
