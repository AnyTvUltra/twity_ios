import 'package:flutter/material.dart';
import 'package:game_hub/utils/haptics.dart';
import '../utils/okey_audio.dart';
import 'game_notice.dart';
import '../../../l10n/app_lang.dart';

class OkeyChatDialog extends StatefulWidget {
  /// معاودة اختيارية عند الإرسال — الأونلاين يمرّرها لبثّ الرسالة
  /// على وثيقة الغرفة بدل الفقاعة المحلية المباشرة
  final void Function(String msg)? onSend;

  const OkeyChatDialog({super.key, this.onSend});

  static Future<void> show(BuildContext context,
      {void Function(String msg)? onSend}) {
    return showOkeyLandscapeDialog(
      context,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (_) => OkeyChatDialog(onSend: onSend),
    );
  }

  @override
  State<OkeyChatDialog> createState() => _OkeyChatDialogState();
}

class _OkeyChatDialogState extends State<OkeyChatDialog> {
  final TextEditingController _textController = TextEditingController();

  final List<Map<String, String>> _quickMessages = [
    {'en': 'Good luck!', 'ar': 'حظاً موفقاً! 🍀'.tr},
    {'en': 'Nice!', 'ar': 'حركة رائعة! 🔥'.tr},
    {'en': 'Well played!', 'ar': 'لعبة ممتازة! 👏'.tr},
    {'en': 'Thank you!', 'ar': 'شكراً لك! 😊'.tr},
    {'en': 'Good game!', 'ar': 'لعبة ممتعة! 🏆'.tr},
    {'en': 'Hurry up!', 'ar': 'أسرع دورك! ⏳'.tr},
  ];

  void _send(String msg) {
    AppHaptics.selection();
    OkeyAudio.playButtonClick();
    Navigator.of(context).pop();
    if (widget.onSend != null) {
      // أونلاين: الشاشة تعرض الفقاعة محلياً وتبثّ الرسالة للغرفة
      widget.onSend!(msg);
      return;
    }
    // الرسالة وحدها في فقاعة فوق استكانة المرسل — بدون كلمة "أرسلت"
    GameBubble.show(context, msg, playerIndex: 0);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          color: const Color(0xF2161C28),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x334ADE80), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.7),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat_bubble_rounded,
                        color: Color(0xFF4ADE80), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'المحادثة السريعة (Chat)'.tr,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0x33FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // الرسائل الجاهزة
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickMessages.map((msg) {
                return GestureDetector(
                  onTap: () => _send(msg['ar']!),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0x3322C55E),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0x444ADE80), width: 1),
                    ),
                    child: Text(
                      msg['ar']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // حقل كتابة مخصص
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0x40000000),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0x33FFFFFF), width: 0.8),
                    ),
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالة...'.tr,
                        hintStyle:
                            TextStyle(color: Colors.white38, fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 9),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) _send(val.trim());
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    if (_textController.text.trim().isNotEmpty) {
                      _send(_textController.text.trim());
                    }
                  },
                  child: Container(
                    height: 38,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
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
