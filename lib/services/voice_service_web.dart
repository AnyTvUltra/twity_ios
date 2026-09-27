// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<Object?> requestAudioStream() async {
  final mediaDevices = html.window.navigator.mediaDevices;
  if (mediaDevices == null) return null;
  return mediaDevices.getUserMedia({'audio': true, 'video': false});
}

void stopAudioStream(Object? stream) {
  if (stream is! html.MediaStream) return;
  for (final track in stream.getAudioTracks()) {
    track.stop();
  }
}
