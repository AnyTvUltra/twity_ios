import 'package:flutter/material.dart';

import '../l10n/app_lang.dart';
import '../services/game_settings_service.dart';
import '../theme_mode.dart';

/// شريط إعلان الإدارة — يظهر في أعلى الرئيسية عندما ينشر المدير
/// رسالة من لوحة الأدمن (config/game_settings → announcement)
class AnnouncementBanner extends StatelessWidget {
  const AnnouncementBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GameSettingsService(),
      builder: (context, _) {
        final text = GameSettingsService().announcement.trim();
        if (text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 0),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  L(0xFF7C3AED).withOpacity(0.22),
                  L(0xFF2563EB).withOpacity(0.22),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: L(0xFF8B5CF6).withOpacity(0.45)),
            ),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, color: L(0xFFC4B5FD), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إعلان الإدارة'.tr,
                          style: TextStyle(
                              color: L(0xFFC4B5FD),
                              fontSize: 10,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(text,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
