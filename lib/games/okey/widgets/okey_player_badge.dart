import 'package:flutter/material.dart';
import '../okey_models.dart';

enum PlayerBadgeType { top, bottom, left, right }

/// شارة اللاعبين المطابقة تماماً للصورة المرجعية
class OkeyPlayerBadge extends StatelessWidget {
  final OkeyPlayer player;
  final bool isTurn;
  final PlayerBadgeType type;

  const OkeyPlayerBadge({
    super.key,
    required this.player,
    required this.isTurn,
    this.type = PlayerBadgeType.bottom,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case PlayerBadgeType.bottom:
        return _buildBottomBadge();
      case PlayerBadgeType.top:
        return _buildTopBadge();
      case PlayerBadgeType.left:
      case PlayerBadgeType.right:
        return _buildSideBadge();
    }
  }

  /// شارة اللاعب الرئيسي في الأسفل (Alex K.)
  Widget _buildBottomBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xEB1A1E29),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? const Color(0xFF4ADE80) : const Color(0x334B5563),
          width: isTurn ? 1.5 : 1.0,
        ),
        boxShadow: [
          if (isTurn)
            BoxShadow(
              color: const Color(0xFF4ADE80).withOpacity(0.35),
              blurRadius: 14,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الصورة الرمزية مع حلقة نيون خضراء متوهجة
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color:
                    isTurn ? const Color(0xFF4ADE80) : const Color(0xFF6B7280),
                width: isTurn ? 2.2 : 1.2,
              ),
              boxShadow: [
                if (isTurn)
                  BoxShadow(
                    color: const Color(0xFF4ADE80).withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: ClipOval(
              child: Container(
                color: const Color(0xFF2E384D),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // الاسم والتقييم والوقت
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 1.5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rating ${player.rating}',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 4.5,
                    height: 4.5,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3.5),
                  const Text(
                    '1:12',
                    style: TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// شارة اللاعب العلوي (User)
  Widget _buildTopBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xEB1A1E29),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTurn ? const Color(0xFF4ADE80) : const Color(0x334B5563),
          width: isTurn ? 1.5 : 0.8,
        ),
        boxShadow: [
          if (isTurn)
            BoxShadow(
              color: const Color(0xFF4ADE80).withOpacity(0.35),
              blurRadius: 10,
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الصورة الرمزية
          _buildAvatarWithDot(isFemale: true),
          const SizedBox(width: 7),

          // الاسم والمعلومات
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Seviye ${player.level}',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4ADE80),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${player.chips} Bakiye',
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// شارة اللاعبين الجانبيين (يسار ويمين)
  Widget _buildSideBadge() {
    final isMale = type == PlayerBadgeType.right;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // البطاقة الرئيسية
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xEB1A1E29),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTurn ? const Color(0xFF4ADE80) : const Color(0x334B5563),
              width: isTurn ? 1.5 : 0.8,
            ),
            boxShadow: [
              if (isTurn)
                BoxShadow(
                  color: const Color(0xFF4ADE80).withOpacity(0.35),
                  blurRadius: 10,
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAvatarWithDot(isFemale: !isMale),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    player.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Seviye ${player.level}',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 3.5,
                        height: 3.5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${player.chips} Bakiye',
                        style: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),

        // الكبسولة السفلية الإضافية برصيد اللاعب (70 Bakiye) مثل الصورة بالتمام
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xCC1A1E29),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0x22FFFFFF),
              width: 0.8,
            ),
          ),
          child: Text(
            '${player.chips} Bakiye',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarWithDot({required bool isFemale}) {
    final url = player.avatarUrl;
    final grad = isFemale
        ? const [Color(0xFFEC4899), Color(0xFF8B5CF6)]
        : const [Color(0xFF3B82F6), Color(0xFF1D4ED8)];
    return Stack(
      alignment: Alignment.topRight,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, colors: grad),
            border: Border.all(
              color: isTurn ? const Color(0xFF4ADE80) : Colors.white24,
              width: 1,
            ),
          ),
          child: ClipOval(
            // صورة اللاعب الحقيقية عند توفر رابطها — وإلا حرف اسمه
            child: url.startsWith('http')
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initialAvatar(isFemale),
                  )
                : _initialAvatar(isFemale),
          ),
        ),
        // نقطة الاتصال الخضراء بالأعلى
        Positioned(
          top: -1,
          right: -1,
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFF4ADE80),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1A1E29), width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  /// أفاتار الحرف الأول من اسم اللاعب — عند غياب صورة حقيقية
  Widget _initialAvatar(bool isFemale) {
    final letter = player.name.isNotEmpty ? player.name.characters.first : '?';
    return Center(
      child: Text(
        letter.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
      ),
    );
  }
}
