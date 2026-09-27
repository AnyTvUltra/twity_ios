/// تنسيق أرقام الأرصدة: 1500 → 1.5K • 2500000 → 2.5M
String formatBalance(int n) {
  if (n >= 1000000) {
    final v = n / 1000000;
    return '${_trim(v)}M';
  }
  if (n >= 1000) {
    final v = n / 1000;
    return '${_trim(v)}K';
  }
  return '$n';
}

String _trim(double v) {
  if (v >= 100) return v.toStringAsFixed(0);
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toStringAsFixed(1);
}
