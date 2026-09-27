// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Object? createRadioAudioElement({
  required double volume,
  required void Function() onPlay,
  required void Function() onPause,
  required void Function(Object error) onError,
}) {
  final element = html.AudioElement()
    ..preload = 'none'
    ..volume = volume;

  element.onPlay.listen((_) => onPlay());
  element.onPause.listen((_) => onPause());
  element.onError.listen(onError);

  return element;
}

void playRadioAudio(Object? element, String url) {
  final audio = element as html.AudioElement?;
  if (audio == null) return;
  audio.src = url;
  audio.play();
}

void pauseRadioAudio(Object? element) {
  (element as html.AudioElement?)?.pause();
}

void stopRadioAudio(Object? element) {
  final audio = element as html.AudioElement?;
  if (audio == null) return;
  audio.pause();
  audio.src = '';
}

void setRadioAudioVolume(Object? element, double volume) {
  final audio = element as html.AudioElement?;
  if (audio != null) audio.volume = volume;
}
