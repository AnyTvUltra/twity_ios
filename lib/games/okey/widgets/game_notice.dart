import 'package:flutter/material.dart';
import '../../../utils/top_notification.dart';

/// قناة إشعارات داخل مشهد الأوكي المدوَّر — تضمن أن كل إشعار يظهر
/// أفقيًا باتجاه اللعبة وليس باتجاه الجهاز
class GameNotice {
  GameNotice._();

  /// معالج الإشعار داخل المشهد (يُسجَّل من شاشة اللعبة)
  static void Function(String message, {IconData? icon})? handler;

  static void show(BuildContext context, String message, {IconData? icon}) {
    final h = handler;
    if (h != null) {
      h(message, icon: icon);
      return;
    }
    TopNotification.show(context, message);
  }
}

/// يعرض حواراً باتجاه أفقي مطابق لاتجاه طاولة الأوكي.
/// عندما يكون الهاتف عمودياً والمشهد مدار 90°، يُدار الحوار بنفس الاتجاه
/// حتى لا يظهر بشكل جانبي عمودي.
Future<T?> showOkeyLandscapeDialog<T>(BuildContext context,
    {required Widget Function(BuildContext) builder,
    Color? barrierColor,
    bool barrierDismissible = true}) {
  final media = MediaQuery.of(context);
  final rotated = media.orientation == Orientation.portrait;
  return showDialog<T>(
    context: context,
    barrierColor: barrierColor ?? Colors.black.withOpacity(0.65),
    barrierDismissible: barrierDismissible,
    builder: (ctx) {
      if (!rotated) return builder(ctx);
      // صندوق بمقاس أفقي (مقاسات الشاشة معكوسة) يُدار 90° ليطابق اتجاه اللعبة
      return RotatedBox(
        quarterTurns: 1,
        child: SizedBox(
          width: media.size.height,
          height: media.size.width,
          child: MediaQuery(
            data:
                media.copyWith(size: Size(media.size.height, media.size.width)),
            child: Center(child: builder(ctx)),
          ),
        ),
      );
    },
  );
}
