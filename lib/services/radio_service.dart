import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class RadioStation {
  final String id;
  final String name;
  final String genre;
  final String url;
  final String flag;

  const RadioStation({
    required this.id,
    required this.name,
    required this.genre,
    required this.url,
    required this.flag,
  });
}

class RadioService extends ChangeNotifier {
  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;
  RadioService._internal();

  static const List<RadioStation> stations = [
    RadioStation(
      id: 'quran',
      name: 'إذاعة القرآن الكريم (القاهرة)',
      genre: 'قرآن وتلاوات',
      url: 'https://stream.radiojar.com/8s5u5tpdtwzuv',
      flag: '📖',
    ),
    RadioStation(
      id: 'rotana_tarab',
      name: 'روتانا طرب كلاسيك',
      genre: 'طرب وأصالة',
      url: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
      flag: '🎶',
    ),
    RadioStation(
      id: 'mc_doualiya',
      name: 'مونت كارلو الدولية',
      genre: 'منوعات وأخبار',
      url: 'https://montecarlodoualiyaaudio.akacdn.perfora.net/mcd/all/mcd-128k.mp3',
      flag: '🌍',
    ),
    RadioStation(
      id: 'kral_pop',
      name: 'Kral Pop (تركيا)',
      genre: 'موسيقى تركية حماسية',
      url: 'https://kralwmedia.radyotvonline.net/kralpop/chunklist.m3u8',
      flag: '🇹🇷',
    ),
    RadioStation(
      id: 'lofi_gaming',
      name: 'Lofi Chillout Beats',
      genre: 'موسيقى هادئة للتركيز',
      url: 'https://stream.zeno.fm/0r0xa792kwzuv',
      flag: '🎧',
    ),
  ];

  dynamic _audioElement;
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _currentStationIndex = 0;
  int get currentStationIndex => _currentStationIndex;
  RadioStation get currentStation => stations[_currentStationIndex];

  double _volume = 0.7;
  double get volume => _volume;

  void init() {
    if (kIsWeb) {
      try {
        _audioElement = html.AudioElement()
          ..preload = 'none'
          ..volume = _volume;

        _audioElement.onPlay.listen((_) {
          _isPlaying = true;
          notifyListeners();
        });

        _audioElement.onPause.listen((_) {
          _isPlaying = false;
          notifyListeners();
        });

        _audioElement.onError.listen((e) {
          debugPrint('Radio stream error: $e');
          _isPlaying = false;
          notifyListeners();
        });
      } catch (e) {
        debugPrint('Error creating HTML Audio element: $e');
      }
    }
  }

  void playStation(int index) {
    if (index < 0 || index >= stations.length) return;
    _currentStationIndex = index;
    if (kIsWeb) {
      if (_audioElement == null) init();
      try {
        _audioElement.src = stations[index].url;
        _audioElement.play();
        _isPlaying = true;
        notifyListeners();
      } catch (e) {
        debugPrint('Error playing radio station: $e');
      }
    } else {
      _isPlaying = true;
      notifyListeners();
    }
  }

  void togglePlay() {
    if (kIsWeb) {
      if (_audioElement == null) init();
      if (_isPlaying) {
        try {
          _audioElement.pause();
        } catch (_) {}
        _isPlaying = false;
      } else {
        playStation(_currentStationIndex);
      }
    } else {
      _isPlaying = !_isPlaying;
    }
    notifyListeners();
  }

  void nextStation() {
    final next = (_currentStationIndex + 1) % stations.length;
    playStation(next);
  }

  void setVolume(double vol) {
    _volume = vol.clamp(0.0, 1.0);
    if (kIsWeb && _audioElement != null) {
      try {
        _audioElement.volume = _volume;
      } catch (_) {}
    }
    notifyListeners();
  }

  void stop() {
    if (kIsWeb && _audioElement != null) {
      try {
        _audioElement.pause();
        _audioElement.src = '';
      } catch (_) {}
    }
    _isPlaying = false;
    notifyListeners();
  }
}
