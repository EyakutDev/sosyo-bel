import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';
import 'package:sosyo_bel/features/home/presentation/models/application_card_view_data.dart';

/// Figma'daki 327×108 başvuru özet kartı.
class ApplicationSummaryCard extends StatelessWidget {
  const ApplicationSummaryCard({
    required this.data,
    required this.scale,
    this.onTap,
    super.key,
  });

  final ApplicationCardViewData data;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final addressLine2 = data.addressLine2;
    final addressText = addressLine2 == null || addressLine2.isEmpty
        ? data.addressLine1
        : '${data.addressLine1}\n$addressLine2';
    final statusLabel = data.statusLabel;

    return SizedBox(
      height: 108 * scale,
      child: Semantics(
        button: onTap != null,
        enabled: onTap != null,
        label: '${data.applicationNumber} başvurusunu aç',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(15 * scale),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x123629B7),
                  offset: Offset(0, 4),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 16 * scale,
                  top: 12 * scale,
                  child: Text(
                    data.applicationNumber,
                    style: TextStyle(
                      color: AppColors.neutralDark,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w600,
                      height: 24 / 16,
                    ),
                  ),
                ),
                Positioned(
                  left: 120 * scale,
                  right: 16 * scale,
                  top: 12 * scale,
                  child: Text(
                    data.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.neutralDark,
                      fontSize: 15 * scale,
                      fontWeight: FontWeight.w600,
                      height: 24 / 15,
                    ),
                  ),
                ),
                Positioned(
                  left: 16 * scale,
                  top: 52 * scale,
                  child: Text(
                    data.date,
                    style: TextStyle(
                      color: AppColors.neutralSecondary,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w600,
                      height: 16 / 12,
                    ),
                  ),
                ),
                Positioned(
                  right: 16 * scale,
                  top: 52 * scale,
                  width: 160 * scale,
                  child: Text(
                    addressText,
                    maxLines: 2,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w500,
                      height: 16 / 12,
                    ),
                  ),
                ),
                Positioned(
                  left: 16 * scale,
                  top: 74 * scale,
                  child: Row(
                    children: [
                      Text(
                        'Durum',
                        style: TextStyle(
                          color: AppColors.neutralStatusLabel,
                          fontSize: 12 * scale,
                          fontWeight: FontWeight.w500,
                          height: 16 / 12,
                        ),
                      ),
                      if (statusLabel != null && statusLabel.isNotEmpty) ...[
                        SizedBox(width: 5 * scale),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: data.statusColor,
                            fontSize: 12 * scale,
                            fontWeight: FontWeight.w600,
                            height: 16 / 12,
                          ),
                        ),
                      ],
                    ],
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
