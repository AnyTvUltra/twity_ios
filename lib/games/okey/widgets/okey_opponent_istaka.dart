import 'dart:math' as math;
import 'package:flutter/material.dart';

enum OpponentPosition { top, left, right }

/// استكانات الخصوم ثلاثية الأبعاد – تصميم خشبي واقعي مناسب لوضع البورتريت
class OkeyOpponentIstaka extends StatelessWidget {
  final OpponentPosition position;
  final int tileCount;
  final bool isTurn;

  const OkeyOpponentIstaka({
    super.key,
    required this.position,
    this.tileCount = 14,
    this.isTurn = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (position) {
      case OpponentPosition.top:
        return _buildTopIstaka();
      case OpponentPosition.left:
        return _buildSideIstaka(isLeft: true);
      case OpponentPosition.right:
        return _buildSideIstaka(isLeft: false);
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  الاستكانة العلوية – رف أفقي مواجه للاعب
  // ─────────────────────────────────────────────────────────────
  Widget _buildTopIstaka() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.65),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          if (isTurn)
            BoxShadow(
              color: const Color(0xFF4ADE80).withOpacity(0.45),
              blurRadius: 16,
              spreadRadius: 1,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF4E2611),
                Color(0xFF381A0B),
                Color(0xFF261006),
              ],
            ),
            border: Border.all(
              color: isTurn
                  ? const Color(0xFF4ADE80)
                  : const Color(0xFF6B3A1C),
              width: isTurn ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // رأس الاستكانة
              Container(
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF3B1A0A),
                      Color(0xFF562810),
                      Color(0xFF3B1A0A),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF1E0A03), width: 1.0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🀄 $tileCount Taş',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isTurn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SIRA SENDE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      )
                    else
                      Text(
                        'OKEY',
                        style: TextStyle(
                          color:
                              const Color(0xFFD4A373).withOpacity(0.6),
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                  ],
                ),
              ),

              // صف الأحجار المقلوبة
              Container(
                height: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF261006), Color(0xFF1A0A03)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      math.min(tileCount, 14), (index) {
                    return Container(
                      width: 11,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFFDF8),
                            Color(0xFFF3E9D2),
                            Color(0xFFE4D6B6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: const Color(0xFFC7BBA5),
                          width: 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 1.5,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  الاستكانات الجانبية – رف عمودي بمنظور 3D خفيف
  // ─────────────────────────────────────────────────────────────
  Widget _buildSideIstaka({required bool isLeft}) {
    // تحويل 3D خفيف يعطي إحساس العمق بدون تشويه
    final transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(isLeft ? 0.22 : -0.22);

    return Transform(
      transform: transform,
      alignment:
          isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 12,
              offset: Offset(isLeft ? 4 : -4, 6),
            ),
            if (isTurn)
              BoxShadow(
                color: const Color(0xFF4ADE80).withOpacity(0.4),
                blurRadius: 14,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeft
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                end: isLeft
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                colors: const [
                  Color(0xFF562810),
                  Color(0xFF3E1C0A),
                  Color(0xFF2B1206),
                  Color(0xFF1E0A03),
                ],
              ),
              border: Border.all(
                color: isTurn
                    ? const Color(0xFF4ADE80)
                    : const Color(0xFF6B3A1C),
                width: isTurn ? 1.5 : 0.8,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // رأس الاستكانة الجانبية
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: const BoxDecoration(
                    color: Color(0xFF261006),
                    border: Border(
                      bottom: BorderSide(
                          color: Color(0xFF190702), width: 1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      isLeft ? '◀' : '▶',
                      style: TextStyle(
                        color: isTurn
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFD4A373),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // الأحجار العمودية
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 5, horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                        math.min(tileCount, 14), (i) {
                      // نعرض كل حجرين متكدسين
                      if (i >= 7) return const SizedBox.shrink();
                      final isEven = i % 2 == 0;
                      return Container(
                        width: 34,
                        height: 10,
                        margin: const EdgeInsets.symmetric(vertical: 1.2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: isLeft
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            end: isLeft
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            colors: isEven
                                ? const [
                                    Color(0xFFFFFDF8),
                                    Color(0xFFEBE1CA),
                                    Color(0xFFD6C8A6),
                                  ]
                                : const [
                                    Color(0xFFF5EDDA),
                                    Color(0xFFE0D4B8),
                                    Color(0xFFCEC0A0),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: const Color(0xFFBFAF91),
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.28),
                              blurRadius: 1.5,
                              offset: const Offset(0, 0.8),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                // شارة العدد
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E0A03),
                    border: Border(
                      top: BorderSide(
                          color: Color(0xFF331607), width: 1),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$tileCount',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
