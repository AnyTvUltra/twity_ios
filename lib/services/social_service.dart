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

  ConversationSummary({
    required this.id,
    required this.otherUid,
    required this.otherName,
    required this.otherUsername,
    required this.otherPhoto,
    required this.lastMessage,
    required this.lastTime,
    this.isOnline = false,
  });
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

  /// إضافة صديق
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

  /// إرسال رسالة في الشات
  Future<void> sendMessage({
    required String senderUid,
    required String senderName,
    required String receiverUid,
    required String receiverName,
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

      // 2. تحديث ملخص المحادثة
      await _firestore.collection('conversations').doc(convId).set({
        'participants': [senderUid, receiverUid],
        'lastMessage': cleanText,
        'lastSenderId': senderUid,
        'lastUpdated': FieldValue.serverTimestamp(),
        'participantData': {
          senderUid: {'name': senderName},
          receiverUid: {'name': receiverName},
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
