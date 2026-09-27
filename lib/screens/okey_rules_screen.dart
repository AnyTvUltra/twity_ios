import 'dart:ui';
import 'package:flutter/material.dart';
import '../games/okey/okey_rules.dart';
import '../utils/haptics.dart';
import 'okey_lobby_screen.dart';

/// شاشة اختيار قانون الكونكان — تظهر عند الضغط على بطاقة اللعبة
class OkeyRulesScreen extends StatefulWidget {
  const OkeyRulesScreen({super.key});

  @override
  State<OkeyRulesScreen> createState() => _OkeyRulesScreenState();
}

class _OkeyRulesScreenState extends State<OkeyRulesScreen> {
  OkeyRulesVariant _selected = OkeyRulesVariant.turkish;

  static const _bgTop = Color(0xFF0A0F24);
  static const _bgMid = Color(0xFF070B18);
  static const _bgBot = Color(0xFF04060F);
  static const _neonBlue = Color(0xFF3B82F6);
  static const _cyan = Color(0xFF38BDF8);
  static const _gold = Color(0xFFFFD54F);
  static const _textWhite = Color(0xFFF1F5FF);
  static const _textDim = Color(0xFF8EA3C8);

  static const _variants = [
    OkeyRules.sulaymaniyah,
    OkeyRules.erbil,
    OkeyRules.turkish,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBot,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _RulesBackdrop(),
          SafeArea(
            child: Column(
              children: [
                // الهيدر
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      _glassIcon(Icons.arrow_back_ios_new_rounded,
                          () => Navigator.of(context).pop()),
                      const Expanded(
                        child: Text(
                          'كونكان — اختر القانون 🀄',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 34),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      children: [
                        // وصف
                        const Text(
                          'لكل مدينة قانونها الخاص في الكونكان — اختر القانون الذي تريد اللعب به، أو اضغط "؟" لقراءة شرحه الكامل',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _textDim, fontSize: 11.5, height: 1.5),
                        ),
                        const SizedBox(height: 18),

                        ..._variants.map(_buildVariantCard),

                        const SizedBox(height: 8),
                        _buildContinueButton(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x2E16204A),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0x26FFFFFF), width: 1),
            ),
            child: Icon(icon, color: _textDim, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantCard(OkeyRules rules) {
    final isSelected = _selected == rules.variant;
    const accent = _neonBlue;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        setState(() => _selected = rules.variant);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isSelected
                      ? [
                          accent.withOpacity(0.5),
                          const Color(0xFF14286B).withOpacity(0.85),
                        ]
                      : [
                          const Color(0x2E141C3C),
                          const Color(0x1E0C1230),
                        ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color:
                      isSelected ? accent : const Color(0x2EFFFFFF),
                  width: isSelected ? 1.8 : 1.0,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                        color: accent.withOpacity(0.35),
                        blurRadius: 22,
                        spreadRadius: -2),
                ],
              ),
              child: Row(
                children: [
                  // أيقونة القانون
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          accent.withOpacity(isSelected ? 0.5 : 0.25),
                          const Color(0xFF0A1230),
                        ],
                      ),
                      border: Border.all(
                        color: accent.withOpacity(isSelected ? 0.9 : 0.4),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                            color: accent.withOpacity(isSelected ? 0.4 : 0.2),
                            blurRadius: 14),
                      ],
                    ),
                    child: Center(
                        child: Text(rules.icon,
                            style: const TextStyle(fontSize: 24))),
                  ),
                  const SizedBox(width: 14),

                  // الاسم + ملخص القانون
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rules.name,
                          style: const TextStyle(
                              color: _textWhite,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rules.subtitle,
                          style: const TextStyle(
                              color: _textDim,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _miniTag('افتتاح ${rules.openingPoints}', _gold),
                            const SizedBox(width: 6),
                            _miniTag(
                                rules.allowSevenPairs
                                    ? 'أزواج ✓'
                                    : 'بدون أزواج',
                                rules.allowSevenPairs ? _cyan : _textDim),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // زر "؟" لشرح القانون + مؤشر الاختيار
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showRulesInfo(rules),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _gold.withOpacity(0.12),
                            border: Border.all(
                                color: _gold.withOpacity(0.6), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                  color: _gold.withOpacity(0.25),
                                  blurRadius: 8),
                            ],
                          ),
                          child: const Center(
                            child: Text('؟',
                                style: TextStyle(
                                    color: _gold,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? accent
                                : const Color(0x55FFFFFF),
                            width: 2,
                          ),
                          color: isSelected ? accent : Colors.transparent,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: accent.withOpacity(0.6),
                                      blurRadius: 8)
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                color: Colors.white, size: 12)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35), width: 0.8),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildContinueButton() {
    final rules = OkeyRules.of(_selected);
    return GestureDetector(
      onTap: () {
        AppHaptics.medium();
        Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => OkeyLobbyScreen(rules: rules)),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFE082),
                  _gold,
                  Color(0xFFE8A820),
                  Color(0xFFB8860B),
                ],
                stops: [0.0, 0.35, 0.75, 1.0],
              ),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: const Color(0xFFFFE9A8), width: 1.4),
              boxShadow: [
                BoxShadow(
                    color: _gold.withOpacity(0.4),
                    blurRadius: 22,
                    spreadRadius: -2),
                BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  left: 24,
                  right: 24,
                  height: 13,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(rules.icon, style: const TextStyle(fontSize: 19)),
                    const SizedBox(width: 9),
                    Text(
                      'العب بـ${rules.name}',
                      style: const TextStyle(
                          color: Color(0xFF1B0B30),
                          fontWeight: FontWeight.w900,
                          fontSize: 16),
                    ),
                    const SizedBox(width: 9),
                    const Icon(Icons.arrow_back_rounded,
                        color: Color(0xFF1B0B30), size: 22),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══ نافذة شرح القانون الكامل ═══
  void _showRulesInfo(OkeyRules rules) {
    AppHaptics.selection();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xF2152150), Color(0xF20A0F24)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0x44FFFFFF), width: 1.1),
                boxShadow: [
                  BoxShadow(
                      color: _neonBlue.withOpacity(0.2), blurRadius: 30),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // رأس النافذة
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                    child: Row(
                      children: [
                        Text(rules.icon, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rules.name,
                                  style: const TextStyle(
                                      color: _textWhite,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                              Text(rules.subtitle,
                                  style: const TextStyle(
                                      color: _cyan, fontSize: 11)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: const Icon(Icons.close_rounded,
                              color: _textDim, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: const Color(0x22FFFFFF)),
                  // الشرح
                  Flexible(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                      child: Text(
                        rules.fullDescription,
                        style: const TextStyle(
                            color: Color(0xFFD5DEEF),
                            fontSize: 12.5,
                            height: 1.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulesBackdrop extends StatelessWidget {
  const _RulesBackdrop();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _OkeyRulesScreenState._bgTop,
            _OkeyRulesScreenState._bgMid,
            _OkeyRulesScreenState._bgBot,
          ],
        ),
      ),
      child: CustomPaint(painter: _RulesDecorPainter()),
    );
  }
}

class _RulesDecorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r, Color color, double o) {
      canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(
              colors: [color.withOpacity(o), Colors.transparent],
            ).createShader(Rect.fromCircle(center: c, radius: r)));
    }

    glow(Offset(size.width * 0.85, size.height * 0.06), size.width * 0.5,
        const Color(0xFF2540A0), 0.28);
    glow(Offset(size.width * 0.1, size.height * 0.5), size.width * 0.45,
        const Color(0xFF1E3A8A), 0.18);
    glow(Offset(size.width * 0.5, size.height * 1.05), size.width * 0.6,
        const Color(0xFF8A6400), 0.13);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      arcPaint.color =
          const Color(0xFFFFD54F).withOpacity(0.05 + i * 0.014);
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 1.14),
          width: size.width * (0.9 + i * 0.35),
          height: size.height * (0.35 + i * 0.14),
        ),
        3.6,
        5.0,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RulesDecorPainter oldDelegate) => false;
}
