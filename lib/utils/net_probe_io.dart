import 'dart:async';
import 'dart:io';

/// فحص حقيقي للوصول للإنترنت — حلّ DNS سريع. الواجهة قد تبدو متصلة
/// بشبكة بلا إنترنت فعلي، وهذا الفحص يكشف ذلك.
Future<bool> probeInternet() async {
  try {
    await InternetAddress.lookup('firebase.google.com')
        .timeout(const Duration(seconds: 4));
    return true;
  } catch (_) {
    return false;
  }
}
