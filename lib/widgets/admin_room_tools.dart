import 'package:flutter/material.dart';
import '../services/admin_power_service.dart';
import '../services/auth_service.dart';
import '../services/okey_room_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../l10n/app_lang.dart';

/// لوحة أدوات الإدارة داخل غرفة الكونكان — تفتح من زر 👑
/// وتظهر فقط لمن يملك وثيقة admins/{uid} (القواعد ترفض الباقي
/// حتى لو وصلوا للواجهة بطريقة ما)
class AdminRoomToolsSheet extends StatelessWidget {
  final OkeyRoom room;
  const AdminRoomToolsSheet({super.key, required this.room});

  static const _gold = Color(0xFFFFD54F);
  static const _cyan = Color(0xFF38BDF8);
  static const _red = Color(0xFFEF5350);
  static const _textDim = Color(0xFF8EA3C8);

  /// الزر الذهبي العائم الذي يفتح اللوحة — لا يُرسم إلا للأدمن
  static Widget entryButton(BuildContext context, OkeyRoom room) {
    if (!AdminPowerService().isAdmin) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => AdminRoomToolsSheet(room: room),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _gold.withOpacity(0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _gold.withOpacity(0.5)),
        ),
        child: Text('👑 ${'أدوات الإدارة'.tr}',
            style: const TextStyle(
                color: _gold, fontSize: 11.5, fontWeight: FontWeight.w800)),
      ),
    );
  }

  void _toast(BuildContext ctx, String msg, {IconData? icon}) {
    if (ctx.mounted) {
      TopNotification.show(ctx, msg, icon: icon ?? Icons.check_rounded);
    }
  }

  // ═══ حوار اختيار مبلغ الهدية ═══
  Future<void> _pickAmount(
    BuildContext ctx, {
    required String title,
    required void Function(int chips, int gems) onPick,
    bool chipsOnly = false,
  }) async {
    String kind = 'chips';
    await showDialog(
      context: ctx,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => AlertDialog(
          backgroundColor: const Color(0xFF141B33),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0x40FFD54F))),
          title: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!chipsOnly) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final k in ['chips', 'gems'])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(k == 'chips' ? '🪙 رقائق' : '💎 جواهر'),
                          selected: kind == k,
                          onSelected: (_) => setD(() => kind = k),
                          selectedColor: _gold.withOpacity(0.25),
                          labelStyle: TextStyle(
                              color: kind == k ? _gold : _textDim,
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final v in (kind == 'chips'
                      ? [1000, 5000, 25000]
                      : [50, 200, 1000]))
                    GestureDetector(
                      onTap: () {
                        Navigator.of(dctx).pop();
                        onPick(kind == 'chips' ? v : 0, kind == 'gems' ? v : 0);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2A5E).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _gold.withOpacity(0.4)),
                        ),
                        child: Text('$v',
                            style: const TextStyle(
                                color: _gold,
                                fontWeight: FontWeight.w900,
                                fontSize: 15)),
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

  Future<void> _confirm(
    BuildContext ctx, {
    required String title,
    required String body,
    required Future<bool> Function() action,
    required String done,
  }) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B33),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x40EF5350))),
        title: Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15)),
        content: Text(body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _textDim, fontSize: 12.5)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('إلغاء'.tr, style: const TextStyle(color: _textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text('تأكيد'.tr,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true && ctx.mounted) {
      final success = await action();
      _toast(ctx, success ? done : 'تعذّر التنفيذ'.tr,
          icon: success ? Icons.check_rounded : Icons.error_outline_rounded);
    }
  }

  /// حوار إعلان الغرفة — نص يظهر شريطاً لكل المتواجدين
  Future<void> _noticeDialog(BuildContext ctx) async {
    final ctrl = TextEditingController();
    final sent = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B33),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x40FFD54F))),
        title: Text('إعلان داخل الغرفة 📢'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15)),
        content: TextField(
          controller: ctrl,
          maxLength: 80,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'اكتب رسالة تظهر لكل المتواجدين…'.tr,
            hintStyle: const TextStyle(color: _textDim, fontSize: 12),
            filled: true,
            fillColor: const Color(0x40000000),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('إلغاء'.tr, style: const TextStyle(color: _textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _gold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text('انشر'.tr,
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (sent == true && ctx.mounted) {
      final ok =
          await AdminPowerService().setRoomNotice(room.id, ctrl.text.trim());
      _toast(ctx, ok ? 'نُشر الإعلان 📢'.tr : 'تعذّر النشر'.tr);
    }
  }

  /// كشف الأيدي — للمراجعة وكشف الغش
  Future<void> _peekHands(BuildContext ctx) async {
    final hands = await AdminPowerService().peekHands(room.id);
    if (!ctx.mounted) return;
    showDialog(
      context: ctx,
      builder: (dctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B33),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x40FFD54F))),
        title: Text('👁 أيدي اللاعبين — سرية'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14)),
        content: SizedBox(
          width: 300,
          child: hands.isEmpty
              ? Text('لا توجد أيدٍ محفوظة لهذه الجولة'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textDim, fontSize: 12))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final h in hands)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B2A5E).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_playerName(h['uid'])}\n${h.toString()}',
                            style: const TextStyle(
                                color: _textDim, fontSize: 10, height: 1.4),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text('إغلاق'.tr, style: const TextStyle(color: _gold)),
          ),
        ],
      ),
    );
  }

  String _playerName(String uid) {
    for (final p in room.players) {
      if (p.uid == uid) return p.name;
    }
    return uid.length > 8 ? uid.substring(0, 8) : uid;
  }

  /// قائمة إجراءات اللاعب الواحد
  void _playerActions(BuildContext ctx, OkeyRoomPlayer p) {
    AppHaptics.selection();
    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF141B33),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (bctx) {
        Widget action(IconData ic, String label, Color color,
            Future<void> Function() run) {
          return ListTile(
            dense: true,
            leading: Icon(ic, color: color, size: 20),
            title: Text(label,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            onTap: () async {
              Navigator.of(bctx).pop();
              await run();
            },
          );
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('${p.isAdmin ? '👑 ' : ''}${p.name}',
                    style: const TextStyle(
                        color: _gold,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
              ),
              if (!p.isBot) ...[
                action(Icons.card_giftcard_rounded, 'إهداء رقائق/جواهر 🎁'.tr,
                    _gold, () async {
                  await _pickAmount(ctx, title: '${'إهداء إلى'.tr} ${p.name}',
                      onPick: (c, g) async {
                    final ok = await AdminPowerService()
                        .giftTo(toUid: p.uid, chips: c, gems: g);
                    _toast(
                        ctx, ok ? 'أُرسلت الهدية 🎁'.tr : 'تعذّر الإرسال'.tr);
                  });
                }),
                action(Icons.mic_off_rounded, 'كتم 10 دقائق 🔇'.tr, _cyan,
                    () async {
                  final ok =
                      await AdminPowerService().mutePlayer(p.uid, minutes: 10);
                  _toast(ctx, ok ? 'كُتم ${p.name} 🔇'.tr : 'تعذّر الكتم'.tr);
                }),
                action(Icons.mic_off_rounded, 'كتم ساعة 🔇'.tr, _cyan,
                    () async {
                  final ok =
                      await AdminPowerService().mutePlayer(p.uid, minutes: 60);
                  _toast(ctx, ok ? 'كُتم ${p.name} 🔇'.tr : 'تعذّر الكتم'.tr);
                }),
                action(Icons.mic_rounded, 'فك الكتم 🔊'.tr, _cyan, () async {
                  final ok = await AdminPowerService().unmutePlayer(p.uid);
                  _toast(ctx, ok ? 'فُكّ الكتم 🔊'.tr : 'تعذّر'.tr);
                }),
                action(Icons.exit_to_app_rounded, 'طرد من الغرفة 👢'.tr, _red,
                    () async {
                  final ok =
                      await AdminPowerService().kickPlayer(room.id, p.uid);
                  _toast(ctx, ok ? 'طُرد ${p.name} 👢'.tr : 'تعذّر الطرد'.tr);
                }),
                action(Icons.timer_off_rounded, 'حظر مؤقت يوم ⛔'.tr, _red,
                    () async {
                  final ok = await AdminPowerService().tempBan(p.uid, days: 1);
                  _toast(
                      ctx, ok ? 'حُظر ${p.name} يوماً ⛔'.tr : 'تعذّر الحظر'.tr);
                }),
                action(Icons.timer_off_rounded, 'حظر مؤقت أسبوع ⛔'.tr, _red,
                    () async {
                  final ok = await AdminPowerService().tempBan(p.uid, days: 7);
                  _toast(ctx,
                      ok ? 'حُظر ${p.name} أسبوعاً ⛔'.tr : 'تعذّر الحظر'.tr);
                }),
              ] else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('روبوت — لا إجراءات إدارية'.tr,
                      style: const TextStyle(color: _textDim, fontSize: 12)),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = AdminPowerService();
    final me = AuthService().currentUser;

    Widget actionChip(String emoji, String label, VoidCallback onTap,
        {Color color = _gold}) {
      return GestureDetector(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0D1330),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _textDim.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('👑', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('أدوات الإدارة'.tr,
                        style: const TextStyle(
                            color: _gold,
                            fontSize: 17,
                            fontWeight: FontWeight.w900)),
                  ),
                  // وضع التخفي — يخفي التاج عن بقية اللاعبين
                  GestureDetector(
                    onTap: () async {
                      AppHaptics.selection();
                      await svc.toggleStealth();
                      _toast(
                          context,
                          (me?.adminStealth ?? false)
                              ? 'ظهرتَ للجميع 👑'.tr
                              : 'أنت الآن متخفٍ 🕶'.tr);
                    },
                    child: AnimatedBuilder(
                      animation: AuthService(),
                      builder: (_, __) {
                        final stealth =
                            AuthService().currentUser?.adminStealth ?? false;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (stealth ? _cyan : _gold).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    (stealth ? _cyan : _gold).withOpacity(0.5)),
                          ),
                          child: Text(
                            stealth ? '🕶 متخفٍ'.tr : '👑 ظاهر'.tr,
                            style: TextStyle(
                                color: stealth ? _cyan : _gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── الإجراءات السريعة ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  actionChip('🎁', 'إهداء الجميع'.tr, () {
                    _pickAmount(context, title: 'إهداء جماعي لكل اللاعبين'.tr,
                        onPick: (c, g) async {
                      final n = await svc.giftAll(
                          players: room.players, chips: c, gems: g);
                      _toast(context, 'وصلت الهدية إلى {} لاعباً 🎁'.trp([n]));
                    });
                  }),
                  actionChip('🧰', 'صندوق كنز'.tr, () {
                    _pickAmount(context,
                        title: 'جائزة صندوق الكنز — أول من يفتحه يأخذها'.tr,
                        onPick: (c, g) async {
                      final ok =
                          await svc.plantTreasure(room.id, chips: c, gems: g);
                      _toast(context, ok ? 'زُرع الكنز 🧰'.tr : 'تعذّر'.tr);
                    });
                  }),
                  actionChip('⚡', 'جائزة خاطفة للفائز'.tr, () {
                    _pickAmount(context,
                        title: 'جائزة الفائز بهذه الجولة'.tr,
                        chipsOnly: true, onPick: (c, g) async {
                      final ok = await svc.setFlashPrize(room.id, c);
                      _toast(
                          context, ok ? 'جائزة الفائز: $c 🪙'.tr : 'تعذّر'.tr);
                    });
                  }),
                  actionChip(
                      '📢', 'إعلان للغرفة'.tr, () => _noticeDialog(context),
                      color: _cyan),
                  if (room.status == 'playing')
                    actionChip('👁', 'كشف الأيدي'.tr, () => _peekHands(context),
                        color: _cyan),
                  if (room.status == 'playing')
                    actionChip('🏁', 'إنهاء الجولة'.tr, () {
                      _confirm(context,
                          title: 'إنهاء الجولة 🏁'.tr,
                          body: 'ستُنهى الجولة الحالية فوراً لكل اللاعبين.'.tr,
                          action: () => svc.endRound(room.id),
                          done: 'أُرسل أمر الإنهاء 🏁'.tr);
                    }, color: _red),
                ],
              ),

              const SizedBox(height: 14),
              Text('لاعبو الغرفة'.tr,
                  style: const TextStyle(
                      color: _textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),

              // ── اللاعبون — إجراءات فردية ──
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: room.players.length,
                  itemBuilder: (_, i) {
                    final p = room.players[i];
                    final isMe = p.uid == me?.uid;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor:
                            const Color(0xFF1B2A5E).withOpacity(0.6),
                        child: Text(p.isBot ? '🤖' : (p.isAdmin ? '👑' : '🧑'),
                            style: const TextStyle(fontSize: 13)),
                      ),
                      title: Text('${p.name}${isMe ? ' (${'أنت'.tr})' : ''}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                          p.isBot ? 'روبوت'.tr : '${p.tileCount} ${'حجر'.tr}',
                          style:
                              const TextStyle(color: _textDim, fontSize: 10.5)),
                      trailing: p.uid != me?.uid
                          ? const Icon(Icons.tune_rounded,
                              color: _gold, size: 18)
                          : null,
                      onTap: p.uid != me?.uid
                          ? () => _playerActions(context, p)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
