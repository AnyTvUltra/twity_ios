import 'package:flutter/material.dart';

class AppColors {
  // Background
  static const Color bgDark = Color(0xFF030817);
  static const Color bgMedium = Color(0xFF101B3C);
  static const Color bgWarm = Color(0xFF1B1238);
  static const Color bgTableWood = Color(0xFF0A1028);
  static const Color lampGlow = Color(0xFF7C5CFF);

  // Gold Accents
  static const Color goldLight = Color(0xFFFFF2A8);
  static const Color gold = Color(0xFFFFD54F);
  static const Color goldDeep = Color(0xFFFFB300);
  static const Color goldDark = Color(0xFFC68A00);

  // Card 1: Chess (شطرنج) - Royal Purple
  static const Color chessBg = Color(0xFF172B72);
  static const Color chessBorder = Color(0xFF496DDB);
  static const Color chessBorderLight = Color(0xFF8EAAFF);
  static const Color chessGlow = Color(0xFF5B7CFF);

  // Card 2: Solitaire (سوليتر) - Emerald Green
  static const Color solitaireBg = Color(0xFF136A3A);
  static const Color solitaireBorder = Color(0xFF23A059);
  static const Color solitaireBorderLight = Color(0xFF48D383);
  static const Color solitaireGlow = Color(0xFF33C76F);

  // Card 4: Okey (كونكان) - Golden Amber
  static const Color okeyBg = Color(0xFF9E6508);
  static const Color okeyBorder = Color(0xFFD98E04);
  static const Color okeyBorderLight = Color(0xFFFBBF24);
  static const Color okeyGlow = Color(0xFFF59E0B);

  // Card 5: Backgammon (طاولي) - Aegean Cyan / Teal
  static const Color backgammonBg = Color(0xFF0C6170);
  static const Color backgammonBorder = Color(0xFF1792A6);
  static const Color backgammonBorderLight = Color(0xFF38BDF8);
  static const Color backgammonGlow = Color(0xFF0EA5E9);

  // Card 6: Snakes & Ladders (الحية والدرج) - Jungle Lime
  static const Color snakeBg = Color(0xFF33691E);
  static const Color snakeBorder = Color(0xFF7CB342);
  static const Color snakeBorderLight = Color(0xFFAED581);
  static const Color snakeGlow = Color(0xFF8BC34A);

  // Card 7: Dominoes (دومينو) - Slate Ivory
  static const Color dominoBg = Color(0xFF374151);
  static const Color dominoBorder = Color(0xFF6B7280);
  static const Color dominoBorderLight = Color(0xFF9CA3AF);
  static const Color dominoGlow = Color(0xFFD1D5DB);

  // UI Surfaces & Text
  static const Color surfaceDark = Color(0xB3121C3A);
  static const Color surfacePill = Color(0x99162648);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFD6C8F2);
  static const Color textMuted = Color(0xFFA595C8);

  // Play Button
  static const Color playBtnStart = Color(0xFFFF5722);
  static const Color playBtnEnd = Color(0xFFE62D00);

  // Bottom Navigation
  static const Color navBarBg = Color(0xB30A1430);
  static const Color navActiveGlow = Color(0xFFD946EF);
  static const Color navActiveText = Colors.white;
  static const Color navInactiveText = Color(0xFF9386B5);
}

/// لوحة "الزجاج الليلي" المستخدمة في الصفحات الداخلية (غير الرئيسية)
/// أسطح كحلية داكنة شبه شفافة + نصوص فاتحة + حدود زجاجية
class LightGlass {
  // Surfaces — زجاج ليلي داكن
  static const Color card = Color(0xB3151D33);
  static const Color cardStrong = Color(0xF21B2338);
  static const Color cardSoft = Color(0x801E2742);
  static const Color border = Color(0x40FFFFFF);
  static const Color borderDim = Color(0x1FFFFFFF);
  static const Color inputFill = Color(0x2EFFFFFF);

  // Text — نصوص فاتحة مريحة للعين
  static const Color text = Color(0xFFF1F5F9);
  static const Color textSoft = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textFaint = Color(0xFF64748B);

  // Accents — ألوان مميزة تناسب الوضع الليلي
  static const Color accent = Color(0xFF38BDF8);
  static const Color accentBlue = Color(0xFF60A5FA);
  static const Color gold = Color(0xFFFBBF24);
}

class AppGradients {
  /// خلفية الوضع الليلي — كحلي عميق متدرج
  static const LinearGradient lightBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF050A16),
      Color(0xFF0A1224),
      Color(0xFF101B36),
      Color(0xFF0A1020),
      Color(0xFF0D1730),
    ],
    stops: [0.0, 0.25, 0.52, 0.78, 1.0],
  );

  static const LinearGradient fullBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF071126),
      Color(0xFF0B1634),
      Color(0xFF111A3D),
      Color(0xFF171238),
      Color(0xFF080C20),
    ],
    stops: [0.0, 0.25, 0.52, 0.78, 1.0],
  );

  static const LinearGradient chessCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF4169D8),
      Color(0xFF233D94),
      Color(0xFF111D55),
    ],
  );

  static const LinearGradient solitaireCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF259B57),
      Color(0xFF146838),
      Color(0xFF0E4726),
    ],
  );

  static const LinearGradient okeyCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFD98E04),
      Color(0xFF9E6508),
      Color(0xFF704402),
    ],
  );

  static const LinearGradient backgammonCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1792A6),
      Color(0xFF0C6170),
      Color(0xFF07404B),
    ],
  );

  static const LinearGradient snakeCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF689F38),
      Color(0xFF33691E),
      Color(0xFF1B3A0F),
    ],
  );

  static const LinearGradient dominoCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF64748B),
      Color(0xFF374151),
      Color(0xFF1F2937),
    ],
  );

  static const LinearGradient goldText = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF9D2),
      Color(0xFFFFD54F),
      Color(0xFFFFB300),
      Color(0xFFE58E00),
    ],
  );

  static const LinearGradient playButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF7A45),
      Color(0xFFFF3D00),
      Color(0xFFD82800),
    ],
  );

  static LinearGradient getCardGradient(String gameId) {
    switch (gameId) {
      case 'chess':
        return chessCard;
      case 'solitaire':
        return solitaireCard;
      case 'okey':
        return okeyCard;
      case 'backgammon':
        return backgammonCard;
      default:
        return chessCard;
    }
  }
}
