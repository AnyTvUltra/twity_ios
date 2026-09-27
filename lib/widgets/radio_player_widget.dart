import 'package:flutter/material.dart';
import '../services/radio_service.dart';
import '../utils/haptics.dart';

class RadioPlayerSheet extends StatefulWidget {
  const RadioPlayerSheet({super.key});

  static void show(BuildContext context) {
    AppHaptics.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const RadioPlayerSheet(),
    );
  }

  @override
  State<RadioPlayerSheet> createState() => _RadioPlayerSheetState();
}

class _RadioPlayerSheetState extends State<RadioPlayerSheet> {
  String _selectedGroup = 'all';

  @override
  Widget build(BuildContext context) {
    final radio = RadioService();
    final groups = radio.groups;
    final stations = radio.stationsFor(_selectedGroup);

    return AnimatedBuilder(
      animation: radio,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B2338), Color(0xFF0D1424)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0x40FFD54F), width: 1.2),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 24, offset: const Offset(0, -6)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x33FFD54F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.radio_rounded, color: Color(0xFFFFD54F), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'راديو اللعبة المباشر 📻',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'صوت شخصي خاص بك لا يؤثر على باقي اللاعبين',
                            style: TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Current Playing Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: radio.isPlaying
                        ? [const Color(0xFF5B21B6), const Color(0xFF3B0764)]
                        : [const Color(0xFF26183B), const Color(0xFF1B0F2B)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: radio.isPlaying ? const Color(0xFFFFD54F) : Colors.white12,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(radio.currentStation.flag, style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            radio.currentStation.name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            radio.currentStation.genre,
                            style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      iconSize: 42,
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        radio.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                        color: const Color(0xFFFFD54F),
                      ),
                      onPressed: () {
                        AppHaptics.selection();
                        radio.togglePlay();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Volume Slider
              Row(
                children: [
                  const Icon(Icons.volume_mute_rounded, color: Colors.white54, size: 18),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFFFFD54F),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFFFFD54F),
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: radio.volume,
                        onChanged: (val) => radio.setVolume(val),
                      ),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, color: Color(0xFFFFD54F), size: 18),
                ],
              ),
              const SizedBox(height: 12),

              // Stations List
              const Align(
                alignment: Alignment.centerRight,
                child: Text('اختر مجموعة ثم محطة:', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),

              // مجموعات الأغاني
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _groupChip('all', '📻', 'الكل'),
                    ...groups.map(
                      (g) => _groupChip(g.id, g.flag, g.name),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 140,
                child: stations.isEmpty
                    ? const Center(
                        child: Text('لا توجد أغاني في هذه المجموعة',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        itemCount: stations.length,
                        itemBuilder: (context, index) {
                          final station = stations[index];
                          final isCurrent =
                              radio.currentStation.id == station.id;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 0),
                            leading: Text(station.flag,
                                style: const TextStyle(fontSize: 20)),
                            title: Text(
                              station.name,
                              style: TextStyle(
                                color: isCurrent
                                    ? const Color(0xFFFFD54F)
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: isCurrent
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(station.genre,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 10.5)),
                            trailing: isCurrent && radio.isPlaying
                                ? const Icon(Icons.graphic_eq_rounded,
                                    color: Color(0xFFFFD54F), size: 18)
                                : null,
                            onTap: () {
                              AppHaptics.selection();
                              radio.playStationById(station.id);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _groupChip(String id, String flag, String name) {
    final sel = _selectedGroup == id;
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        setState(() => _selectedGroup = id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsetsDirectional.only(end: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? const Color(0x33FFD54F) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: sel ? const Color(0xFFFFD54F) : Colors.white12,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              name,
              style: TextStyle(
                color: sel ? const Color(0xFFFFD54F) : Colors.white70,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
