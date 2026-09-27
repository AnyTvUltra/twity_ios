import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic> data, String myUid) {
    DateTime time = DateTime.now();
    if (data['timestamp'] is Timestamp) {
      time = (data['timestamp'] as Timestamp).toDate();
    }
    return ChatMessage(
      id: id,
      senderId: data['senderId'] ?? '',
      text: data['text'] ?? '',
      timestamp: time,
      isMe: data['senderId'] == myUid,
    );
  }
}

class ConversationSummary {
  final String id;
  final String otherUid;
  final String otherName;
  final String otherUsername;
  final String otherPhoto;
  final String lastMessage;
  final DateTime lastTime;
  final bool isOnline;
  final int unreadCount;

  ConversationSummary({
    required this.id,
    required this.otherUid,
    required this.otherName,
    required this.otherUsername,
    required this.otherPhoto,
    required this.lastMessage,
    required this.lastTime,
    this.isOnline = false,
    this.unreadCount = 0,
  });
}

/// طلب صداقة معلّق
class FriendRequest {
  final String id;
  final String fromUid;
  final String fromName;
  final String fromUsername;
  final String fromPhoto;
  final String toUid;
  final DateTime createdAt;

  FriendRequest({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.fromUsername,
    required this.fromPhoto,
    required this.toUid,
    required this.createdAt,
  });

  factory FriendRequest.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return FriendRequest(
      id: doc.id,
      fromUid: d['fromUid'] ?? '',
      fromName: d['fromName'] ?? 'لاعب',
      fromUsername: d['fromUsername'] ?? '',
      fromPhoto: d['fromPhoto'] ?? '',
      toUid: d['toUid'] ?? '',
      createdAt: d['createdAt'] is Timestamp
          ? (d['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class SocialService {
  static final SocialService _instance = SocialService._internal();
  factory SocialService() => _instance;
  SocialService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// البحث عن اللاعبين بالاسم أو اسم المستخدم الفريد
  Future<List<AppUser>> searchUsers(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: cleanQuery)
          .where('username', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(15)
          .get();

      return snapshot.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }

  /// بث قائمة الأصدقاء الحية
  Stream<List<Map<String, dynamic>>> getFriendsStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'uid': d.id, ...d.data()}).toList());
  }

  /// إضافة صديق مباشرة (تُستخدم داخلياً عند قبول الطلب)
  Future<void> addFriend(String myUid, AppUser friend) async {
    try {
      await _firestore.collection('users').doc(myUid).collection('friends').doc(friend.uid).set({
        'username': friend.username,
        'displayName': friend.displayName,
        'photoUrl': friend.photoUrl,
        'addedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding friend: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // طلبات الصداقة (إرسال → إشعار → قبول/رفض)
  // ══════════════════════════════════════════════════════════

  /// بثّ الطلبات الواردة المعلّقة للمستخدم
  Stream<List<FriendRequest>> getIncomingRequestsStream(String uid) {
    return _firestore
        .collection('friend_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map(FriendRequest.fromDoc).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// بثّ الطلبات الصادرة المعلّقة (لمعرفة حالة "تم الإرسال" في نتائج البحث)
  Stream<Set<String>> getOutgoingRequestsStream(String uid) {
    return _firestore
        .collection('friend_requests')
        .where('fromUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => (d.data())['toUid'] as String? ?? '')
            .where((s) => s.isNotEmpty)
            .toSet());
  }

  /// إرسال طلب صداقة — يعيد رسالة خطأ أو null عند النجاح
  Future<String?> sendFriendRequest(AppUser me, AppUser target) async {
    if (me.uid == target.uid) return 'لا يمكنك إضافة نفسك';
    final reqId = '${me.uid}_${target.uid}';
    final reverseId = '${target.uid}_${me.uid}';
    try {
      // هل هو صديق بالفعل؟
      final existing = await _firestore
          .collection('users')
          .doc(me.uid)
          .collection('friends')
          .doc(target.uid)
          .get();
      if (existing.exists) return 'هذا اللاعب صديقك بالفعل';

      // هل يوجد طلب معلّق سابق؟
      final pending = await _firestore
          .collection('friend_requests')
          .doc(reqId)
          .get();
      if (pending.exists &&
          (pending.data()?['status'] == 'pending')) {
        return 'أرسلت طلباً لهذا اللاعب بالفعل — بانتظار موافقته';
      }

      // إذا كان الطرف الآخر أرسل لي طلباً → قبول متبادل فوري
      final reverse = await _firestore
          .collection('friend_requests')
          .doc(reverseId)
          .get();
      if (reverse.exists && reverse.data()?['status'] == 'pending') {
        await acceptFriendRequest(reverseId);
        return null;
      }

      await _firestore.collection('friend_requests').doc(reqId).set({
        'fromUid': me.uid,
        'fromName': me.displayName,
        'fromUsername': me.username,
        'fromPhoto': me.photoUrl,
        'toUid': target.uid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('Error sending friend request: $e');
      return 'تعذر إرسال الطلب، حاول مرة أخرى';
    }
  }

  /// قبول طلب صداقة: إضافة الطرفين لقوائم بعضهما وحذف الطلب
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      final doc = await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .get();
      if (!doc.exists) return;
      final d = doc.data()!;
      final fromUid = d['fromUid'] as String;
      final toUid = d['toUid'] as String;

      // بيانات الطرف المُرسِل محفوظة في الطلب
      final fromData = {
        'username': d['fromUsername'] ?? '',
        'displayName': d['fromName'] ?? 'لاعب',
        'photoUrl': d['fromPhoto'] ?? '',
        'addedAt': FieldValue.serverTimestamp(),
      };

      // بيانات المستقبِل (الذي وافق) نجلبها من حسابه
      final toDoc =
          await _firestore.collection('users').doc(toUid).get();
      final toData = toDoc.exists
          ? {
              'username': toDoc.data()?['username'] ?? '',
              'displayName': toDoc.data()?['displayName'] ?? 'لاعب',
              'photoUrl': toDoc.data()?['photoUrl'] ?? '',
              'addedAt': FieldValue.serverTimestamp(),
            }
          : {
              'username': '',
              'displayName': 'لاعب',
              'photoUrl': '',
              'addedAt': FieldValue.serverTimestamp(),
            };

      final batch = _firestore.batch();
      batch.set(
          _firestore
              .collection('users')
              .doc(toUid)
              .collection('friends')
              .doc(fromUid),
          fromData);
      batch.set(
          _firestore
              .collection('users')
              .doc(fromUid)
              .collection('friends')
              .doc(toUid),
          toData);
      batch.update(doc.reference, {'status': 'accepted'});
      await batch.commit();
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
    }
  }

  /// رفض/حذف طلب صداقة
  Future<void> declineFriendRequest(String requestId) async {
    try {
      await _firestore
          .collection('friend_requests')
          .doc(requestId)
          .update({'status': 'declined'});
    } catch (e) {
      debugPrint('Error declining friend request: $e');
    }
  }

  /// إلغاء طلب أرسلته أنا
  Future<void> cancelFriendRequest(String myUid, String targetUid) async {
    try {
      await _firestore
          .collection('friend_requests')
          .doc('${myUid}_$targetUid')
          .delete();
    } catch (e) {
      debugPrint('Error canceling friend request: $e');
    }
  }

  /// حذف صديق
  Future<void> removeFriend(String myUid, String friendUid) async {
    try {
      await _firestore.collection('users').doc(myUid).collection('friends').doc(friendUid).delete();
    } catch (e) {
      debugPrint('Error removing friend: $e');
    }
  }

  /// حظر لاعب
  Future<void> blockUser(String myUid, String blockedUid, String reason) async {
    try {
      await _firestore.collection('users').doc(myUid).collection('blocked').doc(blockedUid).set({
        'reason': reason,
        'blockedAt': FieldValue.serverTimestamp(),
      });
      // أيضا إزالته من قائمة الأصدقاء إذا كان مضافاً
      await removeFriend(myUid, blockedUid);
    } catch (e) {
      debugPrint('Error blocking user: $e');
    }
  }

  /// إلغاء حظر لاعب
  Future<void> unblockUser(String myUid, String blockedUid) async {
    try {
      await _firestore.collection('users').doc(myUid).collection('blocked').doc(blockedUid).delete();
    } catch (e) {
      debugPrint('Error unblocking user: $e');
    }
  }

  /// الحصول على معرّف محادثة موحد بين شخصين
  String getConversationId(String uid1, String uid2) {
    final list = [uid1, uid2]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// بث رسائل محادثة معينة
  Stream<List<ChatMessage>> getMessagesStream(String conversationId, String myUid) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .limitToLast(60)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromMap(d.id, d.data(), myUid)).toList());
  }

  /// بث قائمة محادثاتي الحقيقية مع آخر رسالة وعدد غير المقروء
  Stream<List<ConversationSummary>> getConversationsStream(String myUid) {
    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: myUid)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) {
        final d = doc.data();
        final participants =
            (d['participants'] as List?)?.cast<String>() ?? [];
        final otherUid = participants.firstWhere(
          (p) => p != myUid,
          orElse: () => '',
        );
        final pdata =
            (d['participantData'] as Map?)?.cast<String, dynamic>() ?? {};
        final other =
            (pdata[otherUid] as Map?)?.cast<String, dynamic>() ?? {};
        return ConversationSummary(
          id: doc.id,
          otherUid: otherUid,
          otherName: other['name'] ?? 'لاعب',
          otherUsername: other['username'] ?? '',
          otherPhoto: other['photo'] ?? '',
          lastMessage: d['lastMessage'] ?? '',
          lastTime: d['lastUpdated'] is Timestamp
              ? (d['lastUpdated'] as Timestamp).toDate()
              : DateTime.now(),
          unreadCount:
              (d['unread_$myUid'] as num?)?.toInt() ?? 0,
        );
      }).where((c) => c.otherUid.isNotEmpty).toList();
      list.sort((a, b) => b.lastTime.compareTo(a.lastTime));
      return list;
    });
  }

  /// تصفير عدّاد الرسائل غير المقروءة عند فتح المحادثة
  Future<void> markConversationRead(String convId, String myUid) async {
    try {
      await _firestore
          .collection('conversations')
          .doc(convId)
          .set({'unread_$myUid': 0}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error marking read: $e');
    }
  }

  /// إرسال رسالة في الشات
  Future<void> sendMessage({
    required String senderUid,
    required String senderName,
    required String senderUsername,
    required String senderPhoto,
    required String receiverUid,
    required String receiverName,
    required String receiverUsername,
    required String receiverPhoto,
    required String text,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final convId = getConversationId(senderUid, receiverUid);

    try {
      // 1. إضافة الرسالة
      await _firestore.collection('conversations').doc(convId).collection('messages').add({
        'senderId': senderUid,
        'senderName': senderName,
        'text': cleanText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. تحديث ملخص المحادثة + زيادة عدّاد غير المقروء عند المستقبِل
      await _firestore.collection('conversations').doc(convId).set({
        'participants': [senderUid, receiverUid],
        'lastMessage': cleanText,
        'lastSenderId': senderUid,
        'lastUpdated': FieldValue.serverTimestamp(),
        'unread_$receiverUid': FieldValue.increment(1),
        'unread_$senderUid': 0,
        'participantData': {
          senderUid: {
            'name': senderName,
            'username': senderUsername,
            'photo': senderPhoto,
          },
          receiverUid: {
            'name': receiverName,
            'username': receiverUsername,
            'photo': receiverPhoto,
          },
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  /// إرسال بلاغ ضد لاعب للإدارة
  Future<bool> reportUser({
    required String reporterUid,
    required String reporterName,
    required String reportedUid,
    required String reportedUsername,
    required String reason,
    required String details,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterUid': reporterUid,
        'reporterName': reporterName,
        'reportedUid': reportedUid,
        'reportedUsername': reportedUsername,
        'reason': reason,
        'details': details,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error submitting report: $e');
      return false;
    }
  }

  /// إرسال تذكرة دعم واقتراحات
  Future<bool> submitSupportTicket({
    required String uid,
    required String username,
    required String subject,
    required String message,
    required String category,
  }) async {
    try {
      await _firestore.collection('support_tickets').add({
        'uid': uid,
        'username': username,
        'subject': subject,
        'message': message,
        'category': category,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error submitting support ticket: $e');
      return false;
    }
  }
}
