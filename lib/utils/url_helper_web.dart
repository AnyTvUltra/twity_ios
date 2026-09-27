// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void openAdminWebImpl() {
  html.window.open('https://twity-admin.pages.dev', '_blank');
}

bool isWebPlatformImpl() => true;
