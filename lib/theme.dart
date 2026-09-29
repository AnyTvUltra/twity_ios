import 'package:flutter/material.dart';
import 'theme_mode.dart';

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

  // Card 3: Ludo (لودو) - Crimson Ruby Red
  static const Color ludoBg = Color(0xFF991B1B);
  static const Color ludoBorder = Color(0xFFDC2626);
  static const Color ludoBorderLight = Color(0xFFF87171);
  static const Color ludoGlow = Color(0xFFEF4444);

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

/// لوحة "الزجاج" المستخدمة في الصفحات الداخلية — تستجيب لوضع الواجهة:
/// الوضع الليلي يعيد نفس القيم الأصلية حرفياً، والنهاري يعطي زجاجاً فاتحاً.
class LightGlass {
  static bool get _l => UiTheme.instance.isLight;

  // Surfaces
  static Color get card =>
      _l ? const Color(0xF5FFFFFF) : const Color(0xB3151D33);
  static Color get cardStrong =>
      _l ? const Color(0xFFFFFFFF) : const Color(0xF21B2338);
  static Color get cardSoft =>
      _l ? const Color(0xE6FFFFFF) : const Color(0x801E2742);
  static Color get border =>
      _l ? const Color(0x1F111B3A) : const Color(0x40FFFFFF);
  static Color get borderDim =>
      _l ? const Color(0x14111B3A) : const Color(0x1FFFFFFF);
  static Color get inputFill =>
      _l ? const Color(0xFFF1F4F9) : const Color(0x2EFFFFFF);

  // Text
  static Color get text =>
      _l ? const Color(0xFF111B3A) : const Color(0xFFF1F5F9);
  static Color get textSoft =>
      _l ? const Color(0xFF3D4A66) : const Color(0xFFCBD5E1);
  static Color get textMuted =>
      _l ? const Color(0xFF71809A) : const Color(0xFF94A3B8);
  static Color get textFaint =>
      _l ? const Color(0xFFA5B1C6) : const Color(0xFF64748B);

  // Accents
  static Color get accent =>
      _l ? const Color(0xFF2F8EF5) : const Color(0xFF38BDF8);
  static Color get accentBlue =>
      _l ? const Color(0xFF2F8EF5) : const Color(0xFF60A5FA);
  static Color get gold =>
      _l ? const Color(0xFFE8AD22) : const Color(0xFFFBBF24);
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

  /// خلفية الوضع النهاري — أوف-وايت ناعم مع عمق خفيف
  static const LinearGradient dayBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFBFCFE),
      Color(0xFFF7F9FC),
      Color(0xFFEFF3FA),
    ],
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

  static const LinearGradient ludoCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFD62828),
      Color(0xFFA61C1C),
      Color(0xFF781111),
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
      case 'ludo':
        return ludoCard;
      case 'okey':
        return okeyCard;
      case 'backgammon':
        return backgammonCard;
      default:
        return chessCard;
    }
  }
}
