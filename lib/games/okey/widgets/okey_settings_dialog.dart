import 'package:flutter/material.dart';
import 'package:game_hub/utils/haptics.dart';
import 'package:game_hub/utils/top_notification.dart';
import '../utils/okey_audio.dart';

class OkeySettingsDialog extends StatefulWidget {
  final VoidCallback onStateChanged;

  const OkeySettingsDialog({super.key, required this.onStateChanged});

  static Future<void> show(BuildContext context, {required VoidCallback onStateChanged}) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (_) => OkeySettingsDialog(onStateChanged: onStateChanged),
    );
  }

  @override
  State<OkeySettingsDialog> createState() => _OkeySettingsDialogState();
}

class _OkeySettingsDialogState extends State<OkeySettingsDialog> {
  bool _sound = OkeyAudio.soundEnabled;
  bool _music = OkeyAudio.musicEnabled;
  double _volume = OkeyAudio.sfxVolume;
  String _selectedLang = 'العربية';
  int _selectedTimer = 72;

  final List<String> _languages = ['English', 'Türkçe', 'العربية', 'کوردی'];
  final List<int> _timerOptions = [30, 60, 72, 90];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      child: Container(
        width: 440,
        decoration: BoxDecoration(
          color: const Color(0xF5161C28),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x334ADE80), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // العنوان
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.settings_rounded, color: Color(0xFF4ADE80), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'إعدادات اللعبة (Settings)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0x33FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // المؤثرات الصوتية
            _buildSwitchRow(
              icon: Icons.volume_up_rounded,
              title: 'المؤثرات الصوتية (SFX)',
              value: _sound,
              onChanged: (val) {
                setState(() => _sound = val);
                OkeyAudio.soundEnabled = val;
                widget.onStateChanged();
              },
            ),
            const Divider(color: Color(0x22FFFFFF), height: 16),

            // الموسيقى
            _buildSwitchRow(
              icon: Icons.music_note_rounded,
              title: 'الموسيقى الخلفية (Music)',
              value: _music,
              onChanged: (val) {
                setState(() => _music = val);
                OkeyAudio.musicEnabled = val;
                widget.onStateChanged();
              },
            ),
            const Divider(color: Color(0x22FFFFFF), height: 16),

            // مستوى الصوت
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 10),
                const Text(
                  'مستوى الصوت',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF4ADE80),
                      thumbColor: const Color(0xFF4ADE80),
                      inactiveTrackColor: const Color(0x33FFFFFF),
                    ),
                    child: Slider(
                      value: _volume,
                      min: 0.0,
                      max: 1.0,
                      onChanged: (val) {
                        setState(() => _volume = val);
                        OkeyAudio.sfxVolume = val;
                      },
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0x22FFFFFF), height: 16),

            // وقت الدور
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.timer_outlined, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'مدة الدور (Turn Timer)',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _timerOptions.map((t) {
                    final isSel = _selectedTimer == t;
                    return GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() => _selectedTimer = t);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF22C55E) : const Color(0x22FFFFFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${t}s',
                          style: TextStyle(
                            color: isSel ? Colors.white : Colors.white70,
                            fontSize: 11,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const Divider(color: Color(0x22FFFFFF), height: 16),

            // اللغة
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.language_rounded, color: Colors.white70, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'اللغة (Language)',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: _languages.map((lang) {
                    final isSel = _selectedLang == lang;
                    return GestureDetector(
                      onTap: () {
                        AppHaptics.selection();
                        setState(() => _selectedLang = lang);
                        TopNotification.show(context, 'تم اختيار اللغة: $lang');
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF22C55E) : const Color(0x22FFFFFF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lang,
                          style: TextStyle(
                            color: isSel ? Colors.white : Colors.white70,
                            fontSize: 10.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        Switch(
          value: value,
          activeColor: const Color(0xFF4ADE80),
          onChanged: (val) {
            AppHaptics.selection();
            onChanged(val);
          },
        ),
      ],
    );
  }
}
