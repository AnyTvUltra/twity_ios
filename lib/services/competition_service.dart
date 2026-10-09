import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'okey_room_service.dart';
import '../l10n/app_lang.dart';

/// صف في لوحة المتصدرين — بيانات عامة مقروءة من وثائق users
/// (القراءة للمسجّلين بحسب القواعد)
class LeaderRow {
  final String uid;
  final String name;
  final String username;
  final String photoUrl;
  final int rating;
  final int wins;
  final int losses;
  final int weeklyWins;
  final int seasonRating;
  final String title;
  final String frameId;
  final String weekKey;
  final bool isVip;

  const LeaderRow({
    required this.uid,
    required this.name,
    this.username = '',
    this.photoUrl = '',
    this.rating = 1200,
    this.wins = 0,
    this.losses = 0,
    this.weeklyWins = 0,
    this.seasonRating = 0,
    this.title = '',
    this.frameId = '',
    this.weekKey = '',
    this.isVip = false,
  });

  factory LeaderRow.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final vipUntil = d['vipUntil'];
    final vip =
        vipUntil is Timestamp && vipUntil.toDate().isAfter(DateTime.now());
    return LeaderRow(
      uid: doc.id,
      name: d['displayName'] ?? 'لاعب'.tr,
      username: d['username'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      rating: (d['rating'] as num?)?.toInt() ?? 1200,
      wins: (d['wins'] as num?)?.toInt() ?? 0,
      losses: (d['losses'] as num?)?.toInt() ?? 0,
      weeklyWins: (d['weeklyWins'] as num?)?.toInt() ?? 0,
      seasonRating: (d['seasonRating'] as num?)?.toInt() ?? 0,
      title: d['title'] ?? '',
      frameId: (d['equippedSkins'] as Map?)?['frame']?.toString() ?? '',
      weekKey: d['weekKey'] ?? '',
      isVip: vip,
    );
  }
}

/// بطولة أسبوعية — وثيقة في مجموعة tournaments يديرها الأدمن.
/// الغرف تحمل tournamentId فتُحسب نتائجها في standings البطولة.
class Tournament {
  final String id;
  final String name;
  final String game; // 'okey' حالياً
  final String variant;
  final int entryFee; // رهان غرف البطولة
  final List<int> prizes; // جوائز المراكز [أول، ثاني، ثالث]
  final DateTime startAt;
  final DateTime endAt;
  final String status; // 'active' / 'ended'

  const Tournament({
    required this.id,
    required this.name,
    this.game = 'okey',
    this.variant = 'turkish',
    this.entryFee = 200,
    this.prizes = const [0, 0, 0],
    required this.startAt,
    required this.endAt,
    this.status = 'active',
  });

  bool get isLive =>
      status == 'active' &&
      DateTime.now().isAfter(startAt) &&
      DateTime.now().isBefore(endAt);

  Duration get timeLeft => endAt.difference(DateTime.now());

  factory Tournament.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
    return Tournament(
      id: doc.id,
      name: d['name'] ?? 'بطولة'.tr,
      game: d['game'] ?? 'okey',
      variant: d['variant'] ?? 'turkish',
      entryFee: (d['entryFee'] as num?)?.toInt() ?? 200,
      prizes: [
        for (final p in (d['prizes'] as List? ?? const [])) (p as num).toInt()
      ],
      startAt: ts(d['startAt']),
      endAt: ts(d['endAt']),
      status: d['status'] ?? 'active',
    );
  }
}

/// صف ترتيب بطولة — في tournaments/{id}/standings/{uid}
class StandingRow {
  final String uid;
  final String name;
  final String photoUrl;
  final int points;
  final int wins;
  final int matches;

  const StandingRow({
    required this.uid,
    this.name = '',
    this.photoUrl = '',
    this.points = 0,
    this.wins = 0,
    this.matches = 0,
  });

  factory StandingRow.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return StandingRow(
      uid: doc.id,
      name: d['name'] ?? '',
      photoUrl: d['photoUrl'] ?? '',
      points: (d['points'] as num?)?.toInt() ?? 0,
      wins: (d['wins'] as num?)?.toInt() ?? 0,
      matches: (d['matches'] as num?)?.toInt() ?? 0,
    );
  }
}

/// خدمة التنافس: لوحات المتصدرين + المواسم + البطولات الأسبوعية.
/// كلها قراءة عامة للمسجلين؛ الكتابة الوحيدة للمستخدم هي صف
/// ترتيبه في بطولة (نقاطه المكسوبة) ومطالبة جائزته.
class CompetitionService {
  static final CompetitionService _instance = CompetitionService._internal();
  factory CompetitionService() => _instance;
  CompetitionService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ══════════════════ لوحات المتصدرين ══════════════════

  /// الأفضل كل الوقت — أعلى تقييم عام
  Stream<List<LeaderRow>> leaderboardAllTime({int limit = 50}) {
    return _firestore
        .collection('users')
        .orderBy('rating', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(LeaderRow.fromDoc).toList());
  }

  /// الأفضل هذا الأسبوع — عدّاد weeklyWins يُصفّر تلقائياً عند بدء
  /// أسبوع جديد؛ نُرشّح بـ weekKey الحالي فتُستبعد العدّادات القديمة
  Stream<List<LeaderRow>> leaderboardWeekly({int limit = 50}) {
    final wk = AuthService.currentWeekKey();
    return _firestore
        .collection('users')
        .orderBy('weeklyWins', descending: true)
        .limit(limit * 2)
        .snapshots()
        .map((q) => q.docs
            .map(LeaderRow.fromDoc)
            .where((r) => r.weeklyWins > 0 && r.weekKey == wk)
            .take(limit)
            .toList());
  }

  /// ترتيب الموسم — تقييم موسمي منفصل عن العام، يُصفّر كل موسم
  Stream<List<LeaderRow>> leaderboardSeason(String seasonId, {int limit = 50}) {
    return _firestore
        .collection('users')
        .where('seasonId', isEqualTo: seasonId)
        .orderBy('seasonRating', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(LeaderRow.fromDoc).toList());
  }

  /// ترتيبي الحالي في كل لائحة — لتظليل صف المستخدم
  String? get myUid => AuthService().currentUser?.uid;

  // ══════════════════ الموسم ══════════════════

  /// إعداد الموسم الجاري من config/season — الأدمن يديره:
  /// {id: 's2026_10', name: 'موسم أكتوبر', endsAt: ts}
  /// عند غيابه لا يوجد موسم — تُخفى تبويبته من الواجهة.
  Stream<Map<String, dynamic>?> seasonConfig() {
    return _firestore
        .collection('config')
        .doc('season')
        .snapshots()
        .map((d) => d.exists ? d.data() : null);
  }

  Future<String?> currentSeasonId() async {
    try {
      final d = await _firestore.collection('config').doc('season').get();
      return d.data()?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  // ══════════════════ البطولات ══════════════════

  /// البطولات الفعّالة (تُرتّب محلياً — العدد صغير دائماً)
  Stream<List<Tournament>> tournaments() {
    return _firestore
        .collection('tournaments')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((q) => q.docs.map(Tournament.fromDoc).toList()
          ..sort((a, b) => a.endAt.compareTo(b.endAt)));
  }

  /// ترتيب بطولة — نقاط = فوز×3 + تعادل (مستقبلاً قد نضيف مراكز)
  Stream<List<StandingRow>> standings(String tournamentId, {int limit = 50}) {
    return _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('standings')
        .orderBy('points', descending: true)
        .limit(limit)
        .snapshots()
        .map((q) => q.docs.map(StandingRow.fromDoc).toList());
  }

  /// صف ترتيبي في بطولة — null إن لم ألعبها بعد
  Stream<StandingRow?> myStanding(String tournamentId, String uid) {
    return _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('standings')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists ? StandingRow.fromDoc(d) : null);
  }

  /// تسجيل نتيجة مباراة بطولة — فوز = 3 نقاط، خسارة = 0
  /// (الصف وثيقة المستخدم نفسه — القواعد تمنع تزوير صف غيره)
  Future<void> recordTournamentResult(String tournamentId, bool isWin) async {
    final user = AuthService().currentUser;
    if (user == null || user.uid.startsWith('guest_')) return;
    try {
      await _firestore
          .collection('tournaments')
          .doc(tournamentId)
          .collection('standings')
          .doc(user.uid)
          .set({
        'name': user.displayName,
        'photoUrl': user.photoUrl,
        'points': FieldValue.increment(isWin ? 3 : 0),
        'wins': FieldValue.increment(isWin ? 1 : 0),
        'matches': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error recording tournament result: $e');
    }
  }

  /// انضمام لبطولة — ينشئ غرفة خاصة موسومة بالبطولة أو ينضم
  /// لغرفة بطولة منتظرة (مطابقة سريعة داخل نطاق البطولة)
  Future<OkeyRoom?> joinTournamentMatch(Tournament t, AppUser user) async {
    try {
      // ابحث عن غرفة بطولة منتظرة بنفس الرهان فيها مقعد
      final q = await _firestore
          .collection('rooms')
          .where('tournamentId', isEqualTo: t.id)
          .where('status', isEqualTo: 'waiting')
          .limit(5)
          .get();
      for (final d in q.docs) {
        final r = OkeyRoom.fromDoc(d);
        if (r.players.length < 4 && !r.players.any((p) => p.uid == user.uid)) {
          final seat = r.players.length;
          final np = OkeyRoomPlayer(
            uid: user.uid,
            name: user.displayName,
            username: user.username,
            photoUrl: user.photoUrl,
            seatIndex: seat,
            title: user.title,
            frameId: user.equippedSkins['frame'] ?? '',
          );
          await _firestore.collection('rooms').doc(r.id).update({
            'players': FieldValue.arrayUnion([np.toMap()]),
            'playerUids': FieldValue.arrayUnion([user.uid]),
          });
          await AuthService().updateMatchResult(
              chipChange: -t.entryFee,
              ratingChange: 0,
              isWin: false,
              recordResult: false);
          unawaited(AuthService().setActiveRoom(r.id, 'okey'));
          return OkeyRoom.fromDoc(
              await _firestore.collection('rooms').doc(r.id).get());
        }
      }
      // لا غرفة منتظرة — أنشئ واحدة موسومة بالبطولة
      return await OkeyRoomService().createPrivateRoom(
        stakes: t.entryFee,
        user: user,
        variant: t.variant,
        tournamentId: t.id,
      );
    } catch (e) {
      debugPrint('Error joining tournament: $e');
      return null;
    }
  }

  /// مطالبة جائزة بطولة منتهية — يستحقها أصحاب المراكز الثلاثة
  /// الأولى؛ تُكتب وثيقة مطالبة مرة واحدة ثم يُضاف الرصيد
  Future<({bool ok, int prize})> claimTournamentPrize(
      Tournament t, int myRank) async {
    final user = AuthService().currentUser;
    if (user == null || user.uid.startsWith('guest_')) {
      return (ok: false, prize: 0);
    }
    if (myRank < 1 || myRank > t.prizes.length) {
      return (ok: false, prize: 0);
    }
    final prize = t.prizes[myRank - 1];
    if (prize <= 0) return (ok: false, prize: 0);
    try {
      final claimRef = _firestore
          .collection('tournaments')
          .doc(t.id)
          .collection('claims')
          .doc(user.uid);
      // إنشاء وثيقة المطالبة — تفشل إن كانت موجودة (مطالبة مسبقة)
      await claimRef.set({
        'rank': myRank,
        'prize': prize,
        'at': FieldValue.serverTimestamp(),
      });
      await AuthService().adjustChips(prize);
      return (ok: true, prize: prize);
    } catch (e) {
      debugPrint('Error claiming prize: $e');
      return (ok: false, prize: 0);
    }
  }

  /// هل طالبت بجائزتي في هذه البطولة مسبقاً؟
  Stream<bool> prizeClaimed(String tournamentId, String uid) {
    return _firestore
        .collection('tournaments')
        .doc(tournamentId)
        .collection('claims')
        .doc(uid)
        .snapshots()
        .map((d) => d.exists);
  }
}
