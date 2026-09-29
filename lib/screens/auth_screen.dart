import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import '../utils/haptics.dart';

import '../utils/top_notification.dart';
import 'legal_screen.dart';
import '../widgets/app_background.dart';
import 'package:flutter/gestures.dart';
import '../l10n/app_lang.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  final TextEditingController _usernameController = TextEditingController();
  bool _isCheckingUsername = false;
  String? _usernameError;

  Future<void> _handleGoogleSignIn() async {
    AppHaptics.medium();
    setState(() => _isLoading = true);

    final success = await AuthService().signInWithGoogle();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _checkUsernameAndProceed();
    } else {
      if (mounted) {
        TopNotification.show(context, 'تعذر تسجيل الدخول، يرجى المحاولة مرة أخرى'.tr, icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _handleGuestSignIn() async {
    AppHaptics.light();
    setState(() => _isLoading = true);

    final success = await AuthService().signInAsGuest();
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _checkUsernameAndProceed();
    } else {
      if (mounted) {
        TopNotification.show(context, 'تعذر الدخول كضيف، يرجى المحاولة لاحقاً'.tr, icon: Icons.error_outline_rounded);
      }
    }
  }

  void _checkUsernameAndProceed() {
    final user = AuthService().currentUser;
    if (user == null) return;
    if (user.username.startsWith('user_') ||
        user.username.startsWith('player_')) {
      AuthService().beginUsernameSetup();
      _showUsernameSetupDialog();
    } else {
      AuthService().completeUsernameSetup();
      widget.onAuthenticated();
    }
  }

  void _showUsernameSetupDialog() {
    _usernameController.text = AuthService().currentUser?.username ?? '';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF5FFFFFF), Color(0xEAF0F5FC)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.badge_rounded, color: Color(0xFFD97706), size: 26),
                    SizedBox(width: 10),
                    Text(
                      'اختر اسم المستخدم الفريد'.tr,
                      style: TextStyle(color: LightGlass.text, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'اسم المستخدم هو هويتك الخاصة التي يستطيع أصدقاؤك البحث عنك وإضافتك من خلالها.'.tr,
                  style: TextStyle(color: LightGlass.textMuted, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: LightGlass.text, fontSize: 15, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFFD97706)),
                    hintText: 'مثال: okey_king'.tr,
                    hintStyle: const TextStyle(color: LightGlass.textFaint),
                    errorText: _usernameError,
                    filled: true,
                    fillColor: LightGlass.inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: LightGlass.borderDim),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD54F),
                    foregroundColor: const Color(0xFF1B0B30),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isCheckingUsername
                      ? null
                      : () async {
                          final input = _usernameController.text.trim();
                          if (input.length < 3) {
                            setDialogState(() => _usernameError = 'يجب أن يكون الاسم 3 أحرف على الأقل'.tr);
                            return;
                          }
                          setDialogState(() {
                            _isCheckingUsername = true;
                            _usernameError = null;
                          });

                          final available = await AuthService().isUsernameAvailable(input);
                          if (!available) {
                            setDialogState(() {
                              _isCheckingUsername = false;
                              _usernameError = 'اسم المستخدم مأخوذ بالفعل، اختر اسماً آخر'.tr;
                            });
                            return;
                          }

                          final updated = await AuthService().updateUsername(input);
                          if (!updated) {
                            setDialogState(() {
                              _isCheckingUsername = false;
                              _usernameError = 'تعذر حفظ اسم المستخدم، حاول مرة أخرى'.tr;
                            });
                            return;
                          }
                          Navigator.of(ctx).pop();
                          AuthService().completeUsernameSetup();
                          widget.onAuthenticated();
                        },
                  child: _isCheckingUsername
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B0B30)),
                        )
                      : Text('تأكيد وبدء اللعب 🚀'.tr, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8EDF5),
      body: AppBackground(
        light: true,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Hero Icon with Glow
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFEEA0), Color(0xFFFFD54F), Color(0xFFE58E00)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFD54F).withOpacity(0.5),
                          blurRadius: 28,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('🀄', style: TextStyle(fontSize: 48)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Game Title
                  Text(
                    'یەڵا یاری — Yalla Yari'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LightGlass.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تركيش أوكي • شطرنج • لودو • طاولي • سوليتر'.tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LightGlass.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Auth Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xF5FFFFFF), Color(0xEAF0F5FC)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x50FFD54F), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF64748B).withOpacity(0.18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'تسجيل الدخول للمتابعة'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: LightGlass.text, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'سجّل لحفظ رصيدك، أصدقائك، مستواك، والتنافس أونلاين ضد لاعبين حقيقيين!'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: LightGlass.textMuted, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 24),

                        // Google Sign-In Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF1F2937),
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                child: const Center(
                                  child: Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'تسجيل الدخول عبر Google'.tr,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Guest Mode Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: LightGlass.textSoft,
                            side: const BorderSide(color: LightGlass.borderDim, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isLoading ? null : _handleGuestSignIn,
                          icon: const Icon(Icons.person_outline_rounded, size: 20),
                          label: Text(
                            'الدخول كضيف وتجربة اللعب'.tr,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (_isLoading)
                    const CircularProgressIndicator(color: Color(0xFFFFD54F))
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: LightGlass.textFaint, size: 14),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'اتصال سحابي آمن ومشفر عبر Firebase'.tr,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: LightGlass.textMuted, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                            color: LightGlass.textMuted,
                            fontSize: 11,
                            height: 1.5),
                        children: [
                          TextSpan(text: 'بالمتابعة أنت توافق على '.tr),
                          TextSpan(
                            text: 'شروط الاستخدام'.tr,
                            style: const TextStyle(
                                color: Color(0xFF7DD3FC),
                                fontWeight: FontWeight.w700),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const LegalScreen(initialTab: 1))),
                          ),
                          TextSpan(text: ' و'.tr),
                          TextSpan(
                            text: 'سياسة الخصوصية'.tr,
                            style: const TextStyle(
                                color: Color(0xFF7DD3FC),
                                fontWeight: FontWeight.w700),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => const LegalScreen())),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
