import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/okey_room_service.dart';
import '../services/voice_service.dart';
import '../utils/haptics.dart';
import '../utils/top_notification.dart';
import '../widgets/app_background.dart';
import '../widgets/radio_player_widget.dart';
import 'okey_game_screen.dart';

class OkeyLobbyScreen extends StatefulWidget {
  const OkeyLobbyScreen({super.key});

  @override
  State<OkeyLobbyScreen> createState() => _OkeyLobbyScreenState();
}

class _OkeyLobbyScreenState extends State<OkeyLobbyScreen> {
  int _selectedStakes = 50;
  bool _isSearching = false;
  OkeyRoom? _currentRoom;
  StreamSubscription<OkeyRoom>? _roomSub;

  final List<Map<String, dynamic>> _stakeTiers = [
    {
      'stakes': 50,
      'pot': 200,
      'title': 'طاولة المبتدئين 🥉',
      'level': 'المستوى 1+',
      'color': const Color(0xFF10B981),
    },
    {
      'stakes': 200,
      'pot': 800,
      'title': 'طاولة المحترفين 🥈',
      'level': 'المستوى 5+',
      'color': const Color(0xFF3B82F6),
    },
    {
      'stakes': 1000,
      'pot': 4000,
      'title': 'طاولة كبار الشخصيات VIP 👑',
      'level': 'المستوى 10+',
      'color': const Color(0xFFFFD54F),
    },
  ];

  Future<void> _handleQuickMatch() async {
    final user = AuthService().currentUser;
    if (user == null) {
      TopNotification.show(context, 'يرجى تسجيل الدخول أولاً!', icon: Icons.lock_rounded);
      return;
    }

    if (user.chips < _selectedStakes) {
      TopNotification.show(context, 'رصيدك غير كافٍ لدخول هذه الطاولة! تحتاج $_selectedStakes عملة', icon: Icons.warning_rounded);
      return;
    }

    AppHaptics.medium();
    setState(() => _isSearching = true);

    final room = await OkeyRoomService().quickMatch(stakes: _selectedStakes, user: user);
    setState(() => _isSearching = false);

    if (room != null) {
      setState(() => _currentRoom = room);
      _listenToRoom(room.id);
    } else {
      if (mounted) {
        TopNotification.show(context, 'تعذر الدخول للطاولة، حاول مرة أخرى', icon: Icons.error_outline_rounded);
      }
    }
  }

  void _listenToRoom(String roomId) {
    _roomSub?.cancel();
    _roomSub = OkeyRoomService().getRoomStream(roomId).listen((room) {
      setState(() => _currentRoom = room);

      if (room.status == 'playing' && mounted) {
        // Start voice chat room connection
        VoiceService().joinRoomVoice(room.id);

        _roomSub?.cancel();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const OkeyGameScreen()),
        );
      }
    });
  }

  Future<void> _startWithBotsNow() async {
    if (_currentRoom == null) return;
    AppHaptics.medium();
    await OkeyRoomService().fillWithBotsAndStart(_currentRoom!.id, _currentRoom!.stakes);
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF160926),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Text(
                      'صالات تركيش أوكي أونلاين 🀄',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        // Radio button
                        IconButton(
                          icon: const Icon(Icons.radio_rounded, color: Color(0xFFFFD54F), size: 24),
                          onPressed: () => RadioPlayerSheet.show(context),
                        ),
                        // Coins badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xE625143E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x40FFD54F), width: 1),
                          ),
                          child: Row(
                            children: [
                              const Text('🪙', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                '${user?.chips ?? 0}',
                                style: const TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _currentRoom == null ? _buildTableSelection() : _buildWaitingRoom(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableSelection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B1E6D), Color(0xFF1E0E35)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x40FFD54F), width: 1.2),
            ),
            child: const Row(
              children: [
                Text('🏆', style: TextStyle(fontSize: 32)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تنافس حقيقي مع 4 لاعبين',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'اختر قيمة الرهان، وانضم لطاولة نشطة مع دردشة صوتية وراديو مباشر!',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const Text('اختر الطاولة:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          // Tiers List
          ..._stakeTiers.map((tier) {
            final stakes = tier['stakes'] as int;
            final pot = tier['pot'] as int;
            final isSelected = _selectedStakes == stakes;

            return GestureDetector(
              onTap: () {
                AppHaptics.selection();
                setState(() => _selectedStakes = stakes);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [const Color(0xFF5B21B6), const Color(0xFF2E1065)]
                        : [const Color(0xFF26143F), const Color(0xFF1A0B2E)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFFFD54F) : Colors.white12,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(color: const Color(0xFFFFD54F).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 3)),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (tier['color'] as Color).withOpacity(0.2),
                        border: Border.all(color: tier['color'] as Color, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          '$stakes',
                          style: TextStyle(color: tier['color'] as Color, fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tier['title'],
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'الجائزة الإجمالية للفائز: $pot عملة ذهبية 💰',
                            style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Radio<int>(
                      value: stakes,
                      groupValue: _selectedStakes,
                      activeColor: const Color(0xFFFFD54F),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedStakes = val);
                      },
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Join / Quick Play Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: const Color(0xFF1B0B30),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 8,
            ),
            onPressed: _isSearching ? null : _handleQuickMatch,
            child: _isSearching
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B0B30))),
                      SizedBox(width: 10),
                      Text('جاري البحث عن طاولة...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 24),
                      SizedBox(width: 8),
                      Text('دخول الطاولة وبدء التحدي 🀄', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingRoom() {
    final room = _currentRoom!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xEB23123B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x40FFD54F), width: 1.2),
            ),
            child: Column(
              children: [
                const Text('غرفة الانتظار 🪑', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('قيمة الرهان: ${room.stakes} 🪙 • الجائزة: ${room.stakes * 4} 💰', style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4 Seats View
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                final player = index < room.players.length ? room.players[index] : null;

                return Container(
                  decoration: BoxDecoration(
                    color: player != null ? const Color(0xFF3B1E6D) : const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: player != null ? const Color(0xFFFFD54F) : Colors.white12,
                      width: player != null ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: player != null ? const Color(0xFF5B3A82) : Colors.white10,
                        ),
                        child: Center(
                          child: Icon(
                            player != null ? Icons.person : Icons.chair_rounded,
                            color: player != null ? const Color(0xFFFFD54F) : Colors.white30,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        player != null ? player.name : 'مقعد فارغ',
                        style: TextStyle(
                          color: player != null ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (player != null)
                        Text(
                          player.isBot ? 'روبوت ذكي 🤖' : 'لاعب حقيقي 🟢',
                          style: TextStyle(color: player.isBot ? Colors.white54 : const Color(0xFF4ADE80), fontSize: 10),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Instant Start with Bots Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('بدء اللعبة فوراً (ملء المقاعد بروبوتات)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            onPressed: _startWithBotsNow,
          ),
        ],
      ),
    );
  }
}
