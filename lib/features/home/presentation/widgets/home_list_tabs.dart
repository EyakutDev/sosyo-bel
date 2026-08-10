import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Ana ekranda gösterilebilen iki Figma liste durumu.
enum HomeListFilter { pending, completed }

/// Bekleyen ve tamamlanmış listeler arasında geçiş yapan sekme grubu.
class HomeListTabs extends StatelessWidget {
  const HomeListTabs({
    required this.selectedFilter,
    required this.scale,
    required this.onChanged,
    super.key,
  });

  final HomeListFilter selectedFilter;
  final double scale;
  final ValueChanged<HomeListFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _HomeTab(
          label: 'Bekleyen Liste',
          isSelected: selectedFilter == HomeListFilter.pending,
          scale: scale,
          onTap: () => onChanged(HomeListFilter.pending),
        ),
        SizedBox(width: 16 * scale),
        _HomeTab(
          label: 'Tamamlanmış',
          isSelected: selectedFilter == HomeListFilter.completed,
          scale: scale,
          onTap: () => onChanged(HomeListFilter.completed),
        ),
      ],
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.label,
    required this.isSelected,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.primarySurface,
        borderRadius: BorderRadius.circular(15 * scale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15 * scale),
          child: SizedBox(
            width: 155 * scale,
            height: 44 * scale,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.white : AppColors.neutralDark,
                  fontSize: 14 * scale,
                  fontWeight: FontWeight.w500,
                  height: 24 / 14,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
