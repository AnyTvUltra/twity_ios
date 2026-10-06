import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../games/okey/okey_engine.dart';
import '../games/okey/okey_models.dart';
import '../games/okey/okey_rules.dart';
import '../games/okey/widgets/okey_table_painter.dart';
import '../games/okey/widgets/okey_istaka_widget.dart';
import '../games/okey/widgets/okey_opponent_istaka.dart';
import '../games/okey/widgets/okey_player_badge.dart';
import '../games/okey/widgets/okey_tile_widget.dart';
import '../games/okey/widgets/okey_chat_dialog.dart';
import '../games/okey/widgets/okey_settings_dialog.dart';
import '../games/okey/widgets/okey_win_dialog.dart';
import '../games/okey/widgets/okey_win_overlay.dart';
import '../games/okey/utils/okey_audio.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../services/game_settings_service.dart';
import '../services/store_service.dart';
import '../services/voice_service.dart';
import '../services/radio_service.dart';
import '../widgets/radio_player_widget.dart';
import '../widgets/animated_skin_effect.dart';
import '../widgets/skin_image.dart';
import '../games/okey/widgets/game_notice.dart';
import 'package:game_hub/utils/haptics.dart';
import '../l10n/app_lang.dart';

/// شاشة لعبة الأوكي التركية – تصميم بورتريت واقعي بدون تدوير
class OkeyGameScreen extends StatefulWidget {
  final OkeyRules rules;

  /// زوجي: اللاعب المقابل (الأمامي) شريكك — فوزه فوزك
  final bool teamMode;

  /// وضع رامي: نفس الطاولة والميكانيكية لكن بأوراق لعب (بلا مؤشر/كونكان/فول)
  final bool rummyMode;

  OkeyGameScreen(
      {super.key,
      OkeyRules? rules,
      this.teamMode = false,
      this.rummyMode = false})
      : rules = rules ?? (rummyMode ? OkeyRules.rummy : OkeyRules.turkish);

  @override
  State<OkeyGameScreen> createState() => _OkeyGameScreenState();
}

class _OkeyGameScreenState extends State<OkeyGameScreen>
    with TickerProviderStateMixin {
  late OkeyEngine _engine;

  // أنيميشن رمي الحجر بمسار قوسي
  late AnimationController _discardAnimController;
  late Animation<double> _discardCurve;
  OkeyTile? _animatingDiscardTile;

  // أنيميشن سحب حجر جديد
  late AnimationController _drawAnimController;
  late Animation<double> _drawCurve;
  OkeyTile? _animatingDrawTile;

  // دورة تأثير سكن الطاولة المتحرك (لافا/سديم/أورورا...)
  late AnimationController _tableFxController;

  // دعم النقر المزدوج
  int? _lastTappedSlot;
  DateTime? _lastTapTime;
  bool _roundSettled = false;
  bool _winDialogShown = false;
  bool _showWinCelebration = false;
  bool _isLeaving = false;

  // تكبير المشهد (الطاولة والأخشاب والأحجار)

  // مفاتيح مواقع لأنيميشن الحجر الطائر من اليد
  final GlobalKey _sceneKey = GlobalKey();
  final GlobalKey _discardKey = GlobalKey();
  final GlobalKey _deckKey = GlobalKey();

  // إشعار داخل المشهد المدوَّر (يظهر أفقيًا باتجاه اللعبة لا الجهاز)
  String? _sceneNotice;
  IconData? _sceneNoticeIcon;
  Timer? _noticeTimer;

  // فقاعة شات فوق استكانة المرسل داخل المشهد
  String? _chatBubbleMsg;
  int _chatBubblePlayer = 0;
  Timer? _bubbleTimer;

  /// عمود أدوات الجانب الأيمن مطوي خلف زر الإعدادات؟
  bool _dockExpanded = false;

  // ═══ توزيع الأحجار بأنيميشن عند بدء الجولة ═══
  // 4 جولات × 3 أحجار لكل لاعب ثم جولة أخيرة: الخصوم 2 والبادئ 3
  late AnimationController _dealCtrl;
  bool _dealing = true;
  final List<int> _dealtCount = [0, 0, 0, 0];
  final List<(int, int, int)> _dealFlights = []; // (المقعد، الأحجار، بدء ms)
  final Set<int> _landedFlights = {};
  int _dealTickFired = -1;
  static const _dealTotalMs = 2450;
  static const _dealFlightMs = 340;
  static const _dealGapMs = 110;
  final GlobalKey _leftDiscardKey = GlobalKey();
  Offset _discardFrom = const Offset(422, 330);
  Offset _discardTo = const Offset(422, 175);
  Offset _drawFrom = const Offset(380, 175);
  Offset _drawTo = const Offset(422, 330);

  /// هل مشهد اللعبة مُدار 90° (شاشة عمودية)؟ — لتدوير الحجر المسحوب مثله
  bool _sceneRotated = false;

  /// حجم اللوحة المنطقية الفعلي — يُحدَّث في كل LayoutBuilder وتملأ
  /// نسبتها نسبة الشاشة تماماً (لا أشرطة سوداء ولا تشويه)
  Size _sceneSize = const Size(844, 390);

  /// حاشية الجهاز بوحدات اللوحة المنطقية (الجزيرة/النوتش) — تُزيح
  /// أزرار الزوايا عن الحواف غير الآمنة بينما يملأ المشهد الشاشة كاملة
  double _safePadL = 0, _safePadR = 0, _safePadT = 0, _safePadB = 0;

  /// المقعد الذي يشاهد منه هذا العميل — 0=أسفل دائماً.
  /// اتجاه أحجار الطاولة والحوامل Viewer-Dependent: يُحسب من موضع
  /// المقعد على الشاشة لا من بيانات اللاعب، فيرى كل مشاهد الحجر نفسه
  /// موجّهاً نحو صاحبه. قابل للتبديل في وضع التصحيح لمعاينة بقية المقاعد.
  int _viewerSeat = 0;

  /// اللاعب الجالس في موضع الشاشة [seat] (0=أسفل، 1=يمين، 2=أعلى، 3=يسار)
  int _playerAtSeat(int seat) => (seat + _viewerSeat) % 4;

  /// موضع الشاشة الذي يجلس فيه اللاعب [playerIndex]
  int _seatOfPlayer(int playerIndex) => (playerIndex - _viewerSeat + 4) % 4;

  // ══════════════════════════════════════════════════════════
  //  مشهد الغرفة الكوردية: اللعبة مبنية على الصورة نفسها —
  //  الاستكانات والطاولة جزء من الصورة، والأحجار/البيرات/الأزرار
  //  تُرسم فوق مناطق محددة منها. كل إحداثيات المناطق كسورٌ من
  //  أبعاد الصورة (1024×436) ثم تُضرب في مستطيل عرضها الفعلي.
  // ══════════════════════════════════════════════════════════
  static const bool _roomScene = true;
  static const String _roomImage = 'assets/images/okey_room.png';
  static const double _roomImgW = 1024, _roomImgH = 436;

  // سجادة اللعب الوسطى — تنتهي فوق حافة الاستكانة حتى لا يُحسب
  // الإفلات على أحجاري رمياً على "الطاولة"
  static const _roomCarpetF = Rect.fromLTWH(0.300, 0.255, 0.405, 0.240);
  // سطح الطاولة الخشبي الأمامي كاملاً — الإفلات أي مكان فوقه (وليس
  // السجادة فقط) يُحسب رمياً للحجر على الطاولة
  static const _roomTableF = Rect.fromLTWH(0.235, 0.235, 0.545, 0.355);
  // استكانتي: الاتحاد العمودي لمنطقتي الأحجار — اللوح الغائر (الصف
  // العلوي قاعدته 0.758) والشريط المزخرف الأمامي (الصف السفلي حتى 0.950)
  static const _roomRackMineF = Rect.fromLTWH(0.235, 0.600, 0.540, 0.335);
  // حامل المقابل — العارضة الخشبية الأفقية تحت الوسادة الخلفية مباشرة
  static const _roomRackTopF = Rect.fromLTWH(0.365, 0.185, 0.270, 0.090);
  // حاملا الجانبين (المسندان الخشبيان المائلان بين الوسائد والطاولة)
  static const _roomRackLeftF = Rect.fromLTWH(0.255, 0.320, 0.075, 0.300);
  static const _roomRackRightF = Rect.fromLTWH(0.670, 0.320, 0.075, 0.300);
  // مناطق نزول البيرات — كلها فوق سطح السجادة فقط (سجادة الصورة تمتد
  // تقريباً x:0.30-0.71 وy:0.265-0.555) فلا تستقر الأحجار على الخشب
  // الداكن للحوامل المرسومة فتبدو مخفية. حواف الجانبين مُبعدة عن
  // إطارات صور اللاعبين، ولا منطقة تتقاطع مع مركز الرزمة (_roomCenterF)
  // كل منطقة منفصلة تماماً عن مركز الرزمة (0.418-0.582 × 0.352-0.467)
  // فلا يغطي حجر المؤشر أو الكومة أي حجر من البيرات
  static const _roomMeldMineF = Rect.fromLTWH(0.265, 0.472, 0.470, 0.118);
  static const _roomMeldTopF = Rect.fromLTWH(0.345, 0.258, 0.310, 0.090);
  static const _roomMeldLeftF = Rect.fromLTWH(0.305, 0.290, 0.108, 0.180);
  static const _roomMeldRightF = Rect.fromLTWH(0.587, 0.290, 0.108, 0.180);
  // مركز السجادة — الرزمة والمؤشر وكومة المرميات
  static const _roomCenterF = Rect.fromLTWH(0.418, 0.352, 0.164, 0.115);
  // حاشية التقاط هدف الرف حول منطقة الاستكانة — تلتقط الإفلات السريع
  // المتجاوز لحدودها (الإصبع يسبق الحجر المرئي) فيقع على أقرب خانة.
  // الحاشية السفلية أوسع بكثير: الحجر المرئي يطفو فوق الإصبع فيكون
  // الإصبع تحت أسفل الرف عند الإفلات على الصف السفلي — بلا حاشية
  // كافية يقع الإفلات خارج الهدف فيرتد الحجر وكأنه غير مقبول
  static const _rackHitPad = EdgeInsets.fromLTRB(48, 26, 48, 70);

  /// مزود صورة الغرفة — كسنة المتجر المجهزة أو الصورة الافتراضية المدمجة.
  /// كل تصاميم الغرفة تشترك في نفس التخطيط فتبقى مناطق الضبط صالحة للجميع
  ImageProvider get _roomProvider =>
      StoreService().equippedProvider(StoreCategory.okeyRoom) ??
      const AssetImage(_roomImage);

  /// الصورة مفكوكة كـ ui.Image — لرسام تمديد الحواف ولنسبة الأبعاد الحقيقية
  ui.Image? _roomUiImg;

  double get _roomAspect {
    final im = _roomUiImg;
    return im != null ? im.width / im.height : _roomImgW / _roomImgH;
  }

  /// مستطيل الصورة المعروضة داخل اللوحة — تملأ الشاشة دائماً:
  /// - شاشة أوسع من الصورة: بعرض كامل ويُقصّ فائض الارتفاع (الحائط
  ///   والأرضية) — كل عناصر المشهد تبقى مرئية
  /// - أضيق قليلاً (هواتف): بارتفاع كامل ويُقصّ ≤12.5% من كل جانب
  ///   (الحوامل والاستكانات كلها داخل 0.235..0.77 فلا يُفقد شيء)
  /// - أضيق بكثير (أجهزة لوحية): بعرض كامل وتُملأ الأطراف العلوية/
  ///   السفلية بشرائح ممدودة من الصورة نفسها — بلا أشرطة ولا قصّ
  Rect _imgRect(Size s) {
    final a = _roomAspect;
    final sceneA = s.width / s.height;
    if (sceneA >= a) {
      final h = s.width / a;
      return Rect.fromLTWH(0, (s.height - h) / 2, s.width, h);
    }
    if (sceneA >= a * 0.75) {
      final w = s.height * a;
      return Rect.fromLTWH((s.width - w) / 2, 0, w, s.height);
    }
    final h = s.width / a;
    return Rect.fromLTWH(0, (s.height - h) / 2, s.width, h);
  }

  /// تحويل كسرٍ من الصورة إلى مستطيل فعلي داخل اللوحة
  Rect _mapToImg(Rect f, Size s) {
    final img = _imgRect(s);
    return Rect.fromLTWH(
        img.left + f.left * img.width,
        img.top + f.top * img.height,
        f.width * img.width,
        f.height * img.height);
  }

  /// شريحة حافة من صورة الغرفة نفسها: الثلث الأقصى من الصورة مكبّر
  /// بعرض الشاشة ومقلوب عمودياً فيلتحم صفّها الحدي بحافة المستطيل —
  /// الجدار يكمل فوق الصورة والأرضية/السجاد تحتها (للشاشات الضيقة
  /// التي لا تكفي فيها التغطية بالقصّ) — ويدجت بحت لا يعتمد على
  /// فكّ ترميز الصورة فيعمل دائماً
  Widget _roomEdgeSlice(
      {required double bandH,
      required double imgH,
      required double sw,
      required bool top}) {
    if (bandH <= 0) return const SizedBox.shrink();
    const fracH = 0.34;
    final k = bandH / (fracH * imgH);
    return ClipRect(
      child: Transform.translate(
        // الشريط العلوي: قاعه = حافة الصورة العليا (صفّ 0) فيلتحم —
        // translate يُنزله حتى يقع الصف 0 (أسفل الصورة المقلوبة) عند bandH
        offset: Offset(0, top ? bandH - imgH * k : 0.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(1.0, -1.0, 1.0),
          child: SizedBox(
            width: sw,
            height: imgH * k,
            child: Image(image: _roomProvider, fit: BoxFit.fill),
          ),
        ),
      ),
    );
  }

  /// مستطيل سطح اللعب (السجادة في وضع الغرفة) — نسبي للأبعاد الفعلية
  Rect _tableRect(Size s) {
    if (_roomScene) return _mapToImg(_roomCarpetF, s);
    return Rect.fromLTRB(
        s.width * 0.175, s.height * 0.169, s.width * 0.825, s.height * 0.672);
  }

  /// مركز حامل أحجار المقعد — في وضع الغرفة مراكز حوامل الصورة نفسها
  Offset _seatRackCenter(int seat, Rect t, Size s) {
    if (_roomScene) {
      switch (seat) {
        case 2:
          return _mapToImg(_roomRackTopF, s).center;
        case 3:
          return _mapToImg(_roomRackLeftF, s).center;
        case 1:
          return _mapToImg(_roomRackRightF, s).center;
        default:
          return _mapToImg(_roomRackMineF, s).center;
      }
    }
    switch (seat) {
      case 2:
        return Offset(s.width / 2, t.top + 30);
      case 3:
        return Offset(t.left + 26, t.center.dy);
      case 1:
        return Offset(t.right - 26, t.center.dy);
      default:
        return Offset(s.width / 2, s.height - 88);
    }
  }

  static const int _winChips = 200;
  static const int _lossChips = 50;
  static const int _exitChips = 35;

  @override
  void initState() {
    super.initState();
    _engine = OkeyEngine(
        rules: widget.rules,
        turnDuration: GameSettingsService().defaultTurnTimer);
    _syncHumanProfile();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // جلسة صوت مشتركة: مؤثرات اللعبة لا تُسكت الراديو والعكس
    RadioService.applySharedAudioSession();
    // وضع رامي: الأحجار تُعرض كأوراق لعب في كل مكان
    OkeyTileWidget.cardMode = widget.rummyMode;

    // فكّ ترميز صورة الغرفة (الافتراضية أو كسنة المتجر) — تُستخدم لرسام
    // تمديد الحواف ولنسبة الأبعاد الحقيقية عند اختلاف مقاس التصميم
    _roomProvider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (mounted) setState(() => _roomUiImg = info.image);
      }),
    );

    _discardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _discardCurve = CurvedAnimation(
      parent: _discardAnimController,
      curve: Curves.easeOutCubic,
    );

    _drawAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    _drawCurve = CurvedAnimation(
      parent: _drawAnimController,
      curve: Curves.easeOutCubic,
    );

    _tableFxController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // أنيميشن التوزيع: يمين، أمامي، يسار ثم أنا — كل جولة متتالية بسرعة
    _dealCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _dealTotalMs),
    )
      ..addListener(_onDealTick)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _dealing = false);
        }
      });
    const dealOrder = [1, 2, 3, 0];
    var dms = 80;
    for (var r = 0; r < 4; r++) {
      for (final s in dealOrder) {
        _dealFlights.add((s, 3, dms));
        dms += _dealGapMs;
      }
    }
    for (final s in dealOrder) {
      // في رامي الجميع 14 ورقة — الجولة الأخيرة حجران للكل
      _dealFlights.add((s, (s == 0 && !widget.rummyMode) ? 3 : 2, dms));
      dms += _dealGapMs;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dealCtrl.forward();
    });

    // تسخين خامة الخشب الافتراضية (طاولة + استكانات) قبل أول رسم
    StoreService().ensureWoodBase().then((_) {
      if (mounted) setState(() {});
    });

    _engine.addListener(_onEngineUpdate);
    _engine.onNotice = (msg) {
      if (mounted) _showGameNotice(msg);
    };
    GameNotice.handler = _showGameNotice;
    GameBubble.handler = _showChatBubble;
  }

  /// فقاعة رسالة تظهر فوق استكانة اللاعب المرسل مباشرة (بدون "أرسلت:")
  void _showChatBubble(String message, int playerIndex) {
    AppHaptics.selection();
    _bubbleTimer?.cancel();
    setState(() {
      _chatBubbleMsg = message;
      _chatBubblePlayer = playerIndex;
    });
    _bubbleTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _chatBubbleMsg = null);
    });
  }

  /// فقاعة الشات نفسها — كلام فقط في بالون أنيق فوق استكانة صاحبه
  Widget _buildChatBubbles() {
    final msg = _chatBubbleMsg;
    if (msg == null) return const SizedBox.shrink();
    // موضع الفقاعة حسب مقعد اللاعب: 0 أسفل، 2 أعلى، 3 يسار، 1 يمين
    final Positioned pos;
    const colors = [
      Color(0xFF4ADE80), // أنت — أخضر
      Color(0xFF38BDF8), // يمين — أزرق
      Color(0xFFF472B6), // مقابل — وردي
      Color(0xFFFBBF24), // يسار — ذهبي
    ];
    final c = colors[_chatBubblePlayer.clamp(0, 3)];
    final bubble = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: Container(
        key: ValueKey(msg),
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xF5192130),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withOpacity(0.75), width: 1.3),
          boxShadow: [
            BoxShadow(
                color: c.withOpacity(0.30), blurRadius: 12, spreadRadius: 1),
            BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
    // مقعد صاحب الفقاعة على الشاشة من منظور هذا المشاهد + مواضع نسبية
    // للطاولة الفعلية حتى تبقى قرب حامله على أي أبعاد شاشة
    final t = _tableRect(_sceneSize);
    switch (_seatOfPlayer(_chatBubblePlayer)) {
      case 2:
        pos = Positioned(
            top: _roomScene
                ? _imgRect(_sceneSize).top + _imgRect(_sceneSize).height * 0.145
                : t.top - 14,
            left: 0,
            right: 0,
            child: Center(child: IgnorePointer(child: bubble)));
        break;
      case 3:
        pos = Positioned(
            left: math.max(4, t.left - (_roomScene ? 150 : 84)),
            top: t.center.dy - 14,
            child: IgnorePointer(child: bubble));
        break;
      case 1:
        pos = Positioned(
            right: math.max(
                4, _sceneSize.width - t.right - (_roomScene ? 150 : 84)),
            top: t.center.dy - 14,
            child: IgnorePointer(child: bubble));
        break;
      default:
        pos = Positioned(
            bottom: _roomScene
                ? _sceneSize.height -
                    _mapToImg(_roomRackMineF, _sceneSize).top +
                    34
                : 140 * (_rackSlotW() / 40) - 18,
            left: 0,
            right: 0,
            child: Center(child: IgnorePointer(child: bubble)));
    }
    return pos;
  }

  // ─────────────────────────────────────────────
  //  توزيع الأحجار الافتتاحي (Deal Animation)
  // ─────────────────────────────────────────────

  /// صوت "تكة" عند انطلاق كل قذيفة + تحديث عدّاد الأحجار عند هبوطها
  void _onDealTick() {
    final t = _dealCtrl.value * _dealTotalMs;
    var landed = false;
    for (var i = 0; i < _dealFlights.length; i++) {
      final f = _dealFlights[i];
      if (t >= f.$3 && _dealTickFired < i) {
        _dealTickFired = i;
        OkeyAudio.playTileDraw();
      }
      if (t >= f.$3 + _dealFlightMs && _landedFlights.add(i)) {
        _dealtCount[f.$1] += f.$2;
        landed = true;
      }
    }
    if (landed && mounted) setState(() {});
  }

  /// يبدأ التوزيع من جديد (بداية اللعبة أو إعادة المباراة)
  void _startDealAnim() {
    _dealing = true;
    _dealTickFired = -1;
    _landedFlights.clear();
    for (var i = 0; i < 4; i++) {
      _dealtCount[i] = 0;
    }
    _dealCtrl.forward(from: 0);
  }

  /// رفّي أثناء التوزيع — تظهر الأحجار تدريجياً مع وصول القذائف
  List<OkeyTile?> _maskedRack(int count) {
    final real = _engine.players[0].rackTiles;
    final out = List<OkeyTile?>.filled(28, null);
    var seen = 0;
    for (var s = 0; s < 28 && seen < count; s++) {
      final t = real[s];
      if (t != null) {
        out[s] = t;
        seen++;
      }
    }
    return out;
  }

  /// مواضع هبوط القذائف لكل مقعد — مراكز الحوامل على الطاولة الفعلية
  Map<int, Offset> _dealAnchors(Rect t, Size s) => {
        0: Offset(s.width / 2, s.height - 88), // استكانتي أسفلاً
        1: _seatRackCenter(1, t, s), // حامل الأيمن على حافة الطاولة
        2: _seatRackCenter(2, t, s), // حامل الأمامي
        3: _seatRackCenter(3, t, s), // حامل الأيسر
      };

  /// طبقة التوزيع: قذائف أحجار مقلوبة تطير من برج السحب لكل استكانة
  Widget _buildDealOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _dealCtrl,
        builder: (_, __) {
          final t = _dealCtrl.value * _dealTotalMs;
          final deck = _deckKey.currentContext != null
              ? _keyCenter(_deckKey)
              : const Offset(400, 178);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: _dealBanner(t)),
              for (var i = 0; i < _dealFlights.length; i++)
                _buildDealFlight(i, t, deck),
            ],
          );
        },
      ),
    );
  }

  /// لافتة مركزية تظهر وتختفي مع التوزيع
  Widget _dealBanner(double t) {
    final o = (t < 300
            ? t / 300
            : t > _dealTotalMs - 420
                ? (_dealTotalMs - t) / 420
                : 1.0)
        .clamp(0.0, 1.0);
    if (o <= 0) return const SizedBox.shrink();
    return Center(
      child: Opacity(
        opacity: o,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B2E08), Color(0xFF1E1604)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.6)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 5)),
            ],
          ),
          child: Text(
            'يتم توزيع الأحجار 🃏'.tr,
            style: const TextStyle(
                color: Color(0xFFFFD54F),
                fontSize: 13,
                fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  /// قذيفة واحدة: من الرزمة إلى مرسى المقعد بقوس عالٍ ودوران طبيعي
  /// وظلّ أرضي يتبع مسارها — يكبر الحجر في الجوّ ثم يهبط لحجم خانته
  Widget _buildDealFlight(int i, double t, Offset from) {
    final f = _dealFlights[i];
    final local = ((t - f.$3) / _dealFlightMs).clamp(0.0, 1.0);
    if (local <= 0 || local >= 1) return const SizedBox.shrink();
    final to = _dealAnchors(_tableRect(_sceneSize), _sceneSize)[f.$1]!;
    // مسار أفقي متسارع-متباطئ وعمودي يهبط بنعومة + قوس ارتفاع واضح
    final e = Curves.easeInOutCubic.transform(local);
    final x = from.dx + (to.dx - from.dx) * e;
    final arcLift = math.sin(local * math.pi) * 62;
    final gy =
        from.dy + (to.dy - from.dy) * Curves.easeOutQuad.transform(local);
    final y = gy - arcLift;
    // يبدأ بمقاس الرزمة، يكبر في الجوّ ليقترب من المشاهد، ثم يهبط
    // لمقاس خانة مقعده (مقعدي كبير، الخصوم أصغر)
    final seatScale = f.$1 == 0 ? 1.12 : 0.78;
    final sc = seatScale + (1.34 - seatScale) * math.sin(local * math.pi);
    final dir = f.$1.isEven ? -1.0 : 1.0;
    final shadowT = 1.0 - arcLift / 62;
    return Stack(clipBehavior: Clip.none, children: [
      // الظل الأرضي: يتبع نقطة الهبوط تحت القذيفة ويصغر كلما ارتفعت
      Positioned(
        left: x - 13,
        top: gy - 4,
        child: Opacity(
          opacity: 0.30 * shadowT.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(
                0.55 + 0.45 * shadowT, 0.55 + 0.45 * shadowT, 1.0),
            child: Container(
              width: 26,
              height: 7,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                boxShadow: [BoxShadow(blurRadius: 6, color: Colors.black54)],
              ),
            ),
          ),
        ),
      ),
      // الحزمة الطائرة — دوران متصل خفيف يتوقف عند الهبوط
      Positioned(
        left: x - 17,
        top: y - 19,
        child: Transform.rotate(
          angle: dir * local * (f.$1 == 0 ? 0.45 : 0.7),
          child: Transform.scale(scale: sc, child: _dealFan(f.$2)),
        ),
      ),
    ]);
  }

  /// حزمة 2-3 أحجار مقلوبة مروّحة تطير معاً — كل حجر مائل قليلاً
  /// عن التالي ليبدو كورقة مفروشة لا كومة مكدّسة
  Widget _dealFan(int n) {
    final mid = (n - 1) / 2;
    return SizedBox(
      width: 24 + (n - 1) * 8,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var k = 0; k < n; k++)
            Positioned(
              left: k * 7.0,
              top: (k - mid).abs() * 1.6,
              child: Transform.rotate(
                angle: (k - mid) * 0.10,
                child: _tileBack(20, 30),
              ),
            ),
        ],
      ),
    );
  }

  void _syncHumanProfile() {
    final user = AuthService().currentUser;
    if (user == null) return;
    _engine.players[0].chips = user.chips;
    _engine.players[0].rating = user.rating;
    if (user.photoUrl.isNotEmpty) {
      _engine.players[0].avatarUrl = user.photoUrl;
    }
  }

  /// إشعار داخل المشهد نفسه — يظهر أفقيًا باتجاه اللعبة المدوّرة
  void _showGameNotice(String message, {IconData? icon}) {
    AppHaptics.light();
    _noticeTimer?.cancel();
    setState(() {
      _sceneNotice = message;
      _sceneNoticeIcon = icon;
    });
    _noticeTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _sceneNotice = null);
    });
  }

  Widget _buildSceneNotice() {
    final msg = _sceneNotice;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.6),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: FadeTransition(opacity: anim, child: child),
      ),
      child: msg == null
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(msg),
              constraints: const BoxConstraints(maxWidth: 380),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF3B1E6D), Color(0xFF1E0E35)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD54F).withOpacity(0.6),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withOpacity(0.18),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_sceneNoticeIcon ?? Icons.notifications_active_rounded,
                      color: const Color(0xFFFFD54F), size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _onEngineUpdate() {
    if (_engine.gameState == OkeyGameState.win &&
        _engine.winner != null &&
        mounted &&
        !_winDialogShown) {
      _winDialogShown = true;
      // أنيميشن الاحتفال أولاً — يظهر للجميع — ثم نافذة النتيجة
      setState(() => _showWinCelebration = true);
      Timer(const Duration(milliseconds: 2700), () {
        if (!mounted) return;
        setState(() => _showWinCelebration = false);
        _handleGameEnd();
      });
    }
  }

  Future<void> _handleGameEnd() async {
    final winner = _engine.winner!;
    // في الزوجي: فوز الشريك المقابل = فوز فريقك
    final isHumanWinner = winner.isHuman ||
        (widget.teamMode && identical(winner, _engine.players[2]));
    await _settleRound(
      chipChange: isHumanWinner ? _winChips : -_lossChips,
      ratingChange: isHumanWinner ? 25 : -15,
      isWin: isHumanWinner,
    );
    if (!mounted) return;
    OkeyAudio.playWin();
    OkeyWinDialog.show(
      context,
      winner: winner,
      winType: _engine.winType ?? WinType.normal,
      onPlayAgain: () {
        setState(() {
          _roundSettled = false;
          _winDialogShown = false;
          _isLeaving = false;
          _engine.initGame();
          _syncHumanProfile();
          _startDealAnim();
        });
      },
      onExit: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  Future<bool> _settleRound({
    required int chipChange,
    required int ratingChange,
    required bool isWin,
  }) async {
    if (_roundSettled) return true;
    _roundSettled = true;
    final success = await AuthService().updateMatchResult(
      chipChange: chipChange,
      ratingChange: ratingChange,
      isWin: isWin,
    );
    if (!success) {
      _roundSettled = false;
      return false;
    }
    _syncHumanProfile();
    if (mounted) setState(() {});
    return true;
  }

  @override
  void dispose() {
    OkeyTileWidget.cardMode = false;
    _engine.removeListener(_onEngineUpdate);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _noticeTimer?.cancel();
    _bubbleTimer?.cancel();
    GameNotice.handler = null;
    GameBubble.handler = null;
    _discardAnimController.dispose();
    _drawAnimController.dispose();
    _tableFxController.dispose();
    _dealCtrl.dispose();

    _engine.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  قوائم ونوافذ
  // ─────────────────────────────────────────────

  void _showMoreMenu() {
    AppHaptics.light();
    OkeyAudio.playButtonClick();
    showOkeyLandscapeDialog(
      context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF241538), Color(0xFF160B24)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x40FFD54F), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.more_horiz_rounded,
                          color: Color(0xFFFFD54F), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'قائمة الخيارات'.tr,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 20),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFD54F),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book_rounded,
                      color: Color(0xFFFFD54F), size: 20),
                ),
                title: Text('قواعد اللعبة'.tr,
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text('تشكيل المجموعات وحجر الأوكي'.tr,
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showRulesDialog();
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0x224ADE80),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    OkeyAudio.soundEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: const Color(0xFF4ADE80),
                    size: 20,
                  ),
                ),
                title: Text(
                  OkeyAudio.soundEnabled ? 'كتم الصوت'.tr : 'تشغيل الصوت'.tr,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: Text(
                  OkeyAudio.soundEnabled
                      ? 'المؤثرات الصوتية مفعلة'.tr
                      : 'المؤثرات الصوتية معطلة'.tr,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                onTap: () {
                  setState(
                      () => OkeyAudio.soundEnabled = !OkeyAudio.soundEnabled);
                  Navigator.of(ctx).pop();
                  _showGameNotice(
                    OkeyAudio.soundEnabled
                        ? 'تم تشغيل الصوت 🔊'.tr
                        : 'تم كتم الصوت 🔇'.tr,
                    icon: OkeyAudio.soundEnabled
                        ? Icons.volume_up
                        : Icons.volume_off,
                  );
                },
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: Text('انسحاب من الجولة (خسارة)'.tr,
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _confirmSurrender();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSurrender() {
    showOkeyLandscapeDialog(
      context,
      barrierDismissible: false,
      // مربع مدمج قريب من الشكل المربّع بدل مستطيل عريض يغطي الطاولة
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Container(
          width: 265,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E112E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFFEF4444).withOpacity(0.25),
                  blurRadius: 22),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444), size: 34),
              const SizedBox(height: 8),
              Text(
                'تأكيد الانسحاب'.tr,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 10),
              Text(
                '⚠️ تحذير: إذا قمت بالانسحاب الآن ستفقد رسوم الجولة (35 عملة ذهبية) وتُسجل لك خسارة رسمية في تقييمك السحابي!'
                    .tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFFCA5A5), fontSize: 11.5, height: 1.5),
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد من رغبتك في الاستسلام ومغادرة الطاولة؟'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('متابعة اللعب'.tr,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _executeSurrender();
                      },
                      child: Text('نعم، انسحاب'.tr,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeSurrender() async {
    if (_isLeaving) return;
    _isLeaving = true;
    AppHaptics.heavy();
    final success = await _settleRound(
      chipChange: -_exitChips,
      ratingChange: -20,
      isWin: false,
    );
    if (!mounted) return;
    if (!success) {
      _isLeaving = false;
      _showGameNotice('تعذر تحديث الرصيد، حاول مرة أخرى'.tr);
      return;
    }
    FirebaseService().logGameResult(
      winnerName: 'الانسحاب (Surrender)'.tr,
      winType: 'surrender',
      roundDurationSeconds: _engine.turnDuration - _engine.turnTimeRemaining,
    );
    Navigator.of(context).pop();
  }

  void _requestExit() {
    if (_roundSettled) {
      Navigator.of(context).pop();
      return;
    }
    _confirmSurrender();
  }

  void _showRulesDialog() {
    showOkeyLandscapeDialog(
      context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E112E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Icon(Icons.menu_book_rounded, color: Color(0xFFFFD54F), size: 22),
            SizedBox(width: 8),
            Flexible(
              child: Text('قواعد لعبة الأوكي (Okey)'.tr,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• الهدف: تكوين مجموعات صالحة من 14 حجراً (متتالية من نفس اللون أو متماثلة بألوان مختلفة).'
                    .tr,
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 6),
              Text(
                '• حجر الأوكي الحقيقي (Joker): يعوض عن أي حجر ناقص.'.tr,
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              SizedBox(height: 6),
              Text(
                '• الرمي: ارمِ الحجر الزائد في مربع الرمي الأحمر بالمنتصف.'.tr,
                style:
                    TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('حسناً فهمت'.tr,
                style: TextStyle(color: Color(0xFFFFD54F))),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  منطق اللعبة
  // ─────────────────────────────────────────────

  /// مركز عنصر في المشهد بإحداثيات المشهد المنطقية (844×390)
  Offset _keyCenter(GlobalKey key) {
    final ctx = key.currentContext;
    final sceneCtx = _sceneKey.currentContext;
    if (ctx == null || sceneCtx == null) return const Offset(422, 190);
    final box = ctx.findRenderObject() as RenderBox;
    final scene = sceneCtx.findRenderObject() as RenderBox;
    return scene.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  /// عرض خانة الرف الفعلي — نفس معادلة OkeyIstakaWidget (حتى 40 كحد أقصى)
  double _rackSlotW() => ((_sceneSize.width - 64) / 14).clamp(24.0, 40.0);

  /// موقع خانة الرف التقريبي داخل المشهد — محسوب من أبعاده الفعلية
  /// (في وضع الغرفة: داخل تجويف استكانة الصورة بنفس هندسة ghostMode)
  Offset _rackSlotCenter(int slot) {
    final s = _sceneSize;
    if (_roomScene) {
      // نفس معادلة ghostMode في OkeyIstakaWidget — يجب أن تبقى متطابقة:
      // الصف العلوي قاعدته عند 0.758 من الصورة والسفلي عند أسفل المنطقة
      final zone = _mapToImg(_roomRackMineF, s);
      final slotW = ((zone.width - 24) / 14).clamp(20.0, 40.0);
      final tileH = slotW * 1.28 * 1.10;
      final x0 = zone.left + (zone.width - slotW * 14) / 2;
      final x = x0 + slotW * (slot % 14 + 0.5);
      final row0BaseY = zone.bottom - zone.height * (0.935 - 0.758) / 0.335;
      final row1BaseY = zone.bottom - zone.height * (0.935 - 0.912) / 0.335;
      final y = slot < 14 ? row0BaseY - tileH / 2 : row1BaseY - tileH / 2;
      return Offset(x, y);
    }
    final slotW = _rackSlotW();
    final tileH = (slotW - 2) * 1.28;
    final rackTop = s.height - 12 - 140 * (slotW / 40);
    // الاستكانة ممرّكة: جسمها = slotW*14 + 52 والتجويف يبدأ +26 داخله
    final x0 = (s.width - (slotW * 14 + 52)) / 2 + 26;
    final x = x0 + slotW / 2 + slotW * (slot % 14);
    final y = slot < 14 ? rackTop + 24 + tileH / 2 : rackTop + 29 + tileH * 1.5;
    return Offset(x, y);
  }

  void _executeDiscard(int slotIndex, {Offset? dropGlobal}) {
    if (_dealing) return;
    if (_engine.currentTurnIndex != 0) return;
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDiscard) {
      _showGameNotice('يجب سحب حجر أولاً قبل الرمي!'.tr);
      return;
    }
    final tile = _engine.players[0].rackTiles[slotIndex];
    if (tile == null) return;

    OkeyAudio.playTileDiscard();

    // الحجر يطير من مركزه الظاهر — details.offset هو زاوية صندوق
    // الـfeedback فيضاف نصف حجم الحجر للوصول للمركز
    Offset from;
    if (dropGlobal != null && _sceneKey.currentContext != null) {
      final scene = _sceneKey.currentContext!.findRenderObject() as RenderBox;
      from = scene.globalToLocal(dropGlobal + _dropTileHalfScene);
    } else {
      from = _rackSlotCenter(slotIndex);
    }

    setState(() {
      _animatingDiscardTile = tile;
      _discardFrom = from;
      _discardTo = _keyCenter(_discardKey);
    });

    _discardAnimController.forward(from: 0).then((_) {
      _engine.discardSlot(slotIndex);
      setState(() => _animatingDiscardTile = null);
      _discardAnimController.reset();
    });
  }

  void _executeDraw() {
    if (_dealing) return;
    if (_engine.currentTurnIndex != 0) return;
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDraw) {
      _showGameNotice('لقد سحبت بالفعل! ارمِ حجراً لإنهاء دورك'.tr);
      return;
    }
    // رزمة فارغة؟ أعد خلط المرميات أولاً بدل إجبارك على أخذ حجر الخصم
    if (!_engine.ensureDrawableDeck()) {
      _showGameNotice('لا أحجار متبقية للسحب إطلاقاً'.tr);
      return;
    }
    OkeyAudio.playTileDraw();
    final tile = _engine.drawDeck.first;
    final emptySlot = _engine.players[0].rackTiles.indexOf(null);
    setState(() {
      _animatingDrawTile = tile;
      _drawFrom = _keyCenter(_deckKey);
      _drawTo =
          emptySlot != -1 ? _rackSlotCenter(emptySlot) : _rackSlotCenter(0);
    });

    _drawAnimController.forward(from: 0).then((_) {
      _engine.drawFromDeck();
      setState(() => _animatingDrawTile = null);
      _drawAnimController.reset();
    });
  }

  /// سحب بالإفلات: من الرزمة أو كومة اليسار مباشرة إلى خانة في الرف
  void _drawToSlot(int source, int toSlot) {
    if (_dealing) return;
    if (_engine.currentTurnIndex != 0) {
      _showGameNotice('ليس دورك الآن!'.tr);
      return;
    }
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDraw) {
      _showGameNotice('لقد سحبت بالفعل! ارمِ حجراً لإنهاء دورك'.tr);
      return;
    }
    if (source == OkeyDrag.leftPile &&
        _engine.players[3].playStyle == OkeyPlayStyle.full) {
      _showGameNotice('اللاعب الأيسر يلعب فول — لا يمكن أخذ أحجاره'.tr);
      return;
    }
    final ok = source == OkeyDrag.deck
        ? _engine.drawFromDeck(toSlot: toSlot)
        : _engine.drawFromDiscard(toSlot: toSlot);
    if (ok) {
      OkeyAudio.playTileDraw();
      AppHaptics.light();
    }
  }

  /// سحب آخر حجر رماه اللاعب الأيسر
  void _executeDrawFromLeft() {
    if (_dealing) return;
    if (_engine.currentTurnIndex != 0) return;
    if (_engine.turnPhase != OkeyTurnPhase.awaitingDraw) {
      _showGameNotice('لقد سحبت بالفعل! ارمِ حجراً لإنهاء دورك'.tr);
      return;
    }
    final pile = _engine.discardPiles[3];
    if (pile.isEmpty) {
      _showGameNotice('اللاعب الأيسر لم يرمِ أي حجر بعد'.tr);
      return;
    }
    if (_engine.players[3].playStyle == OkeyPlayStyle.full) {
      _showGameNotice('اللاعب الأيسر يلعب فول — لا يمكن أخذ أحجاره'.tr);
      return;
    }

    OkeyAudio.playTileDraw();
    final tile = pile.last;
    final emptySlot = _engine.players[0].rackTiles.indexOf(null);
    setState(() {
      _animatingDrawTile = tile;
      _drawFrom = _keyCenter(_leftDiscardKey);
      _drawTo =
          emptySlot != -1 ? _rackSlotCenter(emptySlot) : _rackSlotCenter(0);
    });

    _drawAnimController.forward(from: 0).then((_) {
      _engine.drawFromDiscard();
      setState(() => _animatingDrawTile = null);
      _drawAnimController.reset();
    });
  }

  void _handleTileTap(int slotIndex) {
    final now = DateTime.now();
    if (_lastTappedSlot == slotIndex &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 350)) {
      if (_engine.getHighlightedSlotIndices().contains(slotIndex)) {
        if (!_humanHasReadyPer) {
          _showGameNotice('لم تبلغ نقاط الفتح بعد — المطلوب {} نقطة'
              .trp([_engine.rules.openingPoints]));
        } else if (_engine.layMeldContainingSlot(slotIndex)) {
          AppHaptics.medium();
          _showGameNotice('تم إنزال الـ Per على الطاولة'.tr);
        }
        _lastTappedSlot = null;
        _lastTapTime = null;
        return;
      }
      if (_engine.currentTurnIndex == 0 &&
          _engine.turnPhase == OkeyTurnPhase.awaitingDiscard) {
        _executeDiscard(slotIndex);
        _lastTappedSlot = null;
        _lastTapTime = null;
        return;
      }
    }
    _lastTappedSlot = slotIndex;
    _lastTapTime = now;
    OkeyAudio.playTilePickup();
    _engine.selectTile(slotIndex);
  }

  // ─────────────────────────────────────────────
  //  بناء الشاشة – بورتريت واقعي
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final rotateToLandscape = media.orientation == Orientation.portrait;
    final landscapeMedia = rotateToLandscape
        ? media.copyWith(
            size: Size(media.size.height, media.size.width),
            padding: EdgeInsets.symmetric(
              horizontal: media.padding.top > media.padding.bottom
                  ? media.padding.top
                  : media.padding.bottom,
              vertical: media.padding.left > media.padding.right
                  ? media.padding.left
                  : media.padding.right,
            ),
          )
        : media;
    _sceneRotated = rotateToLandscape;
    final scene = AnimatedBuilder(
      animation: Listenable.merge([_engine, StoreService()]),
      builder: (context, _) => _buildLandscapeLayout(context),
    );
    final game = MediaQuery(
      data: landscapeMedia,
      // بلا SafeArea في الحالتين: المشهد يملأ الشاشة حافة-لحافة —
      // حواف الجزيرة/النوتش الجانبية كانت تقتطع عرض اللوحة الأفقية
      // فتظهر كأشرطة سوداء على الجانبين. أزرار الزوايا تُزاح يدوياً
      // بمقدار حاشية الجهاز داخل المشهد (انظر _safePadL/_safePadR)
      child: scene,
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _requestExit();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF141018),
          body: rotateToLandscape
              ? RotatedBox(quarterTurns: 1, child: game)
              : game,
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    // حجم التصميم المرجعي — اللوحة المنطقية لا تصغر عنه أبداً
    const designW = 844.0;
    const designH = 390.0;
    final isHumanTurn = _engine.currentTurnIndex == 0;
    final minutes =
        (_engine.turnTimeRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_engine.turnTimeRemaining % 60).toString().padLeft(2, '0');

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive Full-Screen Scaling:
        // مقياس موحّد واحد (لا تشويه ولا تمدّد غير متساوٍ) يكفي لتغطية
        // الشاشة، واللوحة المنطقية تتمدد في البعد الأوسع فقط حتى تطابق
        // نسبة الـViewport بالضبط — تملؤها حافة-لحافة بلا أشرطة سوداء
        // ولا Letterboxing/Pillarboxing على أي أبعاد (16:9 / 19.5:9 / 20:9…)
        final s = math.min(
            constraints.maxWidth / designW, constraints.maxHeight / designH);
        final sw = constraints.maxWidth / s;
        final sh = constraints.maxHeight / s;
        _sceneSize = Size(sw, sh);
        // حاشية الجهاز (الجزيرة/النوتش) بوحدات اللوحة المنطقية — المشهد
        // يملأ الشاشة كلها وأزرار الزوايا تُزاح عن منطقة الحاشية فقط
        final pad = MediaQuery.of(context).padding;
        _safePadL = pad.left / s;
        _safePadR = pad.right / s;
        _safePadT = pad.top / s;
        _safePadB = pad.bottom / s;
        // OverflowBox: اللوحة المنطقية تُبنى بمقاسها الحقيقي sw×sh ثم تُكبَّر
        // بمقدار s فتطابق الشاشة تماماً. بدونه كانت القيود المحكمة تفرض
        // مقاس الشاشة على اللوحة قبل التكبير، فتخرج العناصر المثبتة يميناً
        // وأسفل (زر السماعة، الـdock، زر الفوز) خارج الشاشة بمقدار (s-1)
        return SizedBox.expand(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: sw,
            maxWidth: sw,
            minHeight: sh,
            maxHeight: sh,
            child: Transform.scale(
              scale: s,
              alignment: Alignment.topLeft,
              child: SizedBox(
                key: _sceneKey,
                width: sw,
                height: sh,
                child: _buildScene(
                    context, isHumanTurn, minutes, seconds, s, sw, sh),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScene(BuildContext context, bool isHumanTurn, String minutes,
      String seconds, double scale, double sw, double sh) {
    final tbl = _tableRect(Size(sw, sh));
    final imgRect = _imgRect(Size(sw, sh));
    // حامل الخصم مصغّر بنفس تصميم استكانتي — مقياسه من ارتفاع الطاولة
    final oppTileW = (tbl.height / 15).clamp(10.0, 14.0);
    final oppRackW = oppTileW * 9.5 + 4;
    final oppRackH = oppTileW * 4.32 + 8;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // ═══ منطقة اللعب القابلة للتكبير (الطاولة والأحجار والاستكانات) ═══
        Positioned.fill(
          child: ClipRect(
            child: SizedBox(
              width: sw,
              height: sh,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  if (_roomScene) ...[
                    // ═══ خلفية الغرفة تملأ الشاشة حافة-لحافة: ═══
                    // أساس داكن ثم شريحتان من الصورة نفسها مكبّرتان
                    // ومقلوبتان عمودياً — الجدار يكمل فوقاً والأرضية
                    // تحتاً بالتحامٍ مثالي مع حواف الصورة المعروضة
                    const Positioned.fill(
                        child: ColoredBox(color: Color(0xFF141018))),
                    if (imgRect.top > 0.5)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: imgRect.top,
                        child: _roomEdgeSlice(
                            bandH: imgRect.top,
                            imgH: imgRect.height,
                            sw: sw,
                            top: true),
                      ),
                    if (sh - imgRect.bottom > 0.5)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: imgRect.bottom,
                        height: sh - imgRect.bottom,
                        child: _roomEdgeSlice(
                            bandH: sh - imgRect.bottom,
                            imgH: imgRect.height,
                            sw: sw,
                            top: false),
                      ),
                    // الصورة الحادة — تملأ العرض دائماً، وتملأ الارتفاع
                    // على الشاشات القريبة من نسبتها (قصّ حواف آمن)
                    Positioned.fromRect(
                      rect: imgRect,
                      child: Image(image: _roomProvider, fit: BoxFit.fill),
                    ),
                  ] else ...[
                    Builder(builder: (context) {
                      final bgItem =
                          StoreService().equippedFor(StoreCategory.background);
                      if (bgItem != null) {
                        return SkinTransformImage.fromItem(bgItem);
                      }
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment(0, -0.1),
                            radius: 1.05,
                            colors: [
                              Color(0xFF17171B),
                              Color(0xFF090C12),
                              Color(0xFF030509)
                            ],
                            stops: [0, 0.6, 1],
                          ),
                        ),
                      );
                    }),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.08),
                                Colors.black.withOpacity(0.52)
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (!_roomScene)
                    Positioned.fromRect(
                      rect: tbl,
                      child: Builder(builder: (context) {
                        final tblSkin =
                            StoreService().equippedFor(StoreCategory.table);
                        final tblFx = skinEffectOf(tblSkin);
                        if (tblFx == SkinEffect.none) {
                          return CustomPaint(
                            painter: OkeyTablePainter(
                              isHumanTurn: isHumanTurn,
                              surfaceItem: tblSkin,
                            ),
                          );
                        }
                        return AnimatedBuilder(
                          animation: _tableFxController,
                          builder: (context, _) => CustomPaint(
                            painter: OkeyTablePainter(
                              isHumanTurn: isHumanTurn,
                              surfaceItem: tblSkin,
                              surfaceEffect: tblFx,
                              animT: _tableFxController.value,
                            ),
                          ),
                        );
                      }),
                    ),
                  // منطقة رمي تغطي سطح الطاولة فقط (فوق مستوى الاستكانة):
                  // إسقاط الحجر هناك = رمي. الإفلات أسفل/عند الاستكانة لا يُقبل
                  // فيعود الحجر مكانه — لا رمي بالخطأ من سحب سريع داخل الرف
                  Positioned.fill(
                    child: DragTarget<int>(
                      onWillAcceptWithDetails: (details) =>
                          _isOverTable(details.offset),
                      onAcceptWithDetails: (details) =>
                          _dropOnTable(details.data, details.offset),
                      builder: (context, candidateData, rejectedData) {
                        final hovering =
                            candidateData.isNotEmpty && isHumanTurn;
                        return Stack(children: [
                          Positioned.fromRect(
                            rect: Rect.fromLTRB(
                                tbl.left, tbl.top - 4, tbl.right, tbl.bottom),
                            child: IgnorePointer(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: hovering
                                      ? const Color(0xFFEF4444)
                                          .withOpacity(0.08)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                  border: hovering
                                      ? Border.all(
                                          color: const Color(0x55EF4444),
                                          width: 1.2)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ]);
                      },
                    ),
                  ),
                  // ═══ حوامل الخصوم ═══
                  // وضع الغرفة: الحوامل مرسومة في الصورة وأحجار الخصوم
                  // مخفية بطلب المستخدم — لا يُرسم شيء فوقها
                  if (!_roomScene)
                    // نفس تصميم استكانة اللاعب الحالي (خامة/شريط زجاجي/رفّان/
                    // فاصل معدني) بمقياس أصغر، وكل حامل مستلقٍ على سطح الطاولة
                    // موجّهاً وجهه نحو مقعد صاحبه — منظور 3D محسوب من موضع
                    // المقعد، وليس تدويراً ثابتاً
                    for (final seat in [2, 3, 1])
                      Positioned(
                        left: _seatRackCenter(seat, tbl, Size(sw, sh)).dx -
                            oppRackW / 2,
                        top: _seatRackCenter(seat, tbl, Size(sw, sh)).dy -
                            oppRackH / 2,
                        child: SizedBox(
                          width: oppRackW,
                          child: IgnorePointer(
                            child: OkeyOpponentIstaka(
                              position: seat == 2
                                  ? OpponentPosition.top
                                  : seat == 3
                                      ? OpponentPosition.left
                                      : OpponentPosition.right,
                              tileW: oppTileW,
                              tileCount: _dealing
                                  ? _dealtCount[seat]
                                  : _engine
                                      .players[_playerAtSeat(seat)].tileCount,
                              isTurn: !_dealing &&
                                  _engine.currentTurnIndex ==
                                      _playerAtSeat(seat),
                              rackItem: StoreService()
                                  .equippedFor(StoreCategory.rack),
                            ),
                          ),
                        ),
                      ),
                  // استكانة المقعد السفلي — تُظهر أحجار اللاعب الجالس فيه
                  // من منظور هذا المشاهد (عادةً 0=أنا). التفاعل مقصور على
                  // منظوري الحقيقي حتى لا تتحرك أحجار غيري في المعاينة
                  Positioned(
                    // منطقة الالتقاط موسّعة بحاشية hitPad حول تجويف
                    // الاستكانة — الإفلات السريع المتجاوز للحدود يقع
                    // على أقرب خانة بدل أن يرتد الحجر مكانه
                    left: _roomScene
                        ? _mapToImg(_roomRackMineF, Size(sw, sh)).left -
                            _rackHitPad.left
                        : 0,
                    right: _roomScene ? null : 0,
                    bottom: _roomScene ? null : 12,
                    top: _roomScene
                        ? _mapToImg(_roomRackMineF, Size(sw, sh)).top -
                            _rackHitPad.top
                        : null,
                    width: _roomScene
                        ? _mapToImg(_roomRackMineF, Size(sw, sh)).width +
                            _rackHitPad.horizontal
                        : null,
                    height: _roomScene
                        ? _mapToImg(_roomRackMineF, Size(sw, sh)).height +
                            _rackHitPad.vertical
                        : null,
                    child: IgnorePointer(
                      ignoring: _dealing || _viewerSeat != 0,
                      child: OkeyIstakaWidget(
                        ghostMode: _roomScene,
                        hitPad: _roomScene ? _rackHitPad : EdgeInsets.zero,
                        rackTiles: _dealing
                            ? _maskedRack(_dealtCount[0])
                            : _engine.players[_playerAtSeat(0)].rackTiles,
                        selectedIndex: _engine.selectedTileIndex,
                        isTurn: isHumanTurn && !_dealing,
                        highlightedIndices: _engine.getHighlightedSlotIndices(),
                        dragScaleX: scale,
                        dragScaleY: scale,
                        feedbackQuarterTurns: _sceneRotated ? 1 : 0,
                        rackItem:
                            StoreService().equippedFor(StoreCategory.rack),
                        onTileTap: _handleTileTap,
                        onTileMove: (fromSlot, toSlot) =>
                            _engine.moveTile(fromSlot, toSlot),
                        onDropAboveRack: _dropOnTable,
                        onDrawToSlot: _drawToSlot,
                        onGroupMove: (slot, to) => _engine.moveGroup(slot, to),
                      ),
                    ),
                  ),
                  if (_engine.canDeclareOkeyOut && !_dealing)
                    Positioned(
                      // زر جانبي صغير أسفل اليمين فوق زر الإعدادات —
                      // كان شريطاً ذهبياً طويلاً يغطي بيراتك على الطاولة
                      right: 10 + _safePadR,
                      bottom: 62 + _safePadB,
                      child: _buildOkeyOutButton(),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _roomScene
                        ? _mapToImg(_roomCenterF, Size(sw, sh)).top
                        : tbl.top + tbl.height * 0.14,
                    height: _roomScene
                        ? _mapToImg(_roomCenterF, Size(sw, sh)).height
                        : null,
                    child: Center(
                      child: _roomScene
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _buildTableCenter(isHumanTurn))
                          : _buildTableCenter(isHumanTurn),
                    ),
                  ),
                  // أماكن البير على الطاولة — لكل لاعب جهته، ظاهرة للجميع
                  ..._buildTableMelds(_meldZones(Size(sw, sh), tbl)),
                  // ═══════ أنيميشن الحجر الطائر: الرمي من يد اللاعب ═══════
                  if (_animatingDiscardTile != null)
                    AnimatedBuilder(
                      animation: _discardCurve,
                      builder: (context, _) {
                        final t = _discardCurve.value;
                        final x = _discardFrom.dx +
                            (_discardTo.dx - _discardFrom.dx) * t;
                        final arcLift = math.sin(t * math.pi) * 46;
                        final y = _discardFrom.dy +
                            (_discardTo.dy - _discardFrom.dy) * t -
                            arcLift;
                        return Positioned(
                          left: x - 14,
                          top: y - 19,
                          child: IgnorePointer(
                            child: Transform.rotate(
                              angle: 0.18 * math.sin(t * math.pi),
                              child: Material(
                                color: Colors.transparent,
                                elevation: 8,
                                child: OkeyTileWidget(
                                  tile: _animatingDiscardTile,
                                  isDragging: true,
                                  width: 28,
                                  height: 38,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // ═══════ أنيميشن الحجر الطائر: السحب إلى الرف ═══════
                  if (_animatingDrawTile != null)
                    AnimatedBuilder(
                      animation: _drawCurve,
                      builder: (context, _) {
                        final t = _drawCurve.value;
                        final x =
                            _drawFrom.dx + (_drawTo.dx - _drawFrom.dx) * t;
                        final arcLift = math.sin(t * math.pi) * 34;
                        final y = _drawFrom.dy +
                            (_drawTo.dy - _drawFrom.dy) * t -
                            arcLift;
                        return Positioned(
                          left: x - 14,
                          top: y - 19,
                          child: IgnorePointer(
                            child: Transform.scale(
                              scale: 1.0 + 0.18 * math.sin(t * math.pi),
                              child: Material(
                                color: Colors.transparent,
                                elevation: 8,
                                child: OkeyTileWidget(
                                  tile: _animatingDrawTile,
                                  isDragging: true,
                                  width: 28,
                                  height: 38,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                  // ═══════ أنيميشن توزيع الأحجار الافتتاحي ═══════
                  if (_dealing) _buildDealOverlay(),
                ],
              ),
            ),
          ),
        ),
        // ═══ عناصر الواجهة الثابتة ═══
        // إشعار داخل المشهد — فوق حافة الطاولة العلوية مباشرة
        Positioned(
          top: tbl.top - 6,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(child: _buildSceneNotice()),
          ),
        ),
        // فقاعات الشات — فوق استكانة المرسل داخل المشهد
        _buildChatBubbles(),
        Positioned(
          top: 6 + _safePadT,
          left: 14 + _safePadL,
          child: _landscapeCircleButton(
            icon: Icons.logout_rounded,
            color: const Color(0xFFFCA5A5),
            onTap: _requestExit,
          ),
        ),
        // معاينة منظور المقاعد الأربعة (وضع التصحيح فقط) — للتحقق أن
        // الحوامل والأحجار تواجه دائماً اللاعب الذي يشاهد الشاشة
        if (kDebugMode)
          Positioned(
            top: 6,
            left: 158 + _safePadL,
            child: _landscapeCircleButton(
              icon: Icons.rotate_90_degrees_ccw_rounded,
              color: const Color(0xFF93C5FD),
              onTap: () => setState(() {
                _viewerSeat = (_viewerSeat + 1) % 4;
                _showGameNotice('منظور المقعد: $_viewerSeat');
              }),
            ),
          ),
        Positioned(
          top: 10 + _safePadT,
          left: 60 + _safePadL,
          child: _buildStyleButtons(),
        ),
        // صورة الخصم الأمامي + اسمه — على ظهر الكنبة العليا حيث يجلس
        // اللاعب فعلياً (أمام حامله قليلاً)، وشريحة الدور تتراكب جانباً
        Positioned(
          top: _roomScene ? imgRect.top + imgRect.height * 0.105 : 2,
          left: _roomScene ? imgRect.left + imgRect.width * 0.52 - 46 : null,
          right: _roomScene ? null : 0,
          child: Center(child: _seatBadge(2)),
        ),
        Positioned(
          top: 7 + _safePadT,
          // مسحوب عن حافة اليمين بمقدار حاشية الجهاز + هامش مريح
          right: 16 + _safePadR,
          child: AnimatedBuilder(
            animation: Listenable.merge([VoiceService(), RadioService()]),
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // مايك التحدث داخل الغرفة
                _landscapeCircleButton(
                  icon: VoiceService().isMicOn
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  color: VoiceService().isMicOn
                      ? const Color(0xFF4ADE80)
                      : Colors.white54,
                  onTap: () async {
                    await VoiceService().toggleMic();
                    // فتح المايك يوقف الراديو حتى لا يختلط الصوتان
                    if (VoiceService().isMicOn && RadioService().isPlaying) {
                      RadioService().togglePlay();
                    }
                    _showGameNotice(
                      VoiceService().isMicOn
                          ? '🎙️ المايك مفعّل'
                          : '🔇 المايك مغلق',
                    );
                  },
                ),
                const SizedBox(width: 6),
                // الراديو داخل اللعبة — أيقونة راديو واضحة دائماً
                // (وليس نقطة مستهدفة)، واللون يدل على التشغيل
                _landscapeCircleButton(
                  icon: Icons.radio_rounded,
                  color: RadioService().isPlaying
                      ? const Color(0xFFFBBF24)
                      : Colors.white54,
                  onTap: () {
                    AppHaptics.selection();
                    RadioPlayerSheet.show(context);
                  },
                ),
                const SizedBox(width: 6),
                // السماعة: مؤثرات اللعبة
                _landscapeCircleButton(
                  icon: OkeyAudio.soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: OkeyAudio.soundEnabled
                      ? const Color(0xFF73E6A2)
                      : Colors.white54,
                  onTap: () => setState(
                      () => OkeyAudio.soundEnabled = !OkeyAudio.soundEnabled),
                ),
              ],
            ),
          ),
        ),

        // صورة الخصم الأيسر + اسمه — على مسند كنبته الداخلي المواجه
        // للطاولة حيث يجلس اللاعب ويطل على اللعب
        Positioned(
          left: _roomScene ? imgRect.left + imgRect.width * 0.252 - 25 : 10,
          top: _roomScene
              ? imgRect.top + imgRect.height * 0.370 - 22
              : tbl.center.dy - 24,
          child: _seatBadge(3),
        ),
        // صورة الخصم الأيمن + اسمه — على مسند كنبته الداخلي المواجه للطاولة
        Positioned(
          left: _roomScene ? imgRect.left + imgRect.width * 0.748 - 25 : null,
          right: _roomScene ? null : 10,
          top: _roomScene
              ? imgRect.top + imgRect.height * 0.355 - 22
              : tbl.center.dy - 24,
          child: _seatBadge(1),
        ),
        // إحصائيات الجولة — تحت صف الأزرار اليسرى حتى لا تغطي زر الخروج
        Positioned(
          left: 12 + _safePadL,
          top: _roomScene ? _imgRect(Size(sw, sh)).top + 50 : tbl.top + 4,
          child: _buildRoundStats(),
        ),
        // شريط الوقت الرفيع فوق استكانتي — يظهر أثناء دوري وينقص مع الوقت
        Positioned(
          left: _roomScene ? _mapToImg(_roomRackMineF, Size(sw, sh)).left : 210,
          right: _roomScene ? null : 210,
          width:
              _roomScene ? _mapToImg(_roomRackMineF, Size(sw, sh)).width : null,
          top: _roomScene
              ? _mapToImg(_roomRackMineF, Size(sw, sh)).top - 15
              : sh - 24 - 140 * (_rackSlotW() / 40),
          child: AnimatedOpacity(
            opacity: isHumanTurn ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: _myTurnBar('$minutes:$seconds'),
          ),
        ),
        Positioned(
          right: 8 + _safePadR,
          bottom: 8 + _safePadB,
          child: _buildLandscapeDock(),
        ),
        // ═══ طبقة احتفال الفوز — تظهر للجميع فوق الطاولة ═══
        if (_showWinCelebration && _engine.winner != null)
          Positioned.fill(
            child: OkeyWinOverlay(
              winner: _engine.winner!,
              winType: _engine.winType ?? WinType.normal,
              lastTile: () {
                final wi = _engine.players.indexOf(_engine.winner!);
                final pile = _engine.discardPiles[wi];
                return pile.isNotEmpty ? pile.last : null;
              }(),
            ),
          ),
      ],
    );
  }

  static const _konkanColor = Color(0xFFF59E0B);
  static const _fullColor = Color(0xFFC084FC);

  Color _styleColor(OkeyPlayStyle s) =>
      s == OkeyPlayStyle.full ? _fullColor : _konkanColor;

  /// زرّا كونكان / فول — يختار اللاعب أسلوبه قبل أي نزول، ثم يُقفل
  Widget _buildStyleButtons() {
    if (widget.rummyMode) return const SizedBox.shrink(); // لا أساليب في رامي
    final me = _engine.players[0];
    Widget btn(OkeyPlayStyle style) {
      final c = _styleColor(style);
      final chosen = me.playStyle == style;
      final enabled = _engine.canDeclarePlayStyle;
      if (!chosen && !enabled) return const SizedBox.shrink();
      return GestureDetector(
        onTap: () async {
          if (!enabled) return;
          AppHaptics.medium();
          final ok = await showOkeyLandscapeDialog<bool>(
            context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF141C34),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: c.withOpacity(0.6))),
              title: Text('اللعب {}؟'.trp([style.label]),
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
              content: Text(
                style == OkeyPlayStyle.full
                    ? 'تفوز بجمع لون واحد كامل: 1 2 3 … 13 1.\nأحجارك المرمية تظهر مقلوبة للجميع ولا يستطيع أحد أخذها، وأنت تستطيع أخذ أحجار غيرك.\nلن تستطيع النزول على الطاولة.'
                        .tr
                    : 'تفوز بـ 10 أحجار متسلسلة بلون واحد + بير عادي (3 أحجار فأكثر).\nلن تستطيع النزول على الطاولة.'
                        .tr,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                    color: Color(0xFFB8C4DC), fontSize: 12.5, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child:
                      Text('إلغاء'.tr, style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: c,
                      foregroundColor: const Color(0xFF1B0B30)),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text('ابدأ {}'.trp([style.label]),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          );
          if (ok == true) _engine.declarePlayStyle(style);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: chosen ? c : c.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withOpacity(chosen ? 1 : 0.6)),
            boxShadow: chosen
                ? [BoxShadow(color: c.withOpacity(0.5), blurRadius: 10)]
                : null,
          ),
          child: Text(
            chosen ? '✓ ${style.label}' : style.label,
            style: TextStyle(
                color: chosen ? const Color(0xFF1B0B30) : c,
                fontSize: 11,
                fontWeight: FontWeight.w900),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [btn(OkeyPlayStyle.konkan), btn(OkeyPlayStyle.full)],
    );
  }

  /// شارة دور اللاعب المقابل أُزيلت بطلب المستخدم — اللاعب يعرف خصمه
  /// بنفسه ولا يحتاج نصاً أحمر فوق اسمه

  Widget _buildOkeyOutButton() {
    return GestureDetector(
      onTap: () {
        AppHaptics.heavy();
        OkeyAudio.playWin();
        _engine.declareHumanWin();
      },
      child: Container(
        // زر جانبي مدمج — كان شريطاً عريضاً يغطي بيرات اللاعب على الطاولة
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 1.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withOpacity(0.8),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆', style: TextStyle(fontSize: 13)),
            SizedBox(width: 4),
            Text(
              widget.rummyMode ? 'رامي!'.tr : 'فوز!'.tr,
              style: TextStyle(
                color: Color(0xFF1B0B30),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundStats() {
    Widget stat(String value, String label, Color color) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700)),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xCC241107),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x665F3A24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.45),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          stat('${_engine.livePoints}', 'نقاطي'.tr, const Color(0xFFFFD46B)),
          const SizedBox(width: 10),
          stat('${_engine.liveGroupCount}', 'Per', const Color(0xFF86EFAC)),
          const SizedBox(width: 10),
          stat(
              widget.rummyMode || _engine.players[0].hasOpened
                  ? 'مفتوح ✓'.tr
                  : '${_engine.remainingOpeningPoints}',
              'المطلوب'.tr,
              widget.rummyMode || _engine.players[0].hasOpened
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFFCA5A5)),
        ],
      ),
    );
  }

  /// هل نقطة الإفلات فوق سطح الطاولة فعلاً (فوق مستوى الاستكانة)؟
  /// الإفلات عند مستوى الاستكانة أو أسفلها لا يُحتسب رمياً أبداً —
  /// هذا يمنع السحب السريع داخل/تحت الاستكانة من رمي الحجر بالخطأ
  bool _isOverTable(Offset dropGlobal) {
    final ctx = _sceneKey.currentContext;
    if (ctx == null) return true;
    final scene = ctx.findRenderObject() as RenderBox;
    // details.offset = زاوية صندوق الـfeedback لا الإصبع ولا المركز —
    // نضيف نصف حجم الحجر فيصل التقييم لمركزه الظاهر الفعلي
    final local = scene.globalToLocal(dropGlobal + _dropTileHalfScene);
    // وضع الغرفة: "الطاولة" = سطح الطاولة الخشبي الأمامي كاملاً —
    // إفلات الحجر على الوسائد أو خارج الطاولة لا يُحتسب رمياً
    if (_roomScene) {
      return _mapToImg(_roomTableF, _sceneSize).inflate(6).contains(local);
    }
    final rackTop = _sceneSize.height - 12 - 140 * (_rackSlotW() / 40);
    return local.dy < rackTop - 8;
  }

  /// إزاحة من زاوية صندوق الـfeedback إلى مركز الحجر الظاهر —
  /// نصف حجم حجر الرف (قيم الـfeedback تساوي مقاسه الظاهر نفسه)
  Offset get _dropTileHalfScene {
    if (_roomScene) {
      final zone = _mapToImg(_roomRackMineF, _sceneSize);
      final tileW = (((zone.width - 24) / 14).clamp(20.0, 40.0)) * 1.28;
      return Offset(tileW / 2, tileW * 1.10 / 2);
    }
    final tileW = _rackSlotW() - 2;
    return Offset(tileW / 2, tileW * 1.28 / 2);
  }

  /// إفلات حجر على سطح الطاولة (منطقة اللعب فوق الاستكانة) = رمي
  void _dropOnTable(int slot, Offset dropGlobal) {
    if (_dealing) return;
    if (!_isOverTable(dropGlobal)) return; // إفلات عند مستوى الاستكانة ≠ رمي
    if (OkeyDrag.isGroup(slot)) {
      // كتلة مرفوعة أُفلتت على الطاولة: إن كانت Per صحيحاً والشروط مستوفاة
      // تنزل — وإلا لا تُرمى أبداً، فقط تنبيه وترجع مكانها
      if (!_engine.humanCanLayMelds) {
        _showGameNotice('أنت تلعب {} — لا نزول على الطاولة'
            .trp([_engine.players[0].playStyle.label]));
        return;
      }
      final s = slot - OkeyDrag.groupBase;
      if (_engine.getHighlightedSlotIndices().contains(s)) {
        if (!_humanHasReadyPer) {
          _showGameNotice('لم تبلغ نقاط الفتح بعد — المطلوب {} نقطة'
              .trp([_engine.rules.openingPoints]));
          return;
        }
        if (_engine.layMeldContainingSlot(s)) {
          AppHaptics.medium();
        } else {
          _showGameNotice('هذه الأحجار لا تكوّن Per صحيحاً'.tr);
        }
      } else {
        _showGameNotice('لا يمكن رمي مجموعة — ارمِ حجراً واحداً'.tr);
      }
      return;
    }
    if (!OkeyDrag.isRackTile(slot)) return;
    if (_engine.currentTurnIndex != 0) {
      _showGameNotice('ليس دورك الآن!'.tr);
      return;
    }
    if (_engine.turnPhase == OkeyTurnPhase.awaitingDiscard) {
      _executeDiscard(slot, dropGlobal: dropGlobal);
    } else {
      _showGameNotice('يجب سحب حجر أولاً قبل الرمي!'.tr);
    }
  }

  // ══════════════════════════════════════════════════════
  // البير على الطاولة — كل لاعب له جهة (أنت أسفل، الخصوم أعلى/يمين/يسار)
  // الأحجار مرسومة ممدّدة على السطح بمنظور ثلاثي الأبعاد وظل
  // ══════════════════════════════════════════════════════

  /// منطقة كل مقعد على سطح الطاولة — تُحسب من مستطيل الطاولة الفعلي
  /// (نسبية لأبعاد الـViewport) وكل منطقة أمام حامل صاحبها مباشرة
  Map<int, Rect> _meldZones(Size s, Rect t) {
    // وضع الغرفة: مناطق النزول مثبتة على السجادة في الصورة —
    // أمام حامل كل لاعب مباشرة، بعيداً عن الأخدود والحوامل
    if (_roomScene) {
      return {
        0: _mapToImg(_roomMeldMineF, s),
        2: _mapToImg(_roomMeldTopF, s),
        3: _mapToImg(_roomMeldLeftF, s),
        1: _mapToImg(_roomMeldRightF, s),
      };
    }
    return {
      // المشاهد (أسفل) — أمام استكانتي مباشرة فوق حافة الطاولة السفلية
      0: Rect.fromCenter(
          center: Offset(s.width / 2, t.bottom - t.height * 0.225),
          width: t.width * 0.80,
          height: t.height * 0.20),
      // المقابل (أعلى) — أمام حامله مباشرة تحت حافة الطاولة العلوية
      2: Rect.fromCenter(
          center: Offset(s.width / 2, t.top + t.height * 0.44),
          width: t.width * 0.60,
          height: t.height * 0.20),
      // الأيسر — يمين حامله (أمامه نحو مركز الطاولة)
      3: Rect.fromCenter(
          center: Offset(t.left + t.width * 0.19, t.center.dy),
          width: t.width * 0.17,
          height: t.height * 0.52),
      // الأيمن — يسار حامله (أمامه نحو مركز الطاولة)
      1: Rect.fromCenter(
          center: Offset(t.right - t.width * 0.19, t.center.dy),
          width: t.width * 0.17,
          height: t.height * 0.52),
    };
  }

  /// كل البيرات تظهر باتجاه المشاهد على كل شاشة — كل لاعب يقرأ أحجار
  /// الجميع مستقيمة أمامه (الزاوية محلية فقط ولا تمس حالة اللعبة)
  List<Widget> _buildTableMelds(Map<int, Rect> zones) {
    final out = <Widget>[];
    for (final entry in zones.entries) {
      final seat = entry.key; // موضع المقعد على الشاشة
      final owner =
          _playerAtSeat(seat); // اللاعب الجالس فيه من منظور هذا المشاهد
      final zone = entry.value;
      final melds = <MapEntry<int, OkeyGroup>>[
        for (var i = 0; i < _engine.tableMelds.length; i++)
          if (_engine.tableMelds[i].ownerIndex == owner)
            MapEntry(i, _engine.tableMelds[i]),
      ];
      final isMine = owner == 0;
      final content = melds.isEmpty
          ? (isMine && _humanHasReadyPer
              ? _myMeldHint()
              : const SizedBox.shrink())
          : _meldsOnTable(melds, zone, seat: seat);
      out.add(Positioned.fromRect(
        rect: zone,
        child: isMine ? _myMeldDropZone(content) : content,
      ));
    }
    return out;
  }

  /// خانة الرف من قيمة السحب (حجر مفرد أو كتلة)، أو -1
  int _rackSlotOf(int data) => OkeyDrag.isRackTile(data)
      ? data
      : (OkeyDrag.isGroup(data) ? data - OkeyDrag.groupBase : -1);

  /// شروط النزول مستوفاة: أسلوب عادي + يوجد Per صحيح مميّز على الرف،
  /// وقبل أول نزول يجب بلوغ نقاط الافتتاح (معلّقة الطاولة + جاهزة الرف).
  /// المستطيل يبقى مخفياً حتى يتحقق هذا — لا نزول ولا إسقاط قبله
  bool get _humanHasReadyPer {
    if (!_engine.humanCanLayMelds) return false;
    if (_engine.getHighlightedSlotIndices().isEmpty) return false;
    return _engine.players[0].hasOpened ||
        _engine.livePoints >= _engine.rules.openingPoints;
  }

  /// منطقتك: إسقاط Per مميّز هنا = نزول على الطاولة
  Widget _myMeldDropZone(Widget child) {
    return DragTarget<int>(
      // لا يُقبل هنا إلا حجر ضمن Per صحيح جاهز للنزول وبعد استيفاء
      // شروط النزول كاملة (المستطيل مخفي حتى ذلك) — غيره يرفض ويعود للرف
      onWillAcceptWithDetails: (details) {
        final slot = _rackSlotOf(details.data);
        return slot != -1 &&
            _humanHasReadyPer &&
            _engine.getHighlightedSlotIndices().contains(slot);
      },
      onAcceptWithDetails: (details) {
        final slot = _rackSlotOf(details.data);
        if (_engine.layMeldContainingSlot(slot)) {
          AppHaptics.medium();
        } else {
          _showGameNotice('هذه الأحجار لا تكوّن Per صحيحاً'.tr);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: hovering ? const Color(0x3334D399) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hovering ? const Color(0xFF6EE7B7) : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: child,
        );
      },
    );
  }

  Widget _myMeldHint() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Text(
            _engine.humanCanLayMelds
                ? 'اسحب الـ Per هنا لتنزله على الطاولة'.tr
                : 'تلعب {} — أكمل يدك وأعلن الفوز'
                    .trp([_engine.players[0].playStyle.label]),
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 8.5,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  static const double _meldTileW = 40, _meldTileH = 46;

  /// بلا تراكب — كل حجر ظاهر كاملاً (الرقم والنقطة)؛ التراكب السابق
  /// كان يخفي جزءاً من كل حجر
  static const double _meldOverlap = 1.0;

  // OkeyTileWidget يضيف هامش 1px من كل جانب ⇒ عرض الحجر الفعلي +2
  static double _meldWidth(int n) =>
      (n - 1) * (_meldTileW + 2) * _meldOverlap + _meldTileW + 2 + 4;

  /// بيرات لاعب واحد مصفوفة بأناقة داخل منطقته فقط — لا تتجاوزها أبداً.
  /// الصفوف تتداخل قليلاً عمودياً (الرقم في النصف العلوي فيبقى مقروءاً)
  /// والمقياس يجوز تجاوز ×1 للبيرات القليلة فتظهر أكبر — مثل طاولة
  /// حقيقية تكبّر فيها الأحجار كلما قلّ عددها. الجانبيان: صفوف مرصوفة
  /// نحو صاحبه. المقابل وأنا: صفوف متوسطة.
  // صفوف منفصلة بفراغ صغير — الصف التالي لا يغطي نقاط الصف الذي فوقه
  static const double _meldRowPitch = 1.06;
  static const double _meldMaxScale = 1.4; // سقف التكبير للبيرات القليلة

  Widget _meldsOnTable(List<MapEntry<int, OkeyGroup>> melds, Rect zone,
      {required int seat}) {
    final rows = [for (final m in melds) _meld3D(m.key, m.value)];
    const spacing = 6.0;
    const rowH = _meldTileH + 4 + 2.4;
    const pitch = rowH * _meldRowPitch;
    final widths = [for (final m in melds) _meldWidth(m.value.tiles.length)];
    // نبحث عن عرض الالتفاف الذي يعطي أكبر مقياس ممكن داخل المنطقة —
    // فتبقى الأحجار بأكبر حجم مقروء مهما كثرت البيرات (بدل تصغير ثابت)
    final widest = widths.reduce(math.max);
    final total =
        widths.fold<double>(0, (s, w) => s + w) + spacing * (widths.length - 1);
    var bestW = total, bestScale = 0.0;
    for (var wrapW = widest; wrapW <= total + 0.5; wrapW += 6) {
      var lines = 1;
      var lineW = 0.0;
      var usedW = 0.0;
      for (final w in widths) {
        final next = lineW == 0 ? w : lineW + spacing + w;
        if (next > wrapW + 0.01 && lineW > 0) {
          usedW = math.max(usedW, lineW);
          lines++;
          lineW = w;
        } else {
          lineW = next;
        }
      }
      usedW = math.max(usedW, lineW);
      final h = rowH + (lines - 1) * pitch;
      final scale = math.min(
          _meldMaxScale, math.min(zone.width / usedW, zone.height / h));
      if (scale > bestScale + 0.001) {
        bestScale = scale;
        bestW = wrapW;
      }
    }

    // تقسيم البيرات إلى صفوف على العرض الفائز
    final lines = <List<int>>[[]];
    final lineWidths = <double>[];
    var lineW = 0.0;
    for (var i = 0; i < widths.length; i++) {
      final w = widths[i];
      final next = lineW == 0 ? w : lineW + spacing + w;
      if (next > bestW + 0.01 && lineW > 0) {
        lineWidths.add(lineW);
        lines.add([i]);
        lineW = w;
      } else {
        lines.last.add(i);
        lineW = next;
      }
    }
    lineWidths.add(lineW);
    final usedW = lineWidths.reduce(math.max);
    final contentH = rowH + (lines.length - 1) * pitch;

    final align = switch (seat) {
      3 => Alignment.centerLeft,
      1 => Alignment.centerRight,
      2 => Alignment.bottomCenter,
      _ => Alignment.topCenter,
    };
    // FittedBox يمرّر للمحتوى قيوداً حرّة فيُرسم بكامل عرضه ثم يُصغَّر —
    // Transform.scale السابق كان يضغط الـSizedBox لعرض المنطقة أولاً
    // فيقصّ الـStack أطراف البيرات قبل التصغير فيختفي جزء منها
    return Align(
      alignment: align,
      child: SizedBox(
        width: usedW * bestScale,
        height: contentH * bestScale,
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: usedW,
            height: contentH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var r = 0; r < lines.length; r++)
                  Positioned(
                    top: r * pitch,
                    left: seat == 3
                        ? 0
                        : seat == 1
                            ? usedW - lineWidths[r]
                            : (usedW - lineWidths[r]) / 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < lines[r].length; c++) ...[
                          if (c > 0) const SizedBox(width: spacing),
                          rows[lines[r][c]],
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بير واحد: أحجار متلاصقة بسماكة وظل، وتقبل صرف حجر عليها
  Widget _meld3D(int meldIndex, OkeyGroup meld) {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => OkeyDrag.isRackTile(details.data),
      onAcceptWithDetails: (details) {
        // الحجر يمثّل الجوكر في هذا البير؟ ضعه مكانه وخذ الجوكر لرفّك
        if (_engine.swapJokerFromMeld(details.data, meldIndex)) {
          AppHaptics.medium();
          return;
        }
        // وإلا جرّب الصرف على البير (المحرك يتحقق: الفتح/الدور/صحة الحجر)
        if (_engine.layTileOnMeld(details.data, meldIndex)) {
          AppHaptics.light();
          return;
        }
        // فشل الصرف — حدّد السبب للمستخدم بدل رمي الحجر بالخطأ
        if (_engine.currentTurnIndex != 0) {
          _showGameNotice('ليس دورك الآن!'.tr);
        } else if (!_engine.players[0].hasOpened &&
            !(meld.ownerIndex == 0 && meld.pending)) {
          _showGameNotice(
              'افتح اللعب أولاً (نزّل {} نقطة) قبل الصرف على بيرات غيرك'
                  .trp([_engine.rules.openingPoints]));
        } else {
          _showGameNotice('هذا الحجر لا يصرف على هذا البير'.tr);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        // الأحجار مستلقية على الطاولة مباشرة بلا صندوق داكن — إطار خفيف
        // يظهر فقط عند التحويم (أخضر) أو للبير المعلّق (ذهبي)
        final outline = hovering
            ? const Color(0xFF6EE7B7)
            : meld.pending
                ? const Color(0xFFFBBF24)
                : null;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: hovering ? const Color(0x2234D399) : Colors.transparent,
            border: Border.all(
                color: outline?.withOpacity(0.85) ?? Colors.transparent,
                width: 1.2),
          ),
          child: Container(
            // ظل مشترك ناعم تحت صف الأحجار كأنها قطعة واحدة على القماش
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.38),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < meld.tiles.length; k++)
                  Align(
                    // تراكب: كل حجر يحجز 72% من عرضه والتالي يغطي حافته
                    alignment: Alignment.centerLeft,
                    widthFactor:
                        k == meld.tiles.length - 1 ? 1.0 : _meldOverlap,
                    child: Container(
                      // سماكة الحجر: حافة سفلية عاجية داكنة + ظل جانبي
                      // خفيف يفصل الحجر عن الذي تحته
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          const BoxShadow(
                              color: Color(0xFFB9A57A),
                              offset: Offset(0, 2.2),
                              blurRadius: 0),
                          if (k > 0)
                            BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                offset: const Offset(-1.5, 0),
                                blurRadius: 2),
                        ],
                      ),
                      child: OkeyTileWidget(
                          tile: meld.tiles[k],
                          width: _roomScene ? _meldTileW : 26,
                          height: _roomScene ? _meldTileH : 32),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// زر الإعدادات الوحيد أسفل اليمين — يفتح عمود الأدوات للأعلى
  /// بأنيميشن منبثقة ويُغلق بنفس الطريقة (ينكمش في زر واحد)
  Widget _buildLandscapeDock() {
    final items = [
      (
        Icons.swap_vert_rounded,
        'Sırala',
        () {
          AppHaptics.selection();
          OkeyAudio.playSort();
          _engine.sortHumanTiles();
          _showGameNotice('تم ترتيب المجموعات المتتالية! ✨'.tr);
        }
      ),
      (
        Icons.auto_awesome_rounded,
        'Otomatik',
        () {
          AppHaptics.selection();
          OkeyAudio.playSort();
          _engine.sortHumanTilesBySets();
          _showGameNotice('تم ترتيب المجموعات المتشابهة! 🎯'.tr);
        }
      ),
      (
        Icons.chat_bubble_outline_rounded,
        'Chat',
        () {
          AppHaptics.selection();
          OkeyAudio.playButtonClick();
          OkeyChatDialog.show(context);
        }
      ),
      (
        Icons.settings_rounded,
        'Settings',
        () {
          AppHaptics.selection();
          OkeyAudio.playButtonClick();
          OkeySettingsDialog.show(context,
              onStateChanged: () => setState(() {}));
        }
      ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // عمود الأدوات — ينبثق للأعلى عند الفتح
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutBack,
          alignment: Alignment.bottomCenter,
          child: !_dockExpanded
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: 60,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xEE151922),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          _buildDockButton(
                            icon: items[i].$1,
                            label: items[i].$2,
                            onTap: () {
                              setState(() => _dockExpanded = false);
                              items[i].$3();
                            },
                          ),
                          if (i < items.length - 1)
                            _buildDockDivider(vertical: true),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        // زر الإعدادات الرئيسي — يدور ربع دورة عند الانفتاح
        GestureDetector(
          onTap: () {
            AppHaptics.selection();
            OkeyAudio.playButtonClick();
            setState(() => _dockExpanded = !_dockExpanded);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _dockExpanded
                  ? const Color(0xFF2A3348)
                  : const Color(0xEE151922),
              border: Border.all(
                color: _dockExpanded
                    ? const Color(0xFF4ADE80).withOpacity(0.8)
                    : Colors.white24,
                width: _dockExpanded ? 1.6 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
                if (_dockExpanded)
                  BoxShadow(
                      color: const Color(0xFF4ADE80).withOpacity(0.3),
                      blurRadius: 14),
              ],
            ),
            child: AnimatedRotation(
              turns: _dockExpanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: Icon(
                _dockExpanded ? Icons.close_rounded : Icons.settings_rounded,
                color: _dockExpanded ? const Color(0xFF86EFAC) : Colors.white70,
                size: 21,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// شريط الوقت الرفيع فوق استكانتي — ينقص كل ثانية ويحمر قرب النفاد
  Widget _myTurnBar(String timerString) {
    final remain = _engine.turnTimeRemaining;
    final low = remain <= 10;
    final c = low ? const Color(0xFFEF4444) : const Color(0xFF4ADE80);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timerString,
          style: TextStyle(
              color: c,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              height: 1.0,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 4)]),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 5,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (remain / _engine.turnDuration).clamp(0.0, 1.0),
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(c),
            ),
          ),
        ),
      ],
    );
  }

  /// صورة خصم + اسمه + حلقة وقت دائرية فوقها — موجّهة لي أنا مهما كان مقعده
  Widget _seatBadge(int seat) {
    // seat = موضع المقعد على الشاشة؛ اللاعب الظاهر فيه يعتمد على مقعد المشاهد
    final playerIndex = _playerAtSeat(seat);
    final p = _engine.players[playerIndex];
    final isTurn = !_dealing && _engine.currentTurnIndex == playerIndex;
    final low = _engine.turnTimeRemaining <= 10;
    final ringColor = low ? const Color(0xFFEF4444) : const Color(0xFF4ADE80);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // حلقة الوقت المتبقي — ملتصقة بالصورة، رفيعة وخافتة
              if (isTurn)
                SizedBox(
                  width: 38,
                  height: 38,
                  child: CircularProgressIndicator(
                    value: (_engine.turnTimeRemaining / _engine.turnDuration)
                        .clamp(0.0, 1.0),
                    strokeWidth: 1.8,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  ),
                ),
              _seatAvatar(p, seat, isTurn),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            p.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                height: 1.1),
          ),
        ),
        // شارة أسلوب اللعب (كونكان/فول) تحت الاسم
        if (p.playStyle != OkeyPlayStyle.normal)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: _styleColor(p.playStyle),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              p.playStyle.label,
              style: const TextStyle(
                  color: Color(0xFF1B0B30),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900),
            ),
          ),
      ],
    );
  }

  /// أفاتار اللاعب — صورته الحقيقية أو أول حرف من اسمه، باتجاه الشاشة دائماً
  Widget _seatAvatar(OkeyPlayer p, int seat, bool isTurn) {
    const seatColors = [
      Color(0xFF4ADE80),
      Color(0xFF60A5FA),
      Color(0xFFF472B6),
      Color(0xFFFBBF24),
    ];
    final color = seatColors[seat % seatColors.length];
    final letter = p.name.isNotEmpty ? p.name.characters.first : '?';
    final url = p.avatarUrl;
    Widget face;
    if (url.startsWith('http')) {
      face = Image.network(url,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
              child: Text(letter,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800))));
    } else if (url.startsWith('assets/')) {
      face = Image.asset(url,
          width: 34,
          height: 34,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
              child: Text(letter,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800))));
    } else {
      face = Center(
          child: Text(letter,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)));
    }
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF2E384D),
        border: Border.all(
          color: isTurn ? const Color(0xFF4ADE80) : color,
          width: isTurn ? 2.0 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 6,
              offset: const Offset(0, 2)),
          if (isTurn)
            BoxShadow(
                color: const Color(0xFF4ADE80).withOpacity(0.45),
                blurRadius: 10),
        ],
      ),
      child: ClipOval(child: face),
    );
  }

  Widget _landscapeCircleButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: const Color(0xDD151922),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 6)
            ]),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget buildPortraitLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final sw = size.width;
    final sh = size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom;

    final isHumanTurn = _engine.currentTurnIndex == 0;
    final minutes =
        (_engine.turnTimeRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_engine.turnTimeRemaining % 60).toString().padLeft(2, '0');
    final timerString = '$minutes:$seconds';

    // حجم منطقة الطاولة المربعة في المنتصف
    final tableSize = sw * 0.88;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ══════════════════════════════════════════════
        // 1. خلفية الغرفة
        // ══════════════════════════════════════════════
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, 0),
              radius: 1.2,
              colors: [Color(0xFF111827), Color(0xFF090D17), Color(0xFF04060B)],
              stops: [0.0, 0.65, 1.0],
            ),
          ),
        ),

        // ══════════════════════════════════════════════
        // 2. شريط علوي: زر المزيد + شارة الخصم العلوي + زر الصوت
        // ══════════════════════════════════════════════
        Positioned(
          top: 6,
          left: 8,
          right: 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // زر المزيد
              GestureDetector(
                onTap: _showMoreMenu,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xEB1A1E29),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0x50FFD54F), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_rounded,
                          color: Color(0xFFFFD54F), size: 15),
                      SizedBox(width: 5),
                      Text('المزيد'.tr,
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5)),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // شارة اللاعب العلوي (الخصم المواجه)
              OkeyPlayerBadge(
                player: _engine.players[2],
                isTurn: _engine.currentTurnIndex == 2,
                type: PlayerBadgeType.top,
              ),
              const Spacer(),
              // أزرار الراديو والمايك والصوت
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // زر الراديو الشخصي
                  GestureDetector(
                    onTap: () => RadioPlayerSheet.show(context),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xEB1A1E29),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0x40FFD54F), width: 1),
                      ),
                      child: const Icon(Icons.radio_rounded,
                          color: Color(0xFFFFD54F), size: 16),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // زر المايك للتحدث مع الآخرين
                  AnimatedBuilder(
                    animation: VoiceService(),
                    builder: (context, _) {
                      final voice = VoiceService();
                      return GestureDetector(
                        onTap: () async {
                          final on = await voice.toggleMic();
                          if (!context.mounted) return;
                          _showGameNotice(
                            on
                                ? 'تم تشغيل المايك 🎙️ تحدث الآن'.tr
                                : 'تم كتم المايك 🔇'.tr,
                            icon: on ? Icons.mic : Icons.mic_off,
                          );
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: voice.isMicOn
                                ? const Color(0xFF10B981)
                                : const Color(0xEB1A1E29),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: voice.isSpeaking
                                  ? Colors.white
                                  : const Color(0x334B5563),
                              width: voice.isSpeaking ? 2 : 1,
                            ),
                            boxShadow: voice.isSpeaking
                                ? [
                                    BoxShadow(
                                        color: const Color(0xFF10B981)
                                            .withOpacity(0.8),
                                        blurRadius: 8,
                                        spreadRadius: 1)
                                  ]
                                : null,
                          ),
                          child: Icon(
                            voice.isMicOn ? Icons.mic : Icons.mic_off,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  // زر الصوت
                  GestureDetector(
                    onTap: () {
                      AppHaptics.selection();
                      setState(() =>
                          OkeyAudio.soundEnabled = !OkeyAudio.soundEnabled);
                      _showGameNotice(
                        OkeyAudio.soundEnabled
                            ? 'تم تشغيل الصوت 🔊'.tr
                            : 'تم كتم الصوت 🔇'.tr,
                        icon: OkeyAudio.soundEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xEB1A1E29),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0x334B5563), width: 1),
                      ),
                      child: Icon(
                        OkeyAudio.soundEnabled
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        color: OkeyAudio.soundEnabled
                            ? const Color(0xFF4ADE80)
                            : Colors.white60,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ══════════════════════════════════════════════
        // 3. استكانة الخصم العلوي تحت الشريط العلوي
        // ══════════════════════════════════════════════
        Positioned(
          top: 54,
          left: 0,
          right: 0,
          child: Center(
            child: OkeyOpponentIstaka(
              position: OpponentPosition.top,
              tileCount: _engine.players[2].tileCount,
              isTurn: _engine.currentTurnIndex == 2,
            ),
          ),
        ),

        // ══════════════════════════════════════════════
        // 4. منطقة الطاولة الوسطى (مربعة)
        // ══════════════════════════════════════════════
        Positioned(
          top: sh * 0.17,
          left: (sw - tableSize) / 2,
          child: SizedBox(
            width: tableSize,
            height: tableSize * 0.72,
            child: Stack(
              children: [
                // سطح الطاولة الخشبية
                Positioned.fill(
                  child: CustomPaint(
                    painter: OkeyTablePainter(isHumanTurn: isHumanTurn),
                  ),
                ),

                // الخصم الأيسر داخل الطاولة
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OkeyPlayerBadge(
                          player: _engine.players[3],
                          isTurn: _engine.currentTurnIndex == 3,
                          type: PlayerBadgeType.left,
                        ),
                        const SizedBox(height: 6),
                        OkeyOpponentIstaka(
                          position: OpponentPosition.left,
                          tileCount: _engine.players[3].tileCount,
                          isTurn: _engine.currentTurnIndex == 3,
                        ),
                      ],
                    ),
                  ),
                ),

                // الخصم الأيمن داخل الطاولة
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OkeyPlayerBadge(
                          player: _engine.players[1],
                          isTurn: _engine.currentTurnIndex == 1,
                          type: PlayerBadgeType.right,
                        ),
                        const SizedBox(height: 6),
                        OkeyOpponentIstaka(
                          position: OpponentPosition.right,
                          tileCount: _engine.players[1].tileCount,
                          isTurn: _engine.currentTurnIndex == 1,
                        ),
                      ],
                    ),
                  ),
                ),

                // مركز الطاولة: مؤشر + رمي الأحجار + سحب
                Positioned.fill(
                  child: Center(
                    child: _buildTableCenter(isHumanTurn),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ══════════════════════════════════════════════
        // 4.5. زر إعلان الفوز بالأوكي — جانبي صغير مثل مشهد الغرفة
        // ══════════════════════════════════════════════
        if (_engine.canDeclareOkeyOut)
          Positioned(
            right: 10 + _safePadR,
            bottom: 62 + _safePadB,
            child: _buildOkeyOutButton(),
          ),

        // ══════════════════════════════════════════════
        // 5. استكانة اللاعب البشري (الرف السفلي)
        // ══════════════════════════════════════════════
        Positioned(
          left: 0,
          right: 0,
          bottom: 52,
          child: OkeyIstakaWidget(
            rackTiles: _engine.players[0].rackTiles,
            selectedIndex: _engine.selectedTileIndex,
            isTurn: isHumanTurn,
            highlightedIndices: _engine.getHighlightedSlotIndices(),
            rackItem: StoreService().equippedFor(StoreCategory.rack),
            onTileTap: _handleTileTap,
            onTileMove: (fromSlot, toSlot) =>
                _engine.moveTile(fromSlot, toSlot),
          ),
        ),

        // ══════════════════════════════════════════════
        // 6. شريط الأزرار السفلي
        // ══════════════════════════════════════════════
        Positioned(
          bottom: 6,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // بطاقة اللاعب
              _buildBottomPlayerBadge(timerString, isHumanTurn),
              const Spacer(),
              // أزرار الترتيب والدردشة
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xEB1A1E29),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x334B5563), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDockButton(
                      icon: Icons.swap_vert_rounded,
                      label: 'Sırala',
                      onTap: () {
                        AppHaptics.selection();
                        OkeyAudio.playSort();
                        _engine.sortHumanTiles();
                        _showGameNotice('تم ترتيب المجموعات المتتالية! ✨'.tr);
                      },
                    ),
                    _buildDockDivider(),
                    _buildDockButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Otomatik',
                      onTap: () {
                        AppHaptics.selection();
                        OkeyAudio.playSort();
                        _engine.sortHumanTilesBySets();
                        _showGameNotice('تم ترتيب المجموعات المتشابهة! 🎯'.tr);
                      },
                    ),
                    _buildDockDivider(),
                    _buildDockButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Chat',
                      onTap: () {
                        AppHaptics.selection();
                        OkeyAudio.playButtonClick();
                        OkeyChatDialog.show(context);
                      },
                    ),
                    _buildDockDivider(),
                    _buildDockButton(
                      icon: Icons.settings_rounded,
                      label: 'إعدادات'.tr,
                      onTap: () {
                        AppHaptics.selection();
                        OkeyAudio.playButtonClick();
                        OkeySettingsDialog.show(context,
                            onStateChanged: () => setState(() {}));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ══════════════════════════════════════════════
        // 7. أنيميشن رمي الحجر
        // ══════════════════════════════════════════════
        if (_animatingDiscardTile != null)
          AnimatedBuilder(
            animation: _discardCurve,
            builder: (context, _) {
              final t = _discardCurve.value;
              final startX = sw * 0.5;
              final startY = sh * 0.82;
              final targetX = sw * 0.5;
              final targetY = sh * 0.44;
              final currentX = startX + (targetX - startX) * t;
              final arcLift = math.sin(t * math.pi) * 50;
              final currentY = startY + (targetY - startY) * t - arcLift;
              final scale = 1.0 + 0.22 * math.sin(t * math.pi);
              final rotation = 0.18 * math.sin(t * math.pi);

              return Positioned(
                left: currentX - 14,
                top: currentY - 20,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scale: scale,
                    child: Material(
                      color: Colors.transparent,
                      elevation: 8,
                      child: OkeyTileWidget(
                        tile: _animatingDiscardTile,
                        isDragging: true,
                        width: 28,
                        height: 38,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

        // ══════════════════════════════════════════════
        // 8. أنيميشن سحب حجر جديد
        // ══════════════════════════════════════════════
        if (_animatingDrawTile != null)
          AnimatedBuilder(
            animation: _drawCurve,
            builder: (context, _) {
              final t = _drawCurve.value;
              final startX = sw * 0.5;
              final startY = sh * 0.44;
              final targetX = sw * 0.5;
              final targetY = sh * 0.82;
              final currentX = startX + (targetX - startX) * t;
              final arcLift = math.sin(t * math.pi) * 35;
              final currentY = startY + (targetY - startY) * t - arcLift;

              return Positioned(
                left: currentX - 14,
                top: currentY - 20,
                child: Transform.scale(
                  scale: 1.0 + 0.2 * math.sin(t * math.pi),
                  child: Material(
                    color: Colors.transparent,
                    child: OkeyTileWidget(
                      tile: _animatingDrawTile,
                      isDragging: true,
                      width: 28,
                      height: 38,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  مركز الطاولة: مؤشر + رمي + سحب
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  //  مركز الطاولة: المؤشر + رزمة السحب الطولية + شريط الرمي (للجميع)
  // ─────────────────────────────────────────────

  /// مقاس حجر الـ feedback عند السحب من الرزمة — يطابق حجر الاستكانة
  static const double _rackTileW = 38;
  static const double _rackTileH = 38 * 1.28;

  Widget _buildTableCenter(bool isHumanTurn) {
    final canDraw =
        isHumanTurn && _engine.turnPhase == OkeyTurnPhase.awaitingDraw;
    final canDiscard =
        isHumanTurn && _engine.turnPhase == OkeyTurnPhase.awaitingDiscard;
    final leftPile = _engine.discardPiles[3];
    bool hidden(int i) =>
        i != 0 && _engine.players[i].playStyle == OkeyPlayStyle.full;
    final canTakeLeft = canDraw && leftPile.isNotEmpty && !hidden(3);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // رامي: لا يوجد مؤشر — الورقة المكشوفة ضمن كومة الرمي
        if (!widget.rummyMode) ...[
          _buildIndicator(),
          const SizedBox(width: 8),
        ],
        _buildDrawTower(canDraw),
        const SizedBox(width: 10),
        // كومة رمي موحّدة مبعثرة لكل اللاعبين — مثل طاولة حقيقية
        _buildScatterPile(
            canDraw: canDraw, canDiscard: canDiscard, canTakeLeft: canTakeLeft),
      ],
    );
  }

  /// كومة المرميات: أحجار مقلوبة مبعثرة بمواضع ثابتة (صورة كومة ثابتة
  /// لا تتبدل مع كل رمية)، وفوقها يظهر آخر حجر رُمي على الطاولة من أي
  /// لاعب. حجر اليسار الأخير وحده قابل للأخذ (توهّج أخضر + لمس أو سحب)،
  /// ومرميات الفول تبقى مقلوبة. بلا خلفية — الأحجار على السجادة مباشرة.
  Widget _buildScatterPile({
    required bool canDraw,
    required bool canDiscard,
    required bool canTakeLeft,
  }) {
    // الحجر العلوي = آخر رمية فعلية على الطاولة (يتتبّعها المحرك ويمسحها
    // عند أخذها) — لا يُشتق من قمم الكومات فلا يقفز حجر قديم مكان المأخوذ
    final topTile = _engine.lastDiscardTile;
    final topOwner = _engine.lastDiscardPlayer;
    final topIsFull = topOwner > 0 &&
        _engine.players[topOwner].playStyle == OkeyPlayStyle.full;
    final total = _engine.discardPiles.fold<int>(0, (s, p) => s + p.length);

    final w = _roomScene ? 100.0 : 140.0;
    final h = _roomScene ? 76.0 : 92.0;
    final tw = _roomScene ? 36.0 : 24.0;
    final th = _roomScene ? 43.0 : 30.0;
    // مركز الكومة داخل الحيّز
    final cx = w * 0.5, cy = h * 0.52;
    // مواضع ثابتة للأحجار المقلوبة (إزاحة X، إزاحة Y، زاوية) — الكومة
    // تبقى ثابتة الشكل دائماً ولا تنكمش عند أخذ حجر منها
    const backSlots = [
      (-12.0, 5.0, -0.28),
      (10.0, 1.0, 0.22),
      (-4.0, -4.0, -0.12),
      (13.0, 9.0, 0.38),
      (1.0, -1.0, 0.05),
    ];
    // الكومة الزخرفية ثابتة بأحجارها الخمسة ما دام في الطاولة مرميات —
    // لا تختفي ولا تتغير مع السحب أو الأخذ
    final backs = total > 0 ? backSlots.length : 0;

    final children = <Widget>[
      // عداد الأحجار المرمية — خافت تحت الكومة
      Positioned(
        left: 2,
        bottom: 1,
        child: Text('$total',
            style: TextStyle(
                color: Colors.white.withOpacity(0.30),
                fontSize: 8,
                fontWeight: FontWeight.w900)),
      ),
    ];
    // الأحجار المقلوبة بمواضعها الثابتة
    for (var i = 0; i < backs; i++) {
      final s = backSlots[i];
      children.add(Positioned(
        left: cx - tw / 2 + s.$1,
        top: cy - th / 2 + s.$2,
        child: Transform.rotate(angle: s.$3, child: _tileBack(tw, th)),
      ));
    }
    // آخر حجر مرمي فوق الكومة كلها — مكشوفاً (أو مقلوباً إن كان للفول)
    if (topTile != null) {
      Widget top = topIsFull
          ? _tileBack(tw, th)
          : OkeyTileWidget(tile: topTile, width: tw, height: th);
      if (!topIsFull && canTakeLeft && topOwner == 3) {
        top = Draggable<int>(
          key: _leftDiscardKey,
          data: OkeyDrag.leftPile,
          maxSimultaneousDrags: 1,
          onDragStarted: () => AppHaptics.selection(),
          dragAnchorStrategy: (d, c, p) => const Offset(_rackTileW / 2,
              _rackTileH / 2 + _rackTileH * OkeyIstakaWidget.dragLiftFactor),
          feedback: Material(
            color: Colors.transparent,
            elevation: 10,
            child: OkeyTileWidget(
                tile: topTile,
                isDragging: true,
                width: _rackTileW,
                height: _rackTileH),
          ),
          childWhenDragging: Opacity(opacity: 0.25, child: top),
          child: GestureDetector(
            onTap: _executeDrawFromLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF4ADE80).withOpacity(0.75),
                      blurRadius: 9,
                      spreadRadius: 1.5),
                ],
              ),
              child: top,
            ),
          ),
        );
      }
      children.add(Positioned(
        left: cx - tw / 2 + 1,
        top: cy - th / 2 - 3,
        child: top,
      ));
    }

    return GestureDetector(
      onTap: () {
        if (canDiscard && _engine.selectedTileIndex != null) {
          _executeDiscard(_engine.selectedTileIndex!);
        } else {
          _showDiscardViewer();
        }
      },
      onLongPress: _showDiscardViewer,
      child: SizedBox(
        key: _discardKey,
        width: w,
        height: h,
        child: total == 0
            ? Center(
                child: Icon(Icons.layers_clear_rounded,
                    color: Colors.white.withOpacity(0.14), size: 22))
            : Stack(
                clipBehavior: Clip.none,
                children: children,
              ),
      ),
    );
  }

  /// نافذة عرض مرميات كل لاعب — للاطلاع فقط، لا يمكن أخذ أي حجر منها
  void _showDiscardViewer() {
    final total = _engine.discardPiles.fold<int>(0, (s, p) => s + p.length);
    if (total == 0) {
      _showGameNotice('لا أحجار مرمية بعد'.tr,
          icon: Icons.layers_clear_rounded);
      return;
    }
    AppHaptics.selection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: AppLangController.instance.direction,
        child: Container(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
          decoration: BoxDecoration(
            color: const Color(0xFF141C34),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.3)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.layers_rounded,
                    color: Color(0xFFFFD54F), size: 18),
                const SizedBox(width: 8),
                Text('الأحجار المرمية'.tr,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('$total',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('للاطلاع فقط — لا يمكن أخذ الأحجار من هنا'.tr,
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 10.5)),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (var p = 0; p < 4; p++)
                      if (_engine.discardPiles[p].isNotEmpty)
                        _discardViewerRow(p),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _discardViewerRow(int p) {
    final pile = _engine.discardPiles[p];
    final isFull = p != 0 && _engine.players[p].playStyle == OkeyPlayStyle.full;
    final colors = [
      const Color(0xFF4ADE80),
      const Color(0xFF38BDF8),
      const Color(0xFFF472B6),
      const Color(0xFFFBBF24),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors[p].withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.person_rounded, color: colors[p], size: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                p == 0 ? 'أنت'.tr : _engine.players[p].name,
                style: TextStyle(
                    color: colors[p],
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('${pile.length}',
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final t in pile)
                isFull
                    ? _tileBack(18, 25)
                    : OkeyTileWidget(tile: t, width: 18, height: 25),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator() {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        final indColor = _engine.indicatorTile.color.displayName;
        final okeyColor = _engine.realOkeySample.color.displayName;
        _showGameNotice(
          'المؤشر: {} {} | الأوكي: {} {}'.trp([
            indColor,
            _engine.indicatorTile.value,
            okeyColor,
            _engine.realOkeySample.value
          ]),
          icon: Icons.star_rounded,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: const Color(0xFFFFB300).withOpacity(0.25),
                    blurRadius: 10,
                    spreadRadius: 1),
              ],
            ),
            child: OkeyTileWidget(
                tile: _engine.indicatorTile,
                width: _roomScene ? 36 : 24,
                height: _roomScene ? 48 : 33),
          ),
          const SizedBox(height: 3),
          Text('مؤشر'.tr,
              style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  /// ظهر الحجر (مقلوب) — للرزمة وللحجر المسحوب منها
  Widget _tileBack(double w, double h, {bool glow = false}) {
    if (widget.rummyMode) return _cardBack(w, h, glow: glow);
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFDF5), Color(0xFFEDE0C4), Color(0xFFD6C29E)],
        ),
        borderRadius: BorderRadius.circular(w * 0.12),
        border: Border.all(color: const Color(0xFFC4B28F), width: 0.7),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 3,
              offset: const Offset(0, 2)),
          if (glow)
            BoxShadow(
                color: const Color(0xFF4ADE80).withOpacity(0.55),
                blurRadius: 10),
        ],
      ),
      child: Center(
        child: Container(
          width: w * 0.42,
          height: w * 0.42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: const Color(0xFFB89A62).withOpacity(0.7), width: 1),
          ),
        ),
      ),
    );
  }

  /// ظهر ورقة اللعب (رامي): كحلي بنمط معينات بيضاء — مثل أوراق الشدة الحقيقية
  Widget _cardBack(double w, double h, {bool glow = false}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B4C8C), Color(0xFF1A2F5E), Color(0xFF101E42)],
        ),
        borderRadius: BorderRadius.circular(w * 0.14),
        border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 3,
              offset: const Offset(0, 2)),
          if (glow)
            BoxShadow(
                color: const Color(0xFF4ADE80).withOpacity(0.55),
                blurRadius: 10),
        ],
      ),
      child: Center(
        child: Container(
          width: w * 0.55,
          height: w * 0.55,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white54, width: 0.8),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: Text(
              '◆',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: w * 0.3,
                  height: 1),
            ),
          ),
        ),
      ),
    );
  }

  /// رزمة السحب: برج طولي من الأحجار المتراصة — المس للسحب أو اسحب إلى رفّك
  Widget _buildDrawTower(bool canDraw) {
    final remaining = _engine.drawDeck.length;
    // رزمة فارغة لكن المرميات تكفي لإعادة الخلط → السحب يبقى ممكناً
    final refillable = remaining == 0 && _engine.canRefillDeck;
    final drawable = canDraw && (remaining > 0 || refillable);
    final layers = (remaining / 6).ceil().clamp(1, 5);
    final w = _roomScene ? 44.0 : 30.0;
    final h = _roomScene ? 58.0 : 41.0;
    final step = _roomScene ? 4.5 : 3.8;
    final tower = SizedBox(
      width: w + 2,
      height: h + step * (layers - 1),
      child: Stack(
        children: [
          for (var i = 0; i < layers; i++)
            Positioned(
              left: 1,
              top: step * i,
              child: _tileBack(w, h, glow: drawable && i == layers - 1),
            ),
          if (refillable)
            const Positioned.fill(
              child: Center(
                child: Icon(Icons.autorenew_rounded,
                    color: Color(0xFFFFD54F), size: 18),
              ),
            ),
        ],
      ),
    );
    return GestureDetector(
      onTap: _executeDraw,
      child: Draggable<int>(
        key: _deckKey,
        data: OkeyDrag.deck,
        maxSimultaneousDrags: drawable ? 1 : 0,
        onDragStarted: () => AppHaptics.selection(),
        dragAnchorStrategy: (d, c, p) => const Offset(_rackTileW / 2,
            _rackTileH / 2 + _rackTileH * OkeyIstakaWidget.dragLiftFactor),
        feedback: Material(
          color: Colors.transparent,
          elevation: 10,
          child: _tileBack(_rackTileW, _rackTileH),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tower,
            const SizedBox(height: 3),
            Text(refillable ? '↻' : '$remaining',
                style: TextStyle(
                    color: drawable ? const Color(0xFF86EFAC) : Colors.white60,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPlayerBadge(String timerString, bool isTurn) {
    final player = _engine.players[0];
    return Container(
      margin: const EdgeInsets.only(left: 8),
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
          Container(
            width: 30,
            height: 30,
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
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                player.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    height: 1.15),
              ),
              const SizedBox(height: 1.5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rating ${player.rating}',
                    style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 9,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    timerString,
                    style: TextStyle(
                        color: isTurn
                            ? (_engine.turnTimeRemaining <= 10
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF4ADE80))
                            : const Color(0xFFD1D5DB),
                        fontSize: 9,
                        fontWeight: isTurn ? FontWeight.w800 : FontWeight.w600),
                  ),
                ],
              ),
              if (isTurn) ...[
                const SizedBox(height: 3.5),
                SizedBox(
                  width: 95,
                  height: 3.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (_engine.turnTimeRemaining / _engine.turnDuration)
                          .clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _engine.turnTimeRemaining <= 10
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF4ADE80),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDockDivider({bool vertical = false}) => Container(
        width: vertical ? 40 : 1,
        height: vertical ? 1 : 18,
        color: const Color(0x22FFFFFF),
        margin: EdgeInsets.symmetric(
            horizontal: vertical ? 0 : 2, vertical: vertical ? 1 : 0),
      );

  Widget _buildDockButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  color: Color(0xFFD1D5DB),
                  fontSize: 8,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// رسام تمديد حواف صورة الغرفة: يملأ أي فراغ فوق/تحت الصورة بشرائح
/// ممدودة ومقلوبة من الصورة نفسها — الجدار يكمل للأعلى والأرضية/السجاد
/// للأسفل — بحيث تبقى الصورة متصلة بلا أشرطة سوداء على أي أبعاد شاشة
