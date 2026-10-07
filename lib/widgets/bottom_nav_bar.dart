import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_lang.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  static List<_NavEntry> _entries = [
    _NavEntry(
      index: 3,
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'الملف الشخصي'.tr,
      accent: Color(0xFF34D399),
      accentDeep: Color(0xFF0F766E),
    ),
    _NavEntry(
      index: 2,
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: 'الدردشة'.tr,
      accent: Color(0xFF38BDF8),
      accentDeep: Color(0xFF0C4A6E),
    ),
    _NavEntry(
      index: 1,
      icon: Icons.military_tech_outlined,
      activeIcon: Icons.military_tech_rounded,
      label: 'الإنجازات'.tr,
      accent: Color(0xFFFBBF24),
      accentDeep: Color(0xFF92400E),
    ),
    _NavEntry(
      index: 0,
      icon: Icons.grid_view_rounded,
      activeIcon: Icons.grid_view_rounded,
      label: 'الرئيسية'.tr,
      accent: Color(0xFFF472B6),
      accentDeep: Color(0xFF831843),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      const Color(0xFF0B1220).withValues(alpha: 0.66),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.42),
                      blurRadius: 26,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                  child: Row(
                    children: [
                      for (final entry in _entries)
                        Expanded(child: _buildNavItem(entry)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavEntry entry) {
    final isSelected = currentIndex == entry.index;
    // التحديد يتحرك بنعومة، أما إلغاؤه فلحظي — فلا يبقى لون الزر السابق
    // ظاهراً لوهلة بعد الانتقال لزر آخر
    final dur = isSelected ? const Duration(milliseconds: 220) : Duration.zero;

    return GestureDetector(
      onTap: () => onIndexChanged(entry.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: dur,
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    entry.accent.withValues(alpha: 0.34),
                    entry.accentDeep.withValues(alpha: 0.30),
                  ],
                )
              : null,
          border: Border.all(
            color: isSelected
                ? entry.accent.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: entry.accent.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: dur,
              curve: Curves.easeOutCubic,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.05),
                border: Border.all(
                  color: isSelected
                      ? entry.accent.withValues(alpha: 0.75)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Icon(
                isSelected ? entry.activeIcon : entry.icon,
                color: isSelected ? entry.accent : const Color(0xFF94A3B8),
                size: isSelected ? 19 : 18,
              ),
            ),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                entry.label,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: dur,
              curve: Curves.easeOutCubic,
              height: 3,
              width: isSelected ? 22 : 0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: entry.accent,
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: entry.accent.withValues(alpha: 0.6),
                      blurRadius: 8,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavEntry {
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color accent;
  final Color accentDeep;

  const _NavEntry({
    required this.index,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.accent,
    required this.accentDeep,
  });
}
