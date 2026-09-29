import 'package:flutter/material.dart';
import '../okey_models.dart';
import 'okey_tile_widget.dart';
import 'game_notice.dart';
import 'package:game_hub/utils/haptics.dart';
import '../../../l10n/app_lang.dart';

class OkeyWinDialog extends StatelessWidget {
  final OkeyPlayer winner;
  final WinType winType;
  final VoidCallback onPlayAgain;
  final VoidCallback? onExit;

  const OkeyWinDialog({
    super.key,
    required this.winner,
    required this.winType,
    required this.onPlayAgain,
    this.onExit,
  });

  static Future<void> show(
    BuildContext context, {
    required OkeyPlayer winner,
    required WinType winType,
    required VoidCallback onPlayAgain,
    VoidCallback? onExit,
  }) {
    return showOkeyLandscapeDialog(
      context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (_) => OkeyWinDialog(
        winner: winner,
        winType: winType,
        onPlayAgain: onPlayAgain,
        onExit: onExit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHuman = winner.isHuman;
    final winTitle = isHuman ? '🎉 مبروك! لقد فزت بالجولة!'.tr : 'انتهت الجولة بفوز {}'.trp([winner.name]);
    final winSub = winType == WinType.discardOkey
        ? 'فوز استثنائي برمي حجر الأوكي! (Okey ile Bitti)'.tr
        : (winType == WinType.sevenPairs
            ? 'فوز بالأزواج السبعة! (7 Çift ile Bitti)'.tr
            : 'فوز نظامي بإكمال المجموعات! (Normal Bitiş)'.tr);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: const Color(0xF8161D2B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isHuman ? const Color(0xFFFFD54F) : const Color(0x4460A5FA),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (isHuman ? const Color(0xFFFFD54F) : const Color(0xFF3B82F6))
                  .withOpacity(0.35),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة الفوز
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isHuman
                      ? [const Color(0xFFFFD54F), const Color(0xFFD97706)]
                      : [const Color(0xFF60A5FA), const Color(0xFF2563EB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                isHuman ? Icons.emoji_events_rounded : Icons.military_tech_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),

            // عنوان الفوز
            Text(
              winTitle,
              style: TextStyle(
                color: isHuman ? const Color(0xFFFFD54F) : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              winSub,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // عرض أحجار اليد الفائزة
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x33000000),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x22FFFFFF), width: 1),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: winner.activeTiles.map((t) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: OkeyTileWidget(
                        tile: t,
                        width: 26,
                        height: 36,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // الأزرار: جولة جديدة + خروج
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // زر الخروج
                if (onExit != null) ...[
                  GestureDetector(
                    onTap: () {
                      AppHaptics.light();
                      Navigator.of(context).pop();
                      onExit!();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.25), width: 1.2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.exit_to_app_rounded,
                              color: Colors.white70, size: 19),
                          SizedBox(width: 7),
                          Text(
                            'خروج'.tr,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                // زر لعب جولة جديدة
                GestureDetector(
                  onTap: () {
                    AppHaptics.heavy();
                    Navigator.of(context).pop();
                    onPlayAgain();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22C55E).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.replay_rounded,
                            color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'جولة جديدة (Play Again)'.tr,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
