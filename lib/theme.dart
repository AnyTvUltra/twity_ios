import 'package:flutter/material.dart';

class AppColors {
  // Background
  static const Color bgDark = Color(0xFF160926);
  static const Color bgMedium = Color(0xFF281545);
  static const Color bgWarm = Color(0xFF381F15);
  static const Color bgTableWood = Color(0xFF4A2818);
  static const Color lampGlow = Color(0xFFFFB347);

  // Gold Accents
  static const Color goldLight = Color(0xFFFFF2A8);
  static const Color gold = Color(0xFFFFD54F);
  static const Color goldDeep = Color(0xFFFFB300);
  static const Color goldDark = Color(0xFFC68A00);

  // Card 1: Chess (شطرنج) - Royal Purple
  static const Color chessBg = Color(0xFF4C2A85);
  static const Color chessBorder = Color(0xFF7A4BC2);
  static const Color chessBorderLight = Color(0xFFA57CF2);
  static const Color chessGlow = Color(0xFF8F5EF5);

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

  // UI Surfaces & Text
  static const Color surfaceDark = Color(0xFF1E1135);
  static const Color surfacePill = Color(0xFF261842);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFD6C8F2);
  static const Color textMuted = Color(0xFFA595C8);

  // Play Button
  static const Color playBtnStart = Color(0xFFFF5722);
  static const Color playBtnEnd = Color(0xFFE62D00);

  // Bottom Navigation
  static const Color navBarBg = Color(0xF2160C2B);
  static const Color navActiveGlow = Color(0xFFD946EF);
  static const Color navActiveText = Colors.white;
  static const Color navInactiveText = Color(0xFF9386B5);
}

class AppGradients {
  static const LinearGradient fullBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF23103D), // Top nocturnal purple
      Color(0xFF1D0E32),
      Color(0xFF2E1934), // Middle transition
      Color(0xFF3B1E19), // Warm wood reflection
      Color(0xFF25120E), // Deep warm wooden floor
    ],
    stops: [0.0, 0.25, 0.55, 0.8, 1.0],
  );

  static const LinearGradient chessCard = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF6B3EAE),
      Color(0xFF4C2783),
      Color(0xFF371764),
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
