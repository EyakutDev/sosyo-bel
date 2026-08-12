import 'package:sosyo_bel/core/network/api_client.dart';
import 'package:sosyo_bel/core/network/api_exception.dart';
import 'package:sosyo_bel/features/application/domain/kps_profile.dart';

/// Sosyo-Bel API'deki yetkili KPS profil ucunu çağırır. Mobil uygulama kurumun
/// localhost KPS servisine doğrudan bağlanmaz; erişim ve yetki backend'de kalır.
final class RemoteKpsProfileRepository implements KpsProfileRepository {
  const RemoteKpsProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<KpsProfile> getProfile({
    required String identityNumber,
    required String birthDate,
  }) async {
    final normalizedIdentityNumber = identityNumber.trim();
    final parsedBirthDate = _parseDisplayDate(birthDate);
    if (normalizedIdentityNumber.length != 11 ||
        normalizedIdentityNumber.codeUnits.any(
          (value) => value < 0x30 || value > 0x39,
        )) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'T.C. kimlik numarası 11 rakam olmalıdır.',
      );
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      'api/v1/kps/profile',
      queryParameters: {
        'tcKimlikNo': normalizedIdentityNumber,
        'dogumYil': parsedBirthDate.year,
        'dogumAy': parsedBirthDate.month,
        'dogumGun': parsedBirthDate.day,
      },
    );

    try {
      return _readProfile(
        response.data,
        expectedIdentityNumber: normalizedIdentityNumber,
        expectedBirthDate: parsedBirthDate,
      );
    } on FormatException {
      // Hatalı cevapta ham JSON veya kişisel veri kullanıcı mesajına eklenmez.
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        message: 'KPS profil cevabı geçersiz.',
      );
    }
  }

  static KpsProfile _readProfile(
    Map<String, dynamic>? json, {
    required String expectedIdentityNumber,
    required DateTime expectedBirthDate,
  }) {
    if (json == null) throw const FormatException();

    final identityNumber = _requiredString(json, 'identityNumber');
    final responseBirthDate = DateTime.tryParse(
      _requiredString(json, 'birthDate'),
    );
    if (identityNumber != expectedIdentityNumber ||
        responseBirthDate == null ||
        responseBirthDate.year != expectedBirthDate.year ||
        responseBirthDate.month != expectedBirthDate.month ||
        responseBirthDate.day != expectedBirthDate.day) {
      throw const FormatException();
    }

    return KpsProfile(
      identityNumber: identityNumber,
      firstName: _requiredString(json, 'firstName'),
      lastName: _requiredString(json, 'lastName'),
      fatherName: _optionalString(json, 'fatherName'),
      motherName: _optionalString(json, 'motherName'),
      birthDate: _formatDisplayDate(responseBirthDate),
      birthPlace: _optionalString(json, 'birthPlace'),
      gender: _optionalString(json, 'gender'),
      maritalStatus: _optionalString(json, 'maritalStatus'),
      status: _optionalString(json, 'status'),
      fullAddress: _requiredString(json, 'fullAddress'),
    );
  }

  static DateTime _parseDisplayDate(String value) {
    final match = RegExp(
      r'^(\d{2})[./](\d{2})[./](\d{4})$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Geçerli bir doğum tarihi girilmelidir.',
      );
    }

    final day = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final year = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'Geçerli bir doğum tarihi girilmelidir.',
      );
    }
    return date;
  }

  static String _formatDisplayDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/'
      '${value.year.toString().padLeft(4, '0')}';

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException();
    }
    return value.trim();
  }

  static String? _optionalString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) throw const FormatException();
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
