import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../l10n/app_lang.dart';

/// رسالة دردشة فورية — إيموجي أو نص جاهز
class BgChatMsg {
  final String text;
  final bool emoji;
  final int id;
  BgChatMsg(this.text, {this.emoji = false})
      : id = DateTime.now().microsecondsSinceEpoch;
}

class BgChat {
  BgChat._();

  static const emojis = [
    '😂',
    '😎',
    '🔥',
    '👏',
    '😡',
    '😭',
    '🤯',
    '😏',
    '🎲',
    '👍',
    '❤️',
    '😴',
  ];

  static final phrases = [
    'العب بسرعة! ⏱️'.tr,
    'حظ سعيد 🍀'.tr,
    'ضربة معلم! 👌'.tr,
    'يا لها من رمية 🎲'.tr,
    'ما هذا الحظ؟! 😤'.tr,
    'أحسنت 👏'.tr,
    'لا تستعجل 😏'.tr,
    'مرة ثانية؟ 🔁'.tr,
    'شكراً 🙏'.tr,
    'هههههه 😂'.tr,
  ];

  /// رد البوت على رسالتك
  static BgChatMsg? botReply(BgChatMsg m, math.Random rnd) {
    if (rnd.nextDouble() > 0.6) return null;
    if (m.emoji) {
      const map = {
        '😂': '😂',
        '😎': '😏',
        '🔥': '🔥',
        '👏': '🙏',
        '😡': '😂',
        '😭': '😏',
        '🤯': '😎',
        '😏': '😤',
        '🎲': '🎲',
        '👍': '👍',
        '❤️': '❤️',
        '😴': '😂',
      };
      return BgChatMsg(map[m.text] ?? '😎', emoji: true);
    }
    if (m.text.startsWith('العب بسرعة'.tr)) return BgChatMsg('لا تستعجل 😏'.tr);
    if (m.text.startsWith('حظ سعيد'.tr)) return BgChatMsg('حظ سعيد 🍀'.tr);
    if (m.text.startsWith('ضربة معلم'.tr) || m.text.startsWith('أحسنت'.tr)) {
      return BgChatMsg('شكراً 🙏'.tr);
    }
    if (m.text.startsWith('ما هذا الحظ'.tr))
      return BgChatMsg('😎', emoji: true);
    if (m.text.startsWith('هه'.tr)) return BgChatMsg('😂', emoji: true);
    return BgChatMsg(emojis[rnd.nextInt(emojis.length)], emoji: true);
  }
}

// ══════════════════════════════════════════════════════════════
// لوحة الدردشة — شبكة إيموجي + رسائل جاهزة (زجاجية)
// ══════════════════════════════════════════════════════════════
class BgChatPanel extends StatelessWidget {
  final ValueChanged<BgChatMsg> onSend;
  final VoidCallback onClose;

  const BgChatPanel({super.key, required this.onSend, required this.onClose});

  static const _mint = Color(0xFF3FF5A8);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xF20D1530),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _mint.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 24),
          BoxShadow(
              color: _mint.withValues(alpha: 0.12),
              blurRadius: 30,
              spreadRadius: -6),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('💬 دردشة سريعة'.tr,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close_rounded,
                    color: Colors.white54, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              for (final e in BgChat.emojis)
                _EmojiKey(e, onTap: () => onSend(BgChatMsg(e, emoji: true))),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 110),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in BgChat.phrases)
                    GestureDetector(
                      onTap: () => onSend(BgChatMsg(p)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0x2238BDF8),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x4438BDF8)),
                        ),
                        child: Text(p,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiKey extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  const _EmojiKey(this.emoji, {required this.onTap});

  @override
  State<_EmojiKey> createState() => _EmojiKeyState();
}

class _EmojiKeyState extends State<_EmojiKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 1.35 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x14FFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// فقاعة الرسالة المتحركة — إيموجي: قفزة مرنة + تمايل + طفو + شظايا
// نص: فقاعة كلام تنبثق ثم تتلاشى
// ══════════════════════════════════════════════════════════════
class BgChatBubble extends StatefulWidget {
  final BgChatMsg msg;

  /// اتجاه الذيل/الشظايا: true = الفقاعة على يمين البطاقة
  final bool pointLeft;
  final VoidCallback onDone;

  const BgChatBubble({
    super.key,
    required this.msg,
    required this.onDone,
    this.pointLeft = true,
  });

  @override
  State<BgChatBubble> createState() => _BgChatBubbleState();
}

class _BgChatBubbleState extends State<BgChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2800))
    ..forward().whenComplete(() {
      if (mounted) widget.onDone();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final inT = (t / 0.22).clamp(0.0, 1.0);
          final outT = ((t - 0.82) / 0.18).clamp(0.0, 1.0);
          final pop = Curves.elasticOut.transform(inT);
          final opacity = 1 - outT;
          return widget.msg.emoji
              ? _emoji(t, pop, opacity)
              : _text(pop, opacity);
        },
      ),
    );
  }

  Widget _emoji(double t, double pop, double opacity) {
    final wobble = math.sin(t * math.pi * 10) * 0.18 * (1 - t);
    final float = -t * 26;
    final e = widget.msg.text;
    // حركة مميزة لكل إيموجي
    double extraScale = 1, dx = 0;
    if (e == '❤️' || e == '🔥') {
      extraScale = 1 + 0.12 * math.sin(t * math.pi * 12).abs();
    } else if (e == '😂' || e == '😡') {
      dx = math.sin(t * math.pi * 26) * 3 * (1 - t);
    }
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // شظايا صغيرة تنطلق
            for (int i = 0; i < 7; i++)
              Transform.translate(
                offset: Offset(math.cos(i / 7 * math.pi * 2),
                        math.sin(i / 7 * math.pi * 2)) *
                    (18 + 46 * Curves.easeOut.transform((t * 2).clamp(0, 1))),
                child: Opacity(
                  opacity: (1 - t * 1.8).clamp(0.0, 1.0),
                  child: Text(e, style: const TextStyle(fontSize: 12)),
                ),
              ),
            Container(
              width: 70 * pop,
              height: 70 * pop,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  Colors.white.withValues(alpha: 0.28),
                  Colors.white.withValues(alpha: 0.0),
                ]),
              ),
            ),
            Transform.translate(
              offset: Offset(dx, float),
              child: Transform.rotate(
                angle: wobble,
                child: Transform.scale(
                  scale: pop * extraScale,
                  child: Text(e,
                      style: const TextStyle(fontSize: 52, shadows: [
                        Shadow(color: Colors.black54, blurRadius: 12),
                      ])),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _text(double pop, double opacity) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: 0.5 + 0.5 * pop,
        alignment:
            widget.pointLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFFFFFFFF), Color(0xFFE8EEFF)]),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.pointLeft ? 4 : 16),
              bottomRight: Radius.circular(widget.pointLeft ? 16 : 4),
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4), blurRadius: 12),
            ],
          ),
          child: Text(widget.msg.text,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                  color: Color(0xFF0B1226),
                  fontWeight: FontWeight.w900,
                  fontSize: 13)),
        ),
      ),
    );
  }
}
