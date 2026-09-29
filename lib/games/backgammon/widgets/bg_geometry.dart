import 'dart:math' as math;
import 'dart:ui';

/// هندسة لوح الطاولي — كل المواقع محسوبة من حجم اللوح (أفقي)
/// ترتيب الخانات من منظور اللاعب 0:
///  الصف السفلي من اليمين لليسار: 0..11 (بيتك 0..5 أسفل اليمين)
///  الصف العلوي من اليسار لليمين: 12..23 (بيت الخصم 18..23 أعلى اليمين)
class BgGeom {
  final Size size;

  late final double frame, trayW, barW, rim;
  late final Rect leftTray, rightTray, field, leftHalf, rightHalf, bar;
  late final double pointW, d, triH;

  BgGeom(this.size) {
    final w = size.width, h = size.height;
    frame = w * 0.028;
    trayW = w * 0.072;
    rim = w * 0.012;
    barW = w * 0.052;
    leftTray = Rect.fromLTWH(frame, frame, trayW, h - frame * 2);
    rightTray = Rect.fromLTWH(w - frame - trayW, frame, trayW, h - frame * 2);
    field = Rect.fromLTRB(leftTray.right + rim, frame, rightTray.left - rim,
        h - frame);
    final cx = field.center.dx;
    bar = Rect.fromLTRB(cx - barW / 2, 0, cx + barW / 2, h);
    leftHalf = Rect.fromLTRB(field.left, field.top, bar.left, field.bottom);
    rightHalf = Rect.fromLTRB(bar.right, field.top, field.right, field.bottom);
    pointW = leftHalf.width / 6;
    d = math.min(pointW * 0.92, field.height * 0.088);
    triH = field.height * 0.41;
  }

  bool isTop(int i) => i >= 12;

  double pointX(int i) {
    if (i <= 5) return rightHalf.right - (i + 0.5) * pointW;
    if (i <= 11) return leftHalf.right - (i - 6 + 0.5) * pointW;
    if (i <= 17) return leftHalf.left + (i - 12 + 0.5) * pointW;
    return rightHalf.left + (i - 18 + 0.5) * pointW;
  }

  double _spacing(int n) {
    final maxH = field.height * 0.45;
    if (n <= 1) return d;
    return math.min(d, (maxH - d) / (n - 1));
  }

  /// مركز الحجر رقم [k] في كومة من [n] أحجار على الخانة [i]
  Offset checker(int i, int k, int n) {
    final s = _spacing(n);
    final x = pointX(i);
    final pad = d * 0.08;
    if (isTop(i)) return Offset(x, field.top + pad + d / 2 + k * s);
    return Offset(x, field.bottom - pad - d / 2 - k * s);
  }

  /// أحجار البار: اللاعب 0 في النصف العلوي، اللاعب 1 في السفلي
  Offset barChecker(int side, int k, int n) {
    final s = math.min(d * 0.95, (field.height * 0.36 - d) / math.max(1, n - 1));
    final cy = size.height / 2;
    if (side == 0) return Offset(bar.center.dx, cy - d * 0.9 - k * s);
    return Offset(bar.center.dx, cy + d * 0.9 + k * s);
  }

  /// منطقة الإخراج لكل لاعب في الصينية اليمنى
  Rect offZone(int side) {
    final r = rightTray.deflate(trayW * 0.14);
    final half = (r.height - trayW * 0.3) / 2;
    return side == 0
        ? Rect.fromLTWH(r.left, r.bottom - half, r.width, half)
        : Rect.fromLTWH(r.left, r.top, r.width, half);
  }

  /// مستطيل الشريحة رقم [k] (حجر مُخرج مرسوم من الجانب)
  Rect offSlab(int side, int k) {
    final z = offZone(side);
    final t = z.height / 15;
    return side == 0
        ? Rect.fromLTWH(z.left, z.bottom - (k + 1) * t, z.width, t)
        : Rect.fromLTWH(z.left, z.top + k * t, z.width, t);
  }

  /// مثلث الخانة [i]
  Path triangle(int i) {
    final x = pointX(i);
    final hw = pointW / 2 - pointW * 0.04;
    final top = isTop(i);
    final base = top ? field.top : field.bottom;
    final tip = top ? field.top + triH : field.bottom - triH;
    return Path()
      ..moveTo(x - hw, base)
      ..lineTo(x + hw, base)
      ..lineTo(x + pointW * 0.06, tip - (top ? pointW * 0.08 : -pointW * 0.08))
      ..quadraticBezierTo(x, tip + (top ? pointW * 0.1 : -pointW * 0.1),
          x - pointW * 0.06, tip - (top ? pointW * 0.08 : -pointW * 0.08))
      ..close();
  }

  /// منطقة لمس الخانة (العمود كاملاً حتى منتصف اللوح)
  Rect pointHitRect(int i) {
    final x = pointX(i);
    final cy = size.height / 2;
    return isTop(i)
        ? Rect.fromLTRB(x - pointW / 2, 0, x + pointW / 2, cy)
        : Rect.fromLTRB(x - pointW / 2, cy, x + pointW / 2, size.height);
  }

  /// تحديد ما تحت الإصبع: 0..23 خانة، ‎-1 بار، 24 إخراج، null لا شيء
  int? hitTest(Offset p) {
    if (rightTray.inflate(rim).contains(p)) return 24;
    if (bar.contains(p)) return -1;
    for (int i = 0; i < 24; i++) {
      if (pointHitRect(i).contains(p)) return i;
    }
    return null;
  }
}
