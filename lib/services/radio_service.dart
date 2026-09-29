import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_service.dart';
import '../l10n/app_lang.dart';
import 'radio_service_platform.dart'
    if (dart.library.html) 'radio_service_web.dart' as platform;

class RadioStation {
  final String id;
  final String name;
  final String genre;
  final String url;
  final String flag;
  final String groupId;

  const RadioStation({
    required this.id,
    required this.name,
    required this.genre,
    required this.url,
    required this.flag,
    this.groupId = '',
  });
}

/// مجموعة أغاني/محطات في الراديو — تُدار من لوحة الأدمن
class RadioGroup {
  final String id;
  final String name;
  final String flag;

  const RadioGroup({required this.id, required this.name, this.flag = '🎵'});
}

class RadioService extends ChangeNotifier {
  static final RadioService _instance = RadioService._internal();
  factory RadioService() => _instance;
  RadioService._internal();

  /// محطات احتياطية تُستخدم إن لم توجد بيانات في Firestore
  static List<RadioStation> _fallbackStations = [
    RadioStation(
      id: 'quran',
      name: 'إذاعة القرآن الكريم (القاهرة)'.tr,
      genre: 'قرآن وتلاوات'.tr,
      url: 'https://stream.radiojar.com/8s5u5tpdtwzuv',
      flag: '📖',
      groupId: '_default',
    ),
    RadioStation(
      id: 'rotana_tarab',
      name: 'روتانا طرب كلاسيك'.tr,
      genre: 'طرب وأصالة'.tr,
      url: 'https://stream.zeno.fm/f3wvbbqmdg8uv',
      flag: '🎶',
      groupId: '_default',
    ),
    RadioStation(
      id: 'mc_doualiya',
      name: 'مونت كارلو الدولية'.tr,
      genre: 'منوعات وأخبار'.tr,
      url: 'https://montecarlodoualiyaaudio.akacdn.perfora.net/mcd/all/mcd-128k.mp3',
      flag: '🌍',
      groupId: '_default',
    ),
    RadioStation(
      id: 'kral_pop',
      name: 'Kral Pop (تركيا)'.tr,
      genre: 'موسيقى تركية حماسية'.tr,
      url: 'https://kralwmedia.radyotvonline.net/kralpop/chunklist.m3u8',
      flag: '🇹🇷',
      groupId: '_default',
    ),
    RadioStation(
      id: 'lofi_gaming',
      name: 'Lofi Chillout Beats',
      genre: 'موسيقى هادئة للتركيز'.tr,
      url: 'https://stream.zeno.fm/0r0xa792kwzuv',
      flag: '🎧',
      groupId: '_default',
    ),
  ];

  static List<RadioGroup> _fallbackGroups = [
    RadioGroup(id: '_default', name: 'محطات عامة'.tr, flag: '📻'),
  ];

  List<RadioStation> _stations = _fallbackStations;
  List<RadioGroup> _groups = _fallbackGroups;

  List<RadioStation> get stations => _stations;
  List<RadioGroup> get groups => _groups;

  /// محطات مجموعة محددة (أو الكل عند تمرير 'all')
  List<RadioStation> stationsFor(String groupId) {
    if (groupId == 'all') return _stations;
    return _stations.where((s) => s.groupId == groupId).toList();
  }

  StreamSubscription<QuerySnapshot>? _groupsSub;
  StreamSubscription<QuerySnapshot>? _songsSub;
  List<RadioGroup> _remoteGroups = [];
  List<RadioStation> _remoteStations = [];
  bool _fsInitialized = false;

  /// الاشتراك في مجموعات وأغاني الراديو من Firestore (تُدار من لوحة الأدمن)
  void initialize() {
    if (_fsInitialized) return;
    _fsInitialized = true;
    final fb = FirebaseService();
    if (!fb.isInitialized) return;

    _groupsSub = fb.firestore
        .collection('radio_groups')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      _remoteGroups = snap.docs.map((d) {
        final data = d.data();
        return RadioGroup(
          id: d.id,
          name: data['name'] ?? 'مجموعة'.tr,
          flag: data['flag'] ?? '🎵',
        );
      }).toList();
      _rebuild();
    }, onError: (Object e) {
      debugPrint('Radio groups stream error: $e');
    });

    _songsSub = fb.firestore
        .collection('radio_songs')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      _remoteStations = snap.docs.map((d) {
        final data = d.data();
        final gid = data['groupId'] ?? '';
        final group = _remoteGroups.cast<RadioGroup?>().firstWhere(
              (g) => g?.id == gid,
              orElse: () => null,
            );
        return RadioStation(
          id: d.id,
          name: data['name'] ?? 'أغنية'.tr,
          genre: data['genre'] ?? (group?.name ?? ''),
          url: data['url'] ?? '',
          flag: group?.flag ?? '🎵',
          groupId: gid,
        );
      }).toList();
      _rebuild();
    }, onError: (Object e) {
      debugPrint('Radio songs stream error: $e');
    });
  }

  void _rebuild() {
    if (_remoteStations.isNotEmpty) {
      _stations = _remoteStations;
      _groups = _remoteGroups.isNotEmpty ? _remoteGroups : _fallbackGroups;
    } else {
      _stations = _fallbackStations;
      _groups = _fallbackGroups;
    }
    if (_currentStationIndex >= _stations.length) _currentStationIndex = 0;
    notifyListeners();
  }

  dynamic _audioElement;
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _currentStationIndex = 0;
  int get currentStationIndex => _currentStationIndex;
  RadioStation get currentStation =>
      _stations[_currentStationIndex.clamp(0, _stations.length - 1)];

  /// تشغيل محطة عبر معرفها (يُستخدم من واجهة المجموعات)
  void playStationById(String id) {
    final index = _stations.indexWhere((s) => s.id == id);
    if (index >= 0) playStation(index);
  }

  double _volume = 0.7;
  double get volume => _volume;

  void init() {
    if (kIsWeb) {
      try {
        _audioElement = platform.createRadioAudioElement(
          volume: _volume,
          onPlay: () {
            _isPlaying = true;
            notifyListeners();
          },
          onPause: () {
            _isPlaying = false;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('Radio stream error: $e');
            _isPlaying = false;
            notifyListeners();
          },
        );
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
        platform.playRadioAudio(_audioElement, stations[index].url);
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
          platform.pauseRadioAudio(_audioElement);
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
        platform.setRadioAudioVolume(_audioElement, _volume);
      } catch (_) {}
    }
    notifyListeners();
  }

  void stop() {
    if (kIsWeb && _audioElement != null) {
      try {
        platform.stopRadioAudio(_audioElement);
      } catch (_) {}
    }
    _isPlaying = false;
    notifyListeners();
  }
}
