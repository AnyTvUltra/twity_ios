import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import '../l10n/app_lang.dart';

class OkeyRoomPlayer {
  final String uid;
  final String name;
  final String username;
  final String photoUrl;
  final int seatIndex;
  final bool isBot;
  final bool isReady;
  final int tileCount;

  /// متصل الآن؟ false = منقطع مؤقتاً ويلعب المضيف عنه حتى يعود
  final bool connected;

  /// اللقب المجهّز (نص يظهر تحت الاسم) + معرّف إطار الصورة المجهّز
  final String title;
  final String frameId;

  OkeyRoomPlayer({
    required this.uid,
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.seatIndex,
    this.isBot = false,
    this.isReady = true,
    this.tileCount = 14,
    this.connected = true,
    this.title = '',
    this.frameId = '',
  });

  factory OkeyRoomPlayer.fromMap(Map<String, dynamic> data) {
    return OkeyRoomPlayer(
      uid: data['uid'] ?? '',
      name: data['name'] ?? 'لاعب'.tr,
      username: data['username'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      seatIndex: data['seatIndex'] ?? 0,
      isBot: data['isBot'] ?? false,
      isReady: data['isReady'] ?? true,
      tileCount: data['tileCount'] ?? 14,
      connected: data['connected'] ?? true,
      title: data['title'] ?? '',
      frameId: data['frameId'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'username': username,
      'photoUrl': photoUrl,
      'seatIndex': seatIndex,
      'isBot': isBot,
      'isReady': isReady,
      'tileCount': tileCount,
      'connected': connected,
      if (title.isNotEmpty) 'title': title,
      if (frameId.isNotEmpty) 'frameId': frameId,
    };
  }
}

class OkeyRoom {
  final String id;
  final int stakes;
  final String variant; // قانون الكونكان: sulaymaniyah / erbil / turkish
  final String status; // 'waiting', 'playing', 'finished'
  final String hostUid;
  final List<OkeyRoomPlayer> players;
  final int currentTurnSeat;
  final String turnPhase; // 'draw', 'discard'
  final DateTime? turnStartTime;
  final int turnDurationSeconds;
  final int drawDeckCount;
  final Map<String, dynamic>? indicatorTile;
  final List<Map<String, dynamic>> centerDiscards;
  final Map<String, dynamic>? winner;
  final DateTime createdAt;

  /// لقطة اللعبة العامة التي يكتبها المضيف (لا تحتوي أيدي اللاعبين
  /// ولا الرزمة — أحجار كل لاعب الخاصة في hands/{uid})
  final Map<String, dynamic>? game;

  /// آخر رسالة شات سريعة داخل الغرفة: {uid, msg, at}
  final Map<String, dynamic>? chat;

  /// كود الغرفة الخاصة (6 خانات) — يظهر للمضيف ليشاركه مع أصدقائه.
  /// فارغ = غرفة عادية من المطابقة السريعة
  final String code;

  /// غرفة خاصة بالكود — المطابقة السريعة تتخطاها دائماً
  final bool isPrivate;

  /// معرّف البطولة إن كانت هذه الغرفة جزءاً من بطولة فعّالة —
  /// نتائجها تُحسب في standings البطولة
  final String tournamentId;

  /// معرّفات المشاهدين — لا يشغلون مقاعداً ولا يقرؤون أيدياً خاصة
  final List<String> spectators;

  OkeyRoom({
    required this.id,
    required this.stakes,
    this.variant = 'turkish',
    required this.status,
    required this.hostUid,
    required this.players,
    this.currentTurnSeat = 0,
    this.turnPhase = 'draw',
    this.turnStartTime,
    this.turnDurationSeconds = 30,
    this.drawDeckCount = 48,
    this.indicatorTile,
    this.centerDiscards = const [],
    this.winner,
    required this.createdAt,
    this.game,
    this.chat,
    this.code = '',
    this.isPrivate = false,
    this.tournamentId = '',
    this.spectators = const [],
  });

  factory OkeyRoom.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final playersList = (data['players'] as List<dynamic>? ?? [])
        .map((p) => OkeyRoomPlayer.fromMap(Map<String, dynamic>.from(p)))
        .toList();

    DateTime? turnStart;
    if (data['turnStartTime'] is Timestamp) {
      turnStart = (data['turnStartTime'] as Timestamp).toDate();
    }

    DateTime created = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    }

    return OkeyRoom(
      id: doc.id,
      stakes: data['stakes'] ?? 50,
      variant: data['variant'] ?? 'turkish',
      status: data['status'] ?? 'waiting',
      hostUid: data['hostUid'] ?? '',
      players: playersList,
      currentTurnSeat: data['currentTurnSeat'] ?? 0,
      turnPhase: data['turnPhase'] ?? 'draw',
      turnStartTime: turnStart,
      turnDurationSeconds: data['turnDurationSeconds'] ?? 30,
      drawDeckCount: data['drawDeckCount'] ?? 48,
      indicatorTile: data['indicatorTile'] != null
          ? Map<String, dynamic>.from(data['indicatorTile'])
          : null,
      centerDiscards: (data['centerDiscards'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      winner: data['winner'] != null
          ? Map<String, dynamic>.from(data['winner'])
          : null,
      createdAt: created,
      game:
          data['game'] != null ? Map<String, dynamic>.from(data['game']) : null,
      chat:
          data['chat'] != null ? Map<String, dynamic>.from(data['chat']) : null,
      code: data['code'] ?? '',
      isPrivate: data['isPrivate'] ?? false,
      tournamentId: data['tournamentId'] ?? '',
      spectators: List<String>.from(data['spectators'] as List<dynamic>? ?? []),
    );
  }
}

class OkeyRoomService {
  static final OkeyRoomService _instance = OkeyRoomService._internal();
  factory OkeyRoomService() => _instance;
  OkeyRoomService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// بث حالة الغرفة الحالية
  Stream<OkeyRoom> getRoomStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .snapshots()
        .map((doc) => OkeyRoom.fromDoc(doc));
  }

  /// الانضمام السريع إلى غرفة أو إنشاء غرفة جديدة إذا لم تتوفر
  Future<OkeyRoom?> quickMatch(
      {required int stakes,
      required AppUser user,
      String variant = 'turkish'}) async {
    // 1. خصم رسوم الرهان مقدماً
    if (user.chips < stakes) {
      return null;
    }

    try {
      // ابحث عن غرف في حالة الانتظار بنفس قيمة الرهان ونفس القانون
      final query = await _firestore
          .collection('rooms')
          .where('stakes', isEqualTo: stakes)
          .where('variant', isEqualTo: variant)
          .where('status', isEqualTo: 'waiting')
          .limit(5)
          .get();

      for (final doc in query.docs) {
        final room = OkeyRoom.fromDoc(doc);
        // الغرف الخاصة (بالكود) لا تدخل المطابقة السريعة أبداً
        if (room.isPrivate) continue;
        if (room.players.length < 4 &&
            !room.players.any((p) => p.uid == user.uid)) {
          // انضم لهذه الغرفة
          final seatIndex = room.players.length;
          final newPlayer = OkeyRoomPlayer(
            uid: user.uid,
            name: user.displayName,
            username: user.username,
            photoUrl: user.photoUrl,
            seatIndex: seatIndex,
            title: user.title,
            frameId: user.equippedSkins['frame'] ?? '',
          );

          await _firestore.collection('rooms').doc(doc.id).update({
            'players': FieldValue.arrayUnion([newPlayer.toMap()]),
            'playerUids': FieldValue.arrayUnion([user.uid]),
          });

          // خصم العملات + تسجيل الحضور
          await AuthService().updateMatchResult(
            chipChange: -stakes,
            ratingChange: 0,
            isWin: false,
            recordResult: false,
          );
          unawaited(AuthService().setActiveRoom(doc.id, 'okey'));

          return OkeyRoom.fromDoc(await doc.reference.get());
        }
      }

      // إذا لم توجد غرفة، أنشئ غرفة جديدة
      final docRef = _firestore.collection('rooms').doc();
      final hostP = OkeyRoomPlayer(
        uid: user.uid,
        name: user.displayName,
        username: user.username,
        photoUrl: user.photoUrl,
        seatIndex: 0,
        title: user.title,
        frameId: user.equippedSkins['frame'] ?? '',
      );
      final newRoomData = {
        'stakes': stakes,
        'variant': variant,
        'status': 'waiting',
        'hostUid': user.uid,
        'players': [hostP.toMap()],
        'playerUids': [user.uid],
        'isPrivate': false,
        'currentTurnSeat': 0,
        'turnPhase': 'draw',
        'drawDeckCount': 48,
        'centerDiscards': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(newRoomData);

      // خصم العملات + تسجيل الحضور
      await AuthService().updateMatchResult(
        chipChange: -stakes,
        ratingChange: 0,
        isWin: false,
        recordResult: false,
      );
      unawaited(AuthService().setActiveRoom(docRef.id, 'okey'));

      final createdDoc = await docRef.get();
      return OkeyRoom.fromDoc(createdDoc);
    } catch (e) {
      debugPrint('Error in quickMatch: $e');
      return null;
    }
  }

  /// توليد كود غرفة قصير مقروء — بلا أحرف متشابهة (0/O, 1/I/L)
  static String _genRoomCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = math.Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  /// إنشاء غرفة خاصة بكود — يشارك المضيف الكود مع أصدقائه لينضمّوا.
  /// ترجع الغرفة المنشأة أو null عند نفاد الرصيد/فشل الشبكة
  Future<OkeyRoom?> createPrivateRoom({
    required int stakes,
    required AppUser user,
    String variant = 'turkish',
    String tournamentId = '',
  }) async {
    if (user.chips < stakes) return null;
    try {
      // كود فريد: جرّب حتى تجد واحداً غير مستعمل في غرفة منتظرة
      String code = '';
      for (var attempt = 0; attempt < 6; attempt++) {
        code = _genRoomCode();
        final clash = await _firestore
            .collection('rooms')
            .where('code', isEqualTo: code)
            .where('status', isEqualTo: 'waiting')
            .limit(1)
            .get();
        if (clash.docs.isEmpty) break;
      }

      final docRef = _firestore.collection('rooms').doc();
      final hostPlayer = OkeyRoomPlayer(
        uid: user.uid,
        name: user.displayName,
        username: user.username,
        photoUrl: user.photoUrl,
        seatIndex: 0,
        title: user.title,
        frameId: user.equippedSkins['frame'] ?? '',
      );

      await docRef.set({
        'stakes': stakes,
        'variant': variant,
        'status': 'waiting',
        'hostUid': user.uid,
        'players': [hostPlayer.toMap()],
        'playerUids': [user.uid],
        'isPrivate': true,
        'code': code,
        if (tournamentId.isNotEmpty) 'tournamentId': tournamentId,
        'currentTurnSeat': 0,
        'turnPhase': 'draw',
        'drawDeckCount': 48,
        'centerDiscards': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      await AuthService().updateMatchResult(
          chipChange: -stakes,
          ratingChange: 0,
          isWin: false,
          recordResult: false);
      unawaited(AuthService().setActiveRoom(docRef.id, 'okey'));
      return OkeyRoom.fromDoc(await docRef.get());
    } catch (e) {
      debugPrint('Error creating private room: $e');
      return null;
    }
  }

  /// انضمام بكود — يبحث عن غرفة منتظرة بهذا الكود فيها مقعد فارغ
  Future<({OkeyRoom? room, String error})> joinRoomByCode(
      String code, AppUser user) async {
    try {
      final q = await _firestore
          .collection('rooms')
          .where('code', isEqualTo: code.trim().toUpperCase())
          .limit(3)
          .get();
      OkeyRoom? room;
      for (final d in q.docs) {
        final r = OkeyRoom.fromDoc(d);
        if (r.status == 'waiting') room = r;
        // غرفة جارية وأنا فيها = إعادة انضمام
        if (r.status == 'playing' && r.players.any((p) => p.uid == user.uid)) {
          return (room: r, error: '');
        }
      }
      if (room == null)
        return (room: null, error: 'لا توجد غرفة بهذا الكود'.tr);
      if (room.players.length >= 4) {
        return (room: null, error: 'الغرفة ممتلئة'.tr);
      }
      if (room.players.any((p) => p.uid == user.uid)) {
        return (room: room, error: '');
      }
      if (user.chips < room.stakes) {
        return (room: null, error: 'رصيدك غير كافٍ لرهان هذه الغرفة'.tr);
      }

      final seatIndex = room.players.length;
      final newPlayer = OkeyRoomPlayer(
        uid: user.uid,
        name: user.displayName,
        username: user.username,
        photoUrl: user.photoUrl,
        seatIndex: seatIndex,
        title: user.title,
        frameId: user.equippedSkins['frame'] ?? '',
      );
      await _firestore.collection('rooms').doc(room.id).update({
        'players': FieldValue.arrayUnion([newPlayer.toMap()]),
        'playerUids': FieldValue.arrayUnion([user.uid]),
      });
      await AuthService().updateMatchResult(
          chipChange: -room.stakes,
          ratingChange: 0,
          isWin: false,
          recordResult: false);
      unawaited(AuthService().setActiveRoom(room.id, 'okey'));
      return (
        room: OkeyRoom.fromDoc(
            await _firestore.collection('rooms').doc(room.id).get()),
        error: ''
      );
    } catch (e) {
      debugPrint('Error joining by code: $e');
      return (room: null, error: 'تعذر الانضمام — حاول مجدداً'.tr);
    }
  }

  /// غرفتي الجارية إن وُجدت — لإعادة الانضمام بعد انقطاع/إغلاق التطبيق
  Future<OkeyRoom?> findMyActiveRoom(String uid) async {
    try {
      final q = await _firestore
          .collection('rooms')
          .where('playerUids', arrayContains: uid)
          .where('status', isEqualTo: 'playing')
          .limit(3)
          .get();
      for (final d in q.docs) {
        final r = OkeyRoom.fromDoc(d);
        if (!r.players.any((p) => p.uid == uid)) continue;
        // غرفة جثّة: المضيف يحدّث turnStartTime مع كل لقطة ينشرها،
        // فغياب النبض >10د يعني أن تطبيقه مات قبل إنهاء الجولة.
        // امحُ مؤشر العودة بدل إحياء غرفة لا يديرها أحد
        final lastBeat = r.turnStartTime ?? r.createdAt;
        if (DateTime.now().difference(lastBeat).inMinutes > 10) {
          unawaited(AuthService().setActiveRoom('', ''));
          continue;
        }
        return r;
      }
      return null;
    } catch (e) {
      debugPrint('Error finding active room: $e');
      return null;
    }
  }

  /// تحديث علم الاتصال لمقعد — الضيف يُعلِم بنفسه عند الخروج،
  /// والمضيف يعلّم المقاعد المتجمّدة. يعيد كتابة مصفوفة players
  /// كاملة (لا توجد كتابة حقل داخل عنصر مصفوفة في Firestore)
  Future<void> setConnected(String roomId, String uid, bool connected,
      {List<OkeyRoomPlayer>? players}) async {
    try {
      final ref = _firestore.collection('rooms').doc(roomId);
      final list = players ?? OkeyRoom.fromDoc(await ref.get()).players;
      final updated = [
        for (final p in list)
          p.uid == uid
              ? OkeyRoomPlayer(
                  uid: p.uid,
                  name: p.name,
                  username: p.username,
                  photoUrl: p.photoUrl,
                  seatIndex: p.seatIndex,
                  isBot: p.isBot,
                  isReady: p.isReady,
                  tileCount: p.tileCount,
                  connected: connected,
                  title: p.title,
                  frameId: p.frameId,
                )
              : p
      ];
      await ref.update({'players': updated.map((p) => p.toMap()).toList()});
    } catch (e) {
      debugPrint('Error setting connected: $e');
    }
  }

  /// دخول كمشاهد — يضيف uid لقائمة spectators فقط (لا مقعد ولا يد).
  /// المشاهد يقرأ اللقطة العامة ولا يستطيع إرسال حركات أو قراءة الأيدي
  Future<void> joinAsSpectator(String roomId, String uid) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'spectators': FieldValue.arrayUnion([uid]),
      });
    } catch (e) {
      debugPrint('Error joining as spectator: $e');
    }
  }

  /// مغادرة المشاهدة — إزالة uid بلا أثر على اللعب
  Future<void> leaveSpectate(String roomId, String uid) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'spectators': FieldValue.arrayRemove([uid]),
      });
    } catch (e) {
      debugPrint('Error leaving spectate: $e');
    }
  }

  // ── حالة المضيف الكاملة — ينجو بها من إعادة فتح التطبيق ──
  // وثيقة rooms/{id}/host_state/state يقرأها ويكتبها المضيف
  // وحده (القواعد تمنع غيره): تحمل الرزمة وكل الأيدي — أي كل
  // ما لا يمكن وضعه في اللقطة العامة.

  Future<void> publishHostState(
      String roomId, Map<String, dynamic> fullState) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('host_state')
          .doc('state')
          .set(fullState);
    } catch (e) {
      debugPrint('Error publishing host state: $e');
    }
  }

  Future<Map<String, dynamic>?> loadHostState(String roomId) async {
    try {
      final d = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('host_state')
          .doc('state')
          .get();
      return d.exists ? d.data() : null;
    } catch (e) {
      debugPrint('Error loading host state: $e');
      return null;
    }
  }

  /// ملء الغرفة ببوتات ذكية لبدء اللعبة فوراً دون انتظار
  Future<void> fillWithBotsAndStart(String roomId, int stakes) async {
    try {
      final docRef = _firestore.collection('rooms').doc(roomId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final room = OkeyRoom.fromDoc(doc);
      final currentPlayers = List<OkeyRoomPlayer>.from(room.players);

      final botNames = [
        'سارة (Bot)'.tr,
        'أحمد (Bot)'.tr,
        'كابتن طارق (Bot)'.tr,
        'أمير النرد (Bot)'.tr
      ];
      int botIndex = 0;

      while (currentPlayers.length < 4) {
        final seat = currentPlayers.length;
        currentPlayers.add(
          OkeyRoomPlayer(
            uid: 'bot_${seat}_${DateTime.now().millisecondsSinceEpoch}',
            name: botNames[botIndex % botNames.length],
            username: 'bot_$seat',
            photoUrl: '',
            seatIndex: seat,
            isBot: true,
            tileCount: seat == 0 ? 15 : 14,
          ),
        );
        botIndex++;
      }

      // تجهيز حجر مؤشر عشوائي للعبة
      final colors = ['red', 'blue', 'black', 'yellow'];
      final randomColor = colors[math.Random().nextInt(colors.length)];
      final randomVal = math.Random().nextInt(13) + 1;

      await docRef.update({
        'players': currentPlayers.map((p) => p.toMap()).toList(),
        'playerUids': currentPlayers.map((p) => p.uid).toList(),
        'status': 'playing',
        'currentTurnSeat': 0,
        'turnPhase': 'discard', // اللاعب الأول لديه 15 حجر ويرمي أولاً
        'turnStartTime': FieldValue.serverTimestamp(),
        'indicatorTile': {'color': randomColor, 'value': randomVal},
      });
    } catch (e) {
      debugPrint('Error starting game with bots: $e');
    }
  }

  /// إضافة روبوت واحد لمقعد فارغ (بدون بدء اللعبة)
  Future<void> addBot(String roomId) async {
    try {
      final docRef = _firestore.collection('rooms').doc(roomId);
      final doc = await docRef.get();
      if (!doc.exists) return;

      final room = OkeyRoom.fromDoc(doc);
      if (room.players.length >= 4) return;

      final botNames = [
        'سارة (Bot)',
        'أحمد (Bot)',
        'كابتن طارق (Bot)',
        'أمير النرد (Bot)'
      ];
      final seat = room.players.length;
      final bot = OkeyRoomPlayer(
        uid: 'bot_${seat}_${DateTime.now().millisecondsSinceEpoch}',
        name: botNames[seat % botNames.length],
        username: 'bot_$seat',
        photoUrl: '',
        seatIndex: seat,
        isBot: true,
        tileCount: 14,
      );

      await docRef.update({
        'players': FieldValue.arrayUnion([bot.toMap()]),
        'playerUids': FieldValue.arrayUnion([bot.uid]),
      });
    } catch (e) {
      debugPrint('Error adding bot: $e');
    }
  }

  /// تسجيل رمي حجر في الغرفة
  Future<void> recordDiscard(
      String roomId, Map<String, dynamic> tile, int currentSeat) async {
    try {
      final nextSeat = (currentSeat + 1) % 4;
      await _firestore.collection('rooms').doc(roomId).update({
        'centerDiscards': FieldValue.arrayUnion([tile]),
        'currentTurnSeat': nextSeat,
        'turnPhase': 'draw',
        'turnStartTime': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error recording discard: $e');
    }
  }

  /// تسجيل سحب حجر
  Future<void> recordDraw(String roomId, int seat) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'drawDeckCount': FieldValue.increment(-1),
        'turnPhase': 'discard',
      });
    } catch (e) {
      debugPrint('Error recording draw: $e');
    }
  }

  /// إعلان الفوز (Okey Out) وتوزيع الجائزة
  Future<void> declareWin({
    required String roomId,
    required String winnerUid,
    required String winnerName,
    required int potPrize,
  }) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'status': 'finished',
        'winner': {
          'uid': winnerUid,
          'name': winnerName,
          'pot': potPrize,
          'wonAt': FieldValue.serverTimestamp(),
        },
      });

      // إضافة جائزة الجولة للفائز
      if (AuthService().currentUser?.uid == winnerUid) {
        await AuthService().updateMatchResult(
            chipChange: potPrize, ratingChange: 25, isWin: true);
      }
    } catch (e) {
      debugPrint('Error declaring win: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  مزامنة اللعب الأونلاين — المضيف سلطة مرجعية، الضيوف مرايا
  // ═══════════════════════════════════════════════════════════
  //
  // - الوثيقة الرئيسية تحمل «game»: لقطة عامة بلا أيدٍ ولا رزمة.
  // - rooms/{id}/hands/{uid}: يد كل لاعب الخاصة — يقرأها صاحبها.
  // - rooms/{id}/moves/{auto}: حركات الضيوف — يستهلكها المضيف
  //   بالحذف بعد تطبيقها على محركه المرجعي.

  /// جلب الغرفة مرة واحدة — شاشة اللعب تحتاجها لتحديد مقعدي ودوري
  Future<OkeyRoom?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection('rooms').doc(roomId).get();
      return doc.exists ? OkeyRoom.fromDoc(doc) : null;
    } catch (e) {
      debugPrint('Error fetching room: $e');
      return null;
    }
  }

  /// المضيف يكتب لقطة الحالة العامة + عدّادات أحجار اللاعبين
  /// ويُحدّث مؤقّت الدور — كل إعادة كتابة تشغّل مرايا الضيوف
  Future<void> publishGame(
    String roomId, {
    required Map<String, dynamic> game,
    required List<Map<String, dynamic>> players,
  }) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'game': game,
        'players': players,
        'currentTurnSeat': game['turn'],
        'turnPhase': game['phase'],
        'turnStartTime': FieldValue.serverTimestamp(),
        'turnDurationSeconds': game['turnDur'] ?? 30,
        'drawDeckCount': game['deck'],
        'centerDiscards': game['ldTile'] == null ? const [] : [game['ldTile']],
        'gameRev': game['rev'],
      });
    } catch (e) {
      debugPrint('Error publishing game state: $e');
    }
  }

  /// أيدي اللاعبين البعيدين — كل وثيقة hands/{uid} يقرأها صاحبها
  /// فقط بحسب قواعد الأمان، فيبقى ترتيب ومحتوى اليد مخفيين عن باقي
  /// اللاعبين رغم أن المضيف يملكها فعلياً
  Future<void> publishHands(
      String roomId, Map<String, List<Map<String, dynamic>>> handsByUid) async {
    try {
      final batch = _firestore.batch();
      handsByUid.forEach((uid, tiles) {
        batch.set(
          _firestore
              .collection('rooms')
              .doc(roomId)
              .collection('hands')
              .doc(uid),
          {'uid': uid, 'tiles': tiles},
        );
      });
      await batch.commit();
    } catch (e) {
      debugPrint('Error publishing hands: $e');
    }
  }

  /// بثّ يد اللاعب نفسه — الضيف يقرأ أحجاره الحقيقية من هنا
  Stream<List<Map<String, dynamic>>> getHandStream(String roomId, String uid) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('hands')
        .doc(uid)
        .snapshots()
        .map((d) {
      final data = d.data();
      if (data == null) return const <Map<String, dynamic>>[];
      return [
        for (final t in (data['tiles'] as List? ?? const []))
          Map<String, dynamic>.from(t as Map)
      ];
    });
  }

  /// الضيف يرسل حركته للمضيف — الحقول: uid, seat, t (نوع الحركة)
  /// + حمولة الحركة + at (مللي ثانية للترتيب التقريبي).
  /// لا تُرمى الأخطاء — رفض القواعد أو انقطاع الشبكة لا يجب أن
  /// يسقِط اللعبة (الحركة ببساطة لا تصل ويعيد اللاعب المحاولة)
  Future<void> sendMove(String roomId, Map<String, dynamic> move) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('moves')
          .add(move);
    } catch (e) {
      debugPrint('Error sending move: $e');
    }
  }

  /// بثّ حركات الضيوف بترتيب الوصول — يقرأها المضيف فقط
  Stream<QuerySnapshot<Map<String, dynamic>>> movesStream(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moves')
        .orderBy('at')
        .snapshots();
  }

  /// حذف حركة بعد استهلاكها على محرك المضيف
  Future<void> deleteMove(String roomId, String moveId) async {
    try {
      await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('moves')
          .doc(moveId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting move: $e');
    }
  }

  /// رسالة شات سريعة داخل الغرفة — تُكتب على الوثيقة فيراها الجميع
  /// مع اللقطة التالية، وتُعرض كفقاعة فوق استكانة المرسل
  Future<void> sendRoomChat(String roomId, String uid, String msg) async {
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'chat': {
          'uid': uid,
          'msg': msg,
          'at': DateTime.now().millisecondsSinceEpoch,
        }
      });
    } catch (e) {
      debugPrint('Error sending room chat: $e');
    }
  }
}
