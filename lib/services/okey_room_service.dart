import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

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
      name: data['name'] ?? 'لاعب',
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
        'سارة (Bot)',
        'أحمد (Bot)',
        'كابتن طارق (Bot)',
        'أمير النرد (Bot)'
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
}
