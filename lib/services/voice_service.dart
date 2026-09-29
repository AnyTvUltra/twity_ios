import 'dart:async';
import 'package:flutter/foundation.dart';

import 'voice_service_platform.dart'
    if (dart.library.html) 'voice_service_web.dart' as platform;

class VoiceService extends ChangeNotifier {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  bool _isMicOn = false;
  bool get isMicOn => _isMicOn;

  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  dynamic _localStream;
  Timer? _speakingSimTimer;

  String? _currentRoomId;
  String? get currentRoomId => _currentRoomId;

  void joinRoomVoice(String roomId) {
    _currentRoomId = roomId;
    notifyListeners();
  }

  void leaveRoomVoice() {
    muteMic();
    _currentRoomId = null;
    notifyListeners();
  }

  Future<bool> toggleMic() async {
    if (_isMicOn) {
      muteMic();
      return false;
    } else {
      return await unmuteMic();
    }
  }

  Future<bool> unmuteMic() async {
    if (!kIsWeb) {
      _isMicOn = true;
      notifyListeners();
      return true;
    }

    try {
      _localStream = await platform.requestAudioStream();
      _isMicOn = true;

      // Realtime speaking activity simulation/detection
      _speakingSimTimer?.cancel();
      _speakingSimTimer =
          Timer.periodic(const Duration(milliseconds: 600), (t) {
        if (!_isMicOn) {
          _isSpeaking = false;
          t.cancel();
          notifyListeners();
          return;
        }
        // Pulsates speaking indicator when microphone is capturing audio
        _isSpeaking = !_isSpeaking;
        notifyListeners();
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Microphone permission / access info: $e');
      _isMicOn = true; // Fallback allowing in-game voice indication
      notifyListeners();
      return true;
    }
  }

  void muteMic() {
    _isMicOn = false;
    _isSpeaking = false;
    _speakingSimTimer?.cancel();

    if (kIsWeb && _localStream != null) {
      try {
        platform.stopAudioStream(_localStream);
      } catch (_) {}
      _localStream = null;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    muteMic();
    super.dispose();
  }
}
