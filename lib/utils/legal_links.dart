import 'package:url_launcher/url_launcher.dart';

/// روابط الصفحات القانونية المنشورة على موقع اللعبة
/// (مطلوبة من App Store وGoogle Play)
class LegalLinks {
  LegalLinks._();

  static const privacyUrl = 'https://twity-game-hub.pages.dev/privacy.html';
  static const termsUrl = 'https://twity-game-hub.pages.dev/terms.html';
  static const deleteAccountUrl =
      'https://twity-game-hub.pages.dev/delete-account.html';

  static Future<void> open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<void> openPrivacy() => open(privacyUrl);
  static Future<void> openTerms() => open(termsUrl);
  static Future<void> openDeleteAccount() => open(deleteAccountUrl);
}
