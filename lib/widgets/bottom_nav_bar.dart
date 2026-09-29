import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../l10n/app_lang.dart';
import '../theme_mode.dart';

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
      accent: L(0xFF34D399),
      accentDeep: L(0xFF0F766E),
    ),
    _NavEntry(
      index: 2,
      icon: Icons.forum_outlined,
      activeIcon: Icons.forum_rounded,
      label: 'الدردشة'.tr,
      accent: L(0xFF38BDF8),
      accentDeep: L(0xFF0C4A6E),
    ),
    _NavEntry(
      index: 1,
      icon: Icons.military_tech_outlined,
      activeIcon: Icons.military_tech_rounded,
      label: 'الإنجازات'.tr,
      accent: L(0xFFFBBF24),
      accentDeep: L(0xFF92400E),
    ),
    _NavEntry(
      index: 0,
      icon: Icons.grid_view_rounded,
      activeIcon: Icons.grid_view_rounded,
      label: 'الرئيسية'.tr,
      accent: L(0xFFF472B6),
      accentDeep: L(0xFF831843),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UiTheme.instance,
      builder: (context, _) {
        final t = PT(UiTheme.instance.isLight);
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
                  child: AnimatedContainer(
                    duration: UiTheme.transition,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: t.navGradient,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: t.navBorder),
                      boxShadow: t.navShadow,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 8),
                      child: Row(
                        children: [
                          for (final entry in _entries)
                            Expanded(child: _buildNavItem(entry, t)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(_NavEntry entry, PT t) {
    final isSelected = currentIndex == entry.index;
    final light = t.light;

    return GestureDetector(
      onTap: () => onIndexChanged(entry.index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.symmetric(horizontal: 3),
        padding: EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: light
                      ? [L(0xFF3BD9B4), L(0xFF14A98A)]
                      : [
                          entry.accent.withValues(alpha: 0.34),
                          entry.accentDeep.withValues(alpha: 0.30),
                        ],
                )
              : null,
          border: Border.all(
            color: isSelected
                ? (light
                    ? L(0xFF21C7A0).withValues(alpha: 0.5)
                    : entry.accent.withValues(alpha: 0.55))
                : Colors.transparent,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (light ? L(0xFF21C7A0) : entry.accent)
                        .withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? L(0xFFFFFFFF).withValues(alpha: light ? 0.22 : 0.14)
                    : t.navIconCircle,
                border: Border.all(
                  color: isSelected
                      ? (light
                          ? L(0xFFFFFFFF).withValues(alpha: 0.55)
                          : entry.accent.withValues(alpha: 0.75))
                      : (light
                          ? L(0xFFE3E9F3)
                          : L(0xFFFFFFFF).withValues(alpha: 0.10)),
                ),
              ),
              child: Icon(
                isSelected ? entry.activeIcon : entry.icon,
                color: isSelected
                    ? (light ? L(0xFFFFFFFF) : entry.accent)
                    : t.navInactive,
                size: isSelected ? 19 : 18,
              ),
            ),
            SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                entry.label,
                maxLines: 1,
                style: TextStyle(
                  color: isSelected ? L(0xFFFFFFFF) : t.navInactive,
                  fontSize: 10.5,
                  height: 1,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 4),
            AnimatedContainer(
              duration: Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 3,
              width: isSelected ? 22 : 0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: light ? L(0xFFFFFFFF) : entry.accent,
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: (light ? L(0xFFFFFFFF) : entry.accent)
                          .withValues(alpha: 0.6),
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
