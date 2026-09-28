import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// إشعارات الإدارة — يستمع لأحدث رسالة في مجموعة broadcasts
/// ويعرضها للمستخدم مرة واحدة (تُخزَّن آخر رسالة مُشاهدة محلياً)
class BroadcastService {
  BroadcastService._();
  static final BroadcastService instance = BroadcastService._();

  static const _seenKey = 'last_broadcast_id';
  StreamSubscription<QuerySnapshot>? _sub;

  /// يبدأ الاستماع — onMessage تُستدعى برسالة جديدة لم تُعرض بعد
  void initialize(void Function(String title, String body) onMessage) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('broadcasts')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      final data = doc.data();

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_seenKey) == doc.id) return;

      final ts = data['createdAt'];
      final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
      await prefs.setString(_seenKey, doc.id);

      // رسالة قديمة؟ سجّلها كمُشاهدة بدون إزعاج المستخدم
      if (DateTime.now().difference(createdAt).inHours > 48) return;

      final title = (data['title'] ?? '📢 إشعار').toString();
      final body = (data['body'] ?? '').toString();
      if (body.isEmpty) return;
      onMessage(title, body);
    }, onError: (e) => debugPrint('Broadcast listener error: $e'));
  }

  /// آخر إشعارات الإدارة — لعرضها داخل لوحة الإشعارات
  Stream<List<BroadcastMessage>> recentStream() {
    return FirebaseFirestore.instance
        .collection('broadcasts')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final ts = data['createdAt'];
              return BroadcastMessage(
                id: d.id,
                title: (data['title'] ?? '📢 إشعار').toString(),
                body: (data['body'] ?? '').toString(),
                createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
              );
            }).toList());
  }

  void dispose() => _sub?.cancel();
}

class BroadcastMessage {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  const BroadcastMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });
}
