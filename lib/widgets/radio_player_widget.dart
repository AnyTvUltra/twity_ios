import 'package:flutter/material.dart';
import '../services/radio_service.dart';
import '../utils/haptics.dart';
import '../l10n/app_lang.dart';

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

class _RadioPlayerSheetState extends State<RadioPlayerSheet>
    with SingleTickerProviderStateMixin {
  String _selectedGroup = 'all';
  late final AnimationController _eq;

  @override
  void initState() {
    super.initState();
    _eq = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _eq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radio = RadioService();
    final groups = radio.groups;
    final stations = radio.stationsFor(_selectedGroup);

    return AnimatedBuilder(
      animation: radio,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E2742), Color(0xFF0B1120)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: const Color(0x4DFFD54F), width: 1.2),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.7),
                  blurRadius: 24,
                  offset: const Offset(0, -6)),
            ],
          ),
          // تمرير داخلي + حد بالارتفاع المتاح — تظهر كاملة أيضاً في الوضع الأفقي
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── الترويسة: أيقونة + عنوان + شارة بث مباشر ───
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFFFE082), Color(0xFFF59E0B)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.radio_rounded,
                            color: Color(0xFF1B2338), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    'راديو اللعبة المباشر'.tr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (radio.isPlaying) _liveBadge(),
                              ],
                            ),
                            Text(
                              'صوت شخصي خاص بك لا يؤثر على باقي اللاعبين'.tr,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ─── بطاقة «يُشغَّل الآن» الزجاجية ───
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: radio.isPlaying
                            ? [const Color(0xFF6D28D9), const Color(0xFF2E1065)]
                            : [
                                const Color(0xFF2A2140),
                                const Color(0xFF191227)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: radio.isPlaying
                            ? const Color(0xFFFFD54F).withOpacity(0.8)
                            : Colors.white12,
                        width: 1,
                      ),
                      boxShadow: radio.isPlaying
                          ? [
                              BoxShadow(
                                color:
                                    const Color(0xFF7C3AED).withOpacity(0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        // قرص المحطة: علم داخل كبسولة زجاجية
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.22),
                                width: 1.2),
                          ),
                          child: Text(radio.currentStation.flag,
                              style: const TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                radio.currentStation.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                radio.currentStation.genre,
                                style: const TextStyle(
                                    color: Color(0xFFFFD54F), fontSize: 11),
                              ),
                              const SizedBox(height: 6),
                              // مؤشر الموجات — يتحرك أثناء البث
                              SizedBox(
                                height: 14,
                                child: _EqBars(
                                    controller: _eq, active: radio.isPlaying),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // زر تشغيل/إيقاف — قرص ذهبي بارز
                        GestureDetector(
                          onTap: () {
                            AppHaptics.selection();
                            radio.togglePlay();
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFE082), Color(0xFFF59E0B)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFF59E0B).withOpacity(0.45),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              radio.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: const Color(0xFF1B2338),
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── شريط الصوت داخل كبسولة ───
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.volume_mute_rounded,
                            color: Colors.white54, size: 18),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFFFD54F),
                              inactiveTrackColor: Colors.white12,
                              thumbColor: const Color(0xFFFFD54F),
                              overlayColor:
                                  const Color(0xFFFFD54F).withOpacity(0.15),
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                            ),
                            child: Slider(
                              value: radio.volume,
                              onChanged: (val) => radio.setVolume(val),
                            ),
                          ),
                        ),
                        const Icon(Icons.volume_up_rounded,
                            color: Color(0xFFFFD54F), size: 18),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── المحطات ───
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('اختر مجموعة ثم محطة:'.tr,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),

                  // مجموعات الأغاني
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _groupChip('all', '📻', 'الكل'.tr),
                        ...groups.map(
                          (g) => _groupChip(g.id, g.flag, g.name),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 150,
                    child: stations.isEmpty
                        ? Center(
                            child: Text('لا توجد أغاني في هذه المجموعة'.tr,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: stations.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final station = stations[index];
                              final isCurrent =
                                  radio.currentStation.id == station.id;
                              final live = isCurrent && radio.isPlaying;

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    AppHaptics.selection();
                                    radio.playStationById(station.id);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: isCurrent
                                          ? LinearGradient(colors: [
                                              const Color(0xFFFFD54F)
                                                  .withOpacity(0.16),
                                              const Color(0xFFF59E0B)
                                                  .withOpacity(0.08),
                                            ])
                                          : null,
                                      color: isCurrent
                                          ? null
                                          : Colors.white.withOpacity(0.045),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isCurrent
                                            ? const Color(0xFFFFD54F)
                                                .withOpacity(0.55)
                                            : Colors.white10,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(station.flag,
                                            style:
                                                const TextStyle(fontSize: 20)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                station.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                                              Text(station.genre,
                                                  style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 10.5)),
                                            ],
                                          ),
                                        ),
                                        if (live)
                                          SizedBox(
                                            width: 16,
                                            height: 14,
                                            child: _EqBars(
                                                controller: _eq,
                                                active: true,
                                                barColor:
                                                    const Color(0xFFFFD54F)),
                                          )
                                        else if (isCurrent)
                                          const Icon(Icons.pause_rounded,
                                              color: Color(0xFFFFD54F),
                                              size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// شارة البث المباشر — نقطة نابضة + LIVE
  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
                color: Color(0xFFEF4444), shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('مباشر'.tr,
              style: const TextStyle(
                  color: Color(0xFFFCA5A5),
                  fontSize: 9,
                  fontWeight: FontWeight.w900)),
        ],
      ),
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

/// أعمدة موجات صوتية متحركة — ثلاثة أعمدة تتمايل بإيقاع مختلف
class _EqBars extends StatelessWidget {
  final AnimationController controller;
  final bool active;
  final Color barColor;

  const _EqBars({
    required this.controller,
    required this.active,
    this.barColor = const Color(0xFFFFD54F),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final phase = (controller.value + i * 0.33) % 1.0;
            final wave =
                active ? 0.25 + 0.75 * (0.5 - (phase - 0.5).abs()) * 2 : 0.30;
            return Container(
              width: 2.5,
              height: 14 * wave.clamp(0.2, 1.0),
              margin: const EdgeInsetsDirectional.only(end: 2.5),
              decoration: BoxDecoration(
                color: active ? barColor : Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}
