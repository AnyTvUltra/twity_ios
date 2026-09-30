import 'package:flutter/material.dart';
import 'theme.dart';
import 'l10n/app_lang.dart';

class GameModel {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String route;
  final LinearGradient gradient;
  final Color primaryColor;
  final Color borderColor;
  final Color borderLightColor;
  final Color glowColor;
  final bool hasCrown;

  const GameModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.route,
    required this.gradient,
    required this.primaryColor,
    required this.borderColor,
    required this.borderLightColor,
    required this.glowColor,
    this.hasCrown = false,
    this.comingSoon = false,
  });

  /// لعبة معلنة لكنها قيد التطوير — تظهر شارة "قريباً" على بطاقتها
  final bool comingSoon;
}

class GamesData {
  static List<GameModel> get games => [
        GameModel(
          id: 'chess',
          title: 'شطرنج'.tr,
          subtitle: 'Chess',
          description: 'فكر • خطط • اربح'.tr,
          route: '/games/chess',
          gradient: AppGradients.chessCard,
          primaryColor: AppColors.chessBg,
          borderColor: AppColors.chessBorder,
          borderLightColor: AppColors.chessBorderLight,
          glowColor: AppColors.chessGlow,
          hasCrown: false,
        ),
        GameModel(
          id: 'solitaire',
          title: 'رامي'.tr,
          subtitle: 'Rummy',
          description: 'ورق • بيرات • افرغ يدك أولاً'.tr,
          route: '/games/solitaire',
          gradient: AppGradients.solitaireCard,
          primaryColor: AppColors.solitaireBg,
          borderColor: AppColors.solitaireBorder,
          borderLightColor: AppColors.solitaireBorderLight,
          glowColor: AppColors.solitaireGlow,
          hasCrown: false,
        ),
        GameModel(
          id: 'ludo',
          title: 'لودو'.tr,
          subtitle: 'Ludo',
          description: 'تحدّى أصدقاءك'.tr,
          route: '/games/ludo',
          gradient: AppGradients.ludoCard,
          primaryColor: AppColors.ludoBg,
          borderColor: AppColors.ludoBorder,
          borderLightColor: AppColors.ludoBorderLight,
          glowColor: AppColors.ludoGlow,
          hasCrown: true, // Golden crown on top as in the reference image
        ),
        GameModel(
          id: 'okey',
          title: 'كونكان'.tr,
          subtitle: 'Okey',
          description: 'رتّب أحجارك • وكن الأسرع'.tr,
          route: '/games/okey',
          gradient: AppGradients.okeyCard,
          primaryColor: AppColors.okeyBg,
          borderColor: AppColors.okeyBorder,
          borderLightColor: AppColors.okeyBorderLight,
          glowColor: AppColors.okeyGlow,
          hasCrown: false,
        ),
        GameModel(
          id: 'backgammon',
          title: 'طاولي'.tr,
          subtitle: 'Backgammon',
          description: 'ذكاء • حظ • منافسة'.tr,
          route: '/games/backgammon',
          gradient: AppGradients.backgammonCard,
          primaryColor: AppColors.backgammonBg,
          borderColor: AppColors.backgammonBorder,
          borderLightColor: AppColors.backgammonBorderLight,
          glowColor: AppColors.backgammonGlow,
          hasCrown: false,
        ),
        GameModel(
          id: 'snake',
          title: 'الحية والدرج'.tr,
          subtitle: 'Snakes & Ladders',
          description: 'ارمِ النرد • اصعد الدرج'.tr,
          route: '/games/snake',
          gradient: AppGradients.snakeCard,
          primaryColor: AppColors.snakeBg,
          borderColor: AppColors.snakeBorder,
          borderLightColor: AppColors.snakeBorderLight,
          glowColor: AppColors.snakeGlow,
          hasCrown: false,
        ),
        GameModel(
          id: 'domino',
          title: 'دومينو'.tr,
          subtitle: 'Dominoes',
          description: 'طابق الأرقام • اكسب الجولة'.tr,
          route: '/games/domino',
          gradient: AppGradients.dominoCard,
          primaryColor: AppColors.dominoBg,
          borderColor: AppColors.dominoBorder,
          borderLightColor: AppColors.dominoBorderLight,
          glowColor: AppColors.dominoGlow,
          hasCrown: false,
        ),
      ];

  static GameModel getGame(String id) {
    return games.firstWhere((g) => g.id == id, orElse: () => games.first);
  }

  // Row 1: First 2 games
  static List<GameModel> get row1 => [games[0], games[1]];

  // Row 2: Next 2 games
  static List<GameModel> get row2 => [games[2], games[3]];

  // Row 3: 5th game alone centered
  static GameModel get row3Game => games[4];
}
