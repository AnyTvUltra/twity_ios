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

  OkeyRoomPlayer({
    required this.uid,
    required this.name,
    required this.username,
    required this.photoUrl,
    required this.seatIndex,
    this.isBot = false,
    this.isReady = true,
    this.tileCount = 14,
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
          );

          await _firestore.collection('rooms').doc(doc.id).update({
            'players': FieldValue.arrayUnion([newPlayer.toMap()]),
            'playerUids': FieldValue.arrayUnion([user.uid]),
          });

          // خصم العملات
          await AuthService().updateMatchResult(
            chipChange: -stakes,
            ratingChange: 0,
            isWin: false,
            recordResult: false,
          );

          return OkeyRoom.fromDoc(await doc.reference.get());
        }
      }

      // إذا لم توجد غرفة، أنشئ غرفة جديدة
      final docRef = _firestore.collection('rooms').doc();
      final hostPlayer = OkeyRoomPlayer(
        uid: user.uid,
        name: user.displayName,
        username: user.username,
        photoUrl: user.photoUrl,
        seatIndex: 0,
      );

      final newRoomData = {
        'stakes': stakes,
        'variant': variant,
        'status': 'waiting',
        'hostUid': user.uid,
        'players': [hostPlayer.toMap()],
        'playerUids': [user.uid],
        'currentTurnSeat': 0,
        'turnPhase': 'draw',
        'drawDeckCount': 48,
        'centerDiscards': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(newRoomData);

      // خصم العملات
      await AuthService().updateMatchResult(
        chipChange: -stakes,
        ratingChange: 0,
        isWin: false,
        recordResult: false,
      );

      final createdDoc = await docRef.get();
      return OkeyRoom.fromDoc(createdDoc);
    } catch (e) {
      debugPrint('Error in quickMatch: $e');
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
  /// + حمولة الحركة + at (مللي ثانية للترتيب التقريبي)
  Future<void> sendMove(String roomId, Map<String, dynamic> move) async {
    await _firestore
        .collection('rooms')
        .doc(roomId)
        .collection('moves')
        .add(move);
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
