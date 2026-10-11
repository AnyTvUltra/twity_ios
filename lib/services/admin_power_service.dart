import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'okey_room_service.dart';

/// قوى الإدارة داخل اللعبة — هدايا لحظية + إشراف على الغرف.
///
/// التخويل الفعلي مفروض في قواعد Firestore عبر وثيقة admins/{uid}؛
/// هذه الدوال تكتب فقط ما تسمح به القواعد للأدمن، فلا يستطيع
/// لاعب عادي تزوير أيٍّ من هذه التأثيرات من جهازه.
class AdminPowerService {
  static final AdminPowerService _instance = AdminPowerService._internal();
  factory AdminPowerService() => _instance;
  AdminPowerService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? get _me => AuthService().currentUser;

  /// أنا أدمن فعلياً؟ (القراءة من وثيقة المستخدم المتزامنة)
  bool get isAdmin => _me?.isAdmin ?? false;

  /// أدمن ظاهر بالتاج للآخرين؟ التخفي يخفيه
  bool get isVisibleAdmin => _me?.isVisibleAdmin ?? false;

  // ═══════════════ الهدايا ═══════════════

  /// يهدي لاعباً واحداً — يكتب وثيقة claims فيصله لحظياً
  /// عبر بثّ المطالبات مع إشعار «هدية من الإدارة 👑».
  /// سقف الهدية للأدمن غير محدود بحسب القواعد
  Future<bool> giftTo({
    required String toUid,
    int chips = 0,
    int gems = 0,
    String? skinId,
  }) async {
    final me = _me;
    if (!isAdmin || me == null) return false;
    if (toUid.isEmpty || toUid == me.uid) return false;
    if (chips <= 0 && gems <= 0 && (skinId == null || skinId.isEmpty)) {
      return false;
    }
    try {
      await _firestore.collection('claims').add({
        'toUid': toUid,
        'fromUid': me.uid,
        'fromAdmin': true,
        'chips': chips,
        'gems': gems,
        if (skinId != null && skinId.isNotEmpty) 'skinId': skinId,
        'claimed': false,
        'at': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('giftTo: $e');
      return false;
    }
  }

  /// إهداء جماعي لكل لاعبي الغرفة الحقيقيين (يستثني نفسه والروبوتات)
  Future<int> giftAll({
    required List<OkeyRoomPlayer> players,
    int chips = 0,
    int gems = 0,
  }) async {
    int sent = 0;
    for (final p in players) {
      if (p.isBot || p.uid == _me?.uid) continue;
      if (await giftTo(toUid: p.uid, chips: chips, gems: gems)) sent++;
    }
    return sent;
  }

  // ═══════════════ حضور الأدمن في الغرفة ═══════════════

  /// إعلان دخول أدمن — يكتب lastAnnounce على وثيقة الغرفة فيظهر
  /// بانر «انضمّ مسؤول اللعبة 👑» لكل المتواجدين فيها فقط (ليس بثاً عاماً).
  /// لا يُعلن في وضع التخفي
  Future<void> announceJoin(String roomId) async {
    final me = _me;
    if (!isVisibleAdmin || me == null) return;
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'lastAnnounce': {
          'uid': me.uid,
          'name': me.displayName,
          'at': DateTime.now().millisecondsSinceEpoch,
        },
      });
    } catch (e) {
      debugPrint('announceJoin: $e');
    }
  }

  /// تبديل وضع التخفي — يُخزَّن على وثيقة المستخدم (يكتبها الأدمن
  /// عبر مسار isAdmin في القواعد؛ العضو العادي ممنوع منها)
  Future<void> toggleStealth() async {
    final me = _me;
    if (me == null || !me.isAdmin) return;
    try {
      await _firestore.collection('users').doc(me.uid).update({
        'adminStealth': !me.adminStealth,
      });
    } catch (e) {
      debugPrint('toggleStealth: $e');
    }
  }

  /// إعلان مثبّت داخل الغرفة — يظهر شريطاً لكل المتواجدين.
  /// نص فارغ يمحو الإعلان
  Future<bool> setRoomNotice(String roomId, String text) async {
    if (!isAdmin) return false;
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'notice': text,
      });
      return true;
    } catch (e) {
      debugPrint('setRoomNotice: $e');
      return false;
    }
  }

  // ═══════════════ الإشراف ═══════════════

  /// طرد لاعب من الغرفة — يُزال من المقاعد وتصله إشارة kicked
  /// فيخرجه جهازه فور رؤيتها
  Future<bool> kickPlayer(String roomId, String targetUid) async {
    final me = _me;
    if (!isAdmin || me == null || targetUid.isEmpty || targetUid == me.uid) {
      return false;
    }
    try {
      final ref = _firestore.collection('rooms').doc(roomId);
      final snap = await ref.get();
      final data = snap.data();
      if (data == null) return false;
      final players = (data['players'] as List? ?? [])
          .where((p) => (p as Map)['uid'] != targetUid)
          .toList();
      final uids = (data['playerUids'] as List? ?? [])
          .where((u) => u != targetUid)
          .toList();
      await ref.update({
        'players': players,
        'playerUids': uids,
        'kicked': {
          'uid': targetUid,
          'at': DateTime.now().millisecondsSinceEpoch,
        },
      });
      return true;
    } catch (e) {
      debugPrint('kickPlayer: $e');
      return false;
    }
  }

  /// كتم لاعب — mutedUntil على وثيقته يمنع شات الغرفة من جهازه
  Future<bool> mutePlayer(String uid, {int minutes = 10}) async {
    if (!isAdmin || uid.isEmpty || uid.startsWith('bot_')) return false;
    try {
      await _firestore.collection('users').doc(uid).update({
        'mutedUntil':
            Timestamp.fromDate(DateTime.now().add(Duration(minutes: minutes))),
      });
      return true;
    } catch (e) {
      debugPrint('mutePlayer: $e');
      return false;
    }
  }

  /// فك الكتم فوراً
  Future<bool> unmutePlayer(String uid) async {
    if (!isAdmin || uid.isEmpty) return false;
    try {
      await _firestore.collection('users').doc(uid).update({
        'mutedUntil': null,
      });
      return true;
    } catch (e) {
      debugPrint('unmutePlayer: $e');
      return false;
    }
  }

  /// حظر مؤقت — banUntil يطرده من التطبيق حتى انتهاء المدة
  /// (بوابة الحظر في main.dart تفحصه مع isBanned)
  Future<bool> tempBan(String uid, {int days = 1}) async {
    if (!isAdmin || uid.isEmpty || uid.startsWith('bot_')) return false;
    try {
      await _firestore.collection('users').doc(uid).update({
        'banUntil':
            Timestamp.fromDate(DateTime.now().add(Duration(days: days))),
      });
      return true;
    } catch (e) {
      debugPrint('tempBan: $e');
      return false;
    }
  }

  /// فك الحظر المؤقت
  Future<bool> unbanTemp(String uid) async {
    if (!isAdmin || uid.isEmpty) return false;
    try {
      await _firestore.collection('users').doc(uid).update({
        'banUntil': null,
      });
      return true;
    } catch (e) {
      debugPrint('unbanTemp: $e');
      return false;
    }
  }

  /// أمر إنهاء الجولة — المضيف يلتقطه من بثّ الغرفة ويُنهي
  /// الجولة بشكل نظيف (يغلق status دون فائز)
  Future<bool> endRound(String roomId) async {
    if (!isAdmin) return false;
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'adminCommand': {
          'type': 'endRound',
          'at': DateTime.now().millisecondsSinceEpoch,
        },
      });
      return true;
    } catch (e) {
      debugPrint('endRound: $e');
      return false;
    }
  }

  /// كشف أيدي اللاعبين — للمراجعة وكشف الغش. القواعد تسمح
  /// للأدمن بقراءة hands/ — اللاعبون العاديون لا يقرؤون إلا أيديهم
  Future<List<Map<String, dynamic>>> peekHands(String roomId) async {
    if (!isAdmin) return const [];
    try {
      final snap = await _firestore
          .collection('rooms')
          .doc(roomId)
          .collection('hands')
          .get();
      return snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('peekHands: $e');
      return const [];
    }
  }

  // ═══════════════ الفعاليات ═══════════════

  /// يزرع صندوق كنز — أول لاعب يضغطه يأخذ الجائزة كاملة.
  /// treasureClaim يبدأ فارغاً ولا يملؤه إلا الفائز
  Future<bool> plantTreasure(
    String roomId, {
    int chips = 0,
    int gems = 0,
  }) async {
    final me = _me;
    if (!isAdmin || me == null || (chips <= 0 && gems <= 0)) return false;
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'treasure': {
          'chips': chips,
          'gems': gems,
          'by': me.uid,
          'at': DateTime.now().millisecondsSinceEpoch,
        },
        'treasureClaim': null,
      });
      return true;
    } catch (e) {
      debugPrint('plantTreasure: $e');
      return false;
    }
  }

  /// محاولة أخذ الكنز — معاملة واحدة تمنحه للأسرع فقط.
  /// يعيد: 'won:chips:gems' عند الفوز، 'taken' إن سُبق، 'gone' إن لا كنز
  Future<String> claimTreasure(String roomId) async {
    final me = _me;
    if (me == null) return 'error';
    final ref = _firestore.collection('rooms').doc(roomId);
    try {
      final result = await _firestore.runTransaction<String>((tx) async {
        final snap = await tx.get(ref);
        final d = snap.data();
        if (d == null || d['treasure'] is! Map) return 'gone';
        if (d['treasureClaim'] is Map) return 'taken';
        tx.update(ref, {
          'treasureClaim': {
            'uid': me.uid,
            'name': me.displayName,
            'at': DateTime.now().millisecondsSinceEpoch,
          },
        });
        final t = Map<String, dynamic>.from(d['treasure'] as Map);
        final c = (t['chips'] as num?)?.toInt() ?? 0;
        final g = (t['gems'] as num?)?.toInt() ?? 0;
        return 'won:$c:$g';
      });
      if (result.startsWith('won:')) {
        final parts = result.split(':');
        final chips = int.tryParse(parts[1]) ?? 0;
        final gems = int.tryParse(parts[2]) ?? 0;
        // الرصد ضمن سقف تغيير الرصيد المسموح به للمستخدم نفسه
        await _firestore.collection('users').doc(me.uid).update({
          'chips': me.chips + chips,
          'gems': me.gems + gems,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return result;
    } catch (e) {
      debugPrint('claimTreasure: $e');
      return 'error';
    }
  }

  /// جائزة خاطفة — تُضاف لرصيد الفائز بهذه الجولة تلقائياً.
  /// الفائز يرصدها بنفسه (ضمن سقف الرصيد) ويُسجَّل flashPrizeClaimed
  Future<bool> setFlashPrize(String roomId, int chips) async {
    if (!isAdmin || chips <= 0) return false;
    try {
      await _firestore.collection('rooms').doc(roomId).update({
        'flashPrize': chips,
        'flashPrizeClaimed': null,
      });
      return true;
    } catch (e) {
      debugPrint('setFlashPrize: $e');
      return false;
    }
  }
}
