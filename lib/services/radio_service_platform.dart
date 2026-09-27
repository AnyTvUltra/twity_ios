Object? createRadioAudioElement({
  required double volume,
  required void Function() onPlay,
  required void Function() onPause,
  required void Function(Object error) onError,
}) =>
    null;

void playRadioAudio(Object? element, String url) {}

void pauseRadioAudio(Object? element) {}

void stopRadioAudio(Object? element) {}

void setRadioAudioVolume(Object? element, double volume) {}
