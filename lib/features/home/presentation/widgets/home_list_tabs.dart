import 'package:flutter/material.dart';
import 'package:sosyo_bel/core/theme/app_colors.dart';

/// Ana ekranda gösterilebilen iki Figma liste durumu.
enum HomeListFilter { pending, completed }

/// Bekleyen ve tamamlanmış listeler arasında geçiş yapan sekme grubu.
class HomeListTabs extends StatefulWidget {
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
  State<HomeListTabs> createState() => _HomeListTabsState();
}

class _HomeListTabsState extends State<HomeListTabs> {
  static const _settleDuration = Duration(milliseconds: 180);
  static const _flingVelocity = 350.0;

  double? _dragProgress;

  double get _selectedProgress =>
      widget.selectedFilter == HomeListFilter.pending ? 0 : 1;

  @override
  void didUpdateWidget(covariant HomeListTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFilter != widget.selectedFilter) {
      _dragProgress = null;
    }
  }

  void _startDrag(DragStartDetails details) {
    setState(() => _dragProgress = _selectedProgress);
  }

  void _updateDrag(DragUpdateDetails details) {
    final availableWidth = context.size?.width ?? 0;
    final indicatorTravel = (availableWidth - (8 * widget.scale)) / 2;
    if (indicatorTravel <= 0) return;

    setState(() {
      _dragProgress =
          ((_dragProgress ?? _selectedProgress) +
                  (details.delta.dx / indicatorTravel))
              .clamp(0.0, 1.0)
              .toDouble();
    });
  }

  void _endDrag(DragEndDetails details) {
    final progress = _dragProgress ?? _selectedProgress;
    final velocity = details.primaryVelocity ?? 0;
    final target = velocity.abs() >= _flingVelocity
        ? (velocity > 0 ? HomeListFilter.completed : HomeListFilter.pending)
        : (progress >= 0.5 ? HomeListFilter.completed : HomeListFilter.pending);

    if (target != widget.selectedFilter) {
      widget.onChanged(target);
    }
    setState(() => _dragProgress = null);
  }

  void _cancelDrag() {
    setState(() => _dragProgress = null);
  }

  @override
  Widget build(BuildContext context) {
    final isPendingSelected = widget.selectedFilter == HomeListFilter.pending;
    final progress = (_dragProgress ?? _selectedProgress)
        .clamp(0.0, 1.0)
        .toDouble();
    final transitionDuration = _dragProgress == null
        ? _settleDuration
        : Duration.zero;
    final pendingTextColor = Color.lerp(
      AppColors.white,
      AppColors.neutralDark,
      progress,
    )!;
    final completedTextColor = Color.lerp(
      AppColors.neutralDark,
      AppColors.white,
      progress,
    )!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _startDrag,
      onHorizontalDragUpdate: _updateDrag,
      onHorizontalDragEnd: _endDrag,
      onHorizontalDragCancel: _cancelDrag,
      child: Material(
        key: const Key('home-list-tabs'),
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(16 * widget.scale),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(4 * widget.scale),
          child: SizedBox(
            height: 44 * widget.scale,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    AnimatedAlign(
                      alignment: Alignment((progress * 2) - 1, 0),
                      duration: transitionDuration,
                      curve: Curves.easeOutCubic,
                      child: SizedBox(
                        key: const Key('home-list-tab-indicator'),
                        width: constraints.maxWidth / 2,
                        height: constraints.maxHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(
                              12 * widget.scale,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _HomeTab(
                            label: 'Bekleyen',
                            isSelected: isPendingSelected,
                            textColor: pendingTextColor,
                            transitionDuration: transitionDuration,
                            scale: widget.scale,
                            onTap: () =>
                                widget.onChanged(HomeListFilter.pending),
                          ),
                        ),
                        Expanded(
                          child: _HomeTab(
                            label: 'Tamamlanan',
                            isSelected: !isPendingSelected,
                            textColor: completedTextColor,
                            transitionDuration: transitionDuration,
                            scale: widget.scale,
                            onTap: () =>
                                widget.onChanged(HomeListFilter.completed),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.label,
    required this.isSelected,
    required this.textColor,
    required this.transitionDuration,
    required this.scale,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color textColor;
  final Duration transitionDuration;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12 * scale),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: transitionDuration,
            curve: Curves.easeOutCubic,
            style: TextStyle(
              color: textColor,
              fontSize: 15 * scale,
              fontWeight: FontWeight.w500,
              height: 24 / 15,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
