import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sosyo_bel/core/constants/app_assets.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Aktivite akışındaki üç ana adım.
enum ActivityStep { profile, family, household }

/// Profil, aile ve hane adımlarını Figma'daki üç kart halinde gösterir.
///
/// Bu bileşen yalnızca mevcut adımı belirtir; adımlar arasındaki navigasyon
/// kararları sayfaların dışında, uygulama akışında tutulur.
class ActivityStepTabs extends StatelessWidget {
  const ActivityStepTabs({
    required this.selectedStep,
    required this.scale,
    super.key,
  });

  final ActivityStep selectedStep;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 321 * scale,
      height: 68 * scale,
      child: Row(
        children: [
          _ActivityStepTab(
            label: 'Profil Bilgileri',
            iconAsset: AppAssets.activityProfileIcon,
            isSelected: selectedStep == ActivityStep.profile,
            scale: scale,
          ),
          SizedBox(width: 12 * scale),
          _ActivityStepTab(
            label: 'Aile Bilgileri',
            iconAsset: AppAssets.activityFamilyIcon,
            isSelected: selectedStep == ActivityStep.family,
            isFamily: true,
            scale: scale,
          ),
          SizedBox(width: 12 * scale),
          _ActivityStepTab(
            label: 'Hane Durumu',
            iconAsset: AppAssets.activityHomeIcon,
            isSelected: selectedStep == ActivityStep.household,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class _ActivityStepTab extends StatelessWidget {
  const _ActivityStepTab({
    required this.label,
    required this.iconAsset,
    required this.isSelected,
    required this.scale,
    this.isFamily = false,
  });

  final String label;
  final String iconAsset;
  final bool isSelected;
  final double scale;
  final bool isFamily;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      label: label,
      child: Container(
        width: 99 * scale,
        height: 68 * scale,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.neutralDisabled,
          borderRadius: BorderRadius.circular(15 * scale),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              offset: Offset(0, 5),
              blurRadius: 30,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 13 * scale,
              top: 7 * scale,
              width: 43 * scale,
              height: 24 * scale,
              child: isFamily
                  ? Stack(
                      children: [
                        _familyPerson(left: 0, top: 12),
                        _familyPerson(left: 12, top: 7),
                        _familyPerson(left: 24, top: 12),
                      ],
                    )
                  : Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 21 * scale,
                        height: 21 * scale,
                        child: SvgPicture.asset(iconAsset, fit: BoxFit.contain),
                      ),
                    ),
            ),
            Positioned(
              left: 13 * scale,
              top: 35 * scale,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w500,
                  height: 16 / 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _familyPerson({required double left, required double top}) {
    return Positioned(
      left: left * scale,
      top: top * scale,
      width: 13 * scale,
      height: 12 * scale,
      child: SvgPicture.asset(iconAsset, fit: BoxFit.fill),
    );
  }
}
