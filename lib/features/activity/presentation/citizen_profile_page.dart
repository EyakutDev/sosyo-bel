import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/activity/presentation/fixtures/citizen_profile_design_fixture.dart';
import 'package:sosyo_bel/features/activity/presentation/models/citizen_profile_view_data.dart';
import 'package:sosyo_bel/features/activity/presentation/widgets/activity_step_tabs.dart';

/// Figma'daki `Vatandaş Profili` (40:21517) ekranının Flutter karşılığı.
///
/// Ekran yalnızca kendisine verilen sunum modelini gösterir. MERNİS/KPS veya
/// başka bir API yanıtının bu modele dönüştürülmesi ileride veri katmanında
/// yapılacaktır; ekran hiçbir kurumsal servise doğrudan bağlanmaz.
class CitizenProfilePage extends StatelessWidget {
  const CitizenProfilePage({
    required this.onBack,
    required this.onContinue,
    this.data = CitizenProfileDesignFixture.profile,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onContinue;
  final CitizenProfileViewData data;

  static const _referenceWidth = 375.0;
  static const _referenceHeight = 812.0;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final topSafeArea = MediaQuery.paddingOf(context).top;
    final scale = screenSize.width / _referenceWidth;
    final contentHeight = math.max(screenSize.height, _referenceHeight * scale);

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
                  left: -138 * scale,
                  top: 57 * scale,
                  width: 581 * scale,
                  height: 459 * scale,
                  child: Image.asset(
                    AppAssets.activityMap,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Positioned(
                  left: 176 * scale,
                  top: 117 * scale,
                  width: 18 * scale,
                  height: 23 * scale,
                  child: SvgPicture.asset(AppAssets.activityAddressMarker),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 221 * scale,
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
                  top: 227 * scale,
                  width: 36 * scale,
                  height: 4 * scale,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x80BCBCBC),
                      borderRadius: BorderRadius.all(Radius.circular(100)),
                    ),
                  ),
                ),
                Positioned(
                  left: 24 * scale,
                  top: 245 * scale,
                  child: ActivityStepTabs(
                    selectedStep: ActivityStep.profile,
                    scale: scale,
                  ),
                ),
                Positioned(
                  left: 24 * scale,
                  top: 336 * scale,
                  width: 327 * scale,
                  height: 431 * scale,
                  child: _ProfileCard(
                    data: data,
                    scale: scale,
                    onContinue: onContinue,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  // Üst geri düğmesi durum çubuğu ve kamera çentiğinin
                  // dokunma alanıyla çakışmamalıdır.
                  top: topSafeArea,
                  height: 65 * scale,
                  child: ColoredBox(
                    color: AppColors.white,
                    child: Stack(
                      children: [
                        Positioned(
                          // Görselin merkezi değişmeden dokunma alanı 48×48'e
                          // genişletilir. Opaque hit-test, gerçek cihazda okun
                          // çevresindeki şeffaf alanın da güvenilir çalışmasını sağlar.
                          left: 8 * scale,
                          top: 15 * scale,
                          width: 48 * scale,
                          height: 48 * scale,
                          child: Semantics(
                            button: true,
                            label: 'Geri',
                            child: GestureDetector(
                              key: const Key('citizen-profile-back-button'),
                              behavior: HitTestBehavior.opaque,
                              onTap: onBack,
                              child: Center(
                                child: Transform.rotate(
                                  angle: math.pi / 2,
                                  child: SvgPicture.asset(
                                    AppAssets.activityBackArrow,
                                    width: 16 * scale,
                                    height: 9 * scale,
                                  ),
                                ),
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

/// Aktivite akışının mevcut ve sonraki adımlarını Figma'daki kartlarla gösterir.
/// Aile ve hane adımlarının iş kuralları henüz kodlanmadığı için bu aşamada
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.data,
    required this.scale,
    required this.onContinue,
  });

  final CitizenProfileViewData data;
  final double scale;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -30 * scale,
          top: -26 * scale,
          width: 387 * scale,
          height: 492 * scale,
          child: SvgPicture.asset(
            AppAssets.activityProfileCard,
            fit: BoxFit.fill,
          ),
        ),
        Positioned(
          left: 16 * scale,
          right: 16 * scale,
          top: 18 * scale,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Profil Bilgileri',
                  style: TextStyle(
                    color: AppColors.neutralDark,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w600,
                    height: 24 / 16,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Başvuru No',
                    style: TextStyle(
                      color: AppColors.neutralStatusLabel,
                      fontSize: 10 * scale,
                      fontWeight: FontWeight.w500,
                      height: 16 / 10,
                    ),
                  ),
                  Text(
                    data.applicationNumber,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13 * scale,
                      fontWeight: FontWeight.w600,
                      height: 16 / 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        _ProfileRow(
          top: 66,
          label: 'Ad Soyad',
          value: data.fullName,
          scale: scale,
        ),
        _ProfileRow(
          top: 98,
          label: 'Adres',
          value: data.address,
          scale: scale,
          valueHeight: 34,
        ),
        _ProfileRow(
          top: 143,
          label: 'Telefon',
          value: data.phoneNumber,
          scale: scale,
        ),
        _ProfileRow(
          top: 166,
          label: 'T.C. No',
          value: data.identityNumber,
          scale: scale,
        ),
        _ProfileRow(
          top: 189,
          label: 'Doğum Tarihi',
          value: data.birthDate,
          scale: scale,
        ),
        _ProfileDivider(top: 219, scale: scale),
        _ProfileRow(
          top: 234,
          label: 'Medeni Durum',
          value: data.maritalStatus,
          scale: scale,
        ),
        _ProfileRow(
          top: 257,
          label: 'Çocuk Sayısı',
          value: data.childrenCount,
          scale: scale,
        ),
        _ProfileRow(
          top: 280,
          label: 'Engel Durumu',
          value: data.disabilityStatus,
          scale: scale,
        ),
        _ProfileRow(
          top: 303,
          label: 'Çalışma Durumu',
          value: data.employmentStatus,
          scale: scale,
        ),
        _ProfileRow(
          top: 326,
          label: 'Eğitim Durumu',
          value: data.educationStatus,
          scale: scale,
        ),
        _ProfileDivider(top: 350, scale: scale),
        Positioned(
          right: 16 * scale,
          top: 373 * scale,
          width: 143 * scale,
          height: 36 * scale,
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(15 * scale),
            child: InkWell(
              key: const Key('citizen-profile-continue-button'),
              onTap: onContinue,
              borderRadius: BorderRadius.circular(15 * scale),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Devam Et',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w500,
                      height: 24 / 16,
                    ),
                  ),
                  SizedBox(width: 8 * scale),
                  SvgPicture.asset(
                    AppAssets.activityContinueArrow,
                    width: 6 * scale,
                    height: 11 * scale,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.top,
    required this.label,
    required this.value,
    required this.scale,
    this.valueHeight = 18,
  });

  final double top;
  final String label;
  final String value;
  final double scale;
  final double valueHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16 * scale,
      right: 16 * scale,
      top: top * scale,
      height: valueHeight * scale,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.neutralStatusLabel,
              fontSize: 12 * scale,
              fontWeight: FontWeight.w600,
              height: 16 / 12,
            ),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            child: Text(
              value,
              maxLines: valueHeight > 18 ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
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

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider({required this.top, required this.scale});

  final double top;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16 * scale,
      right: 16 * scale,
      top: top * scale,
      height: 1,
      child: SvgPicture.asset(
        AppAssets.activityProfileDivider,
        fit: BoxFit.fill,
      ),
    );
  }
}
