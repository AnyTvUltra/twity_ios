import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String photoUrl;
  final int chips;
  final int rating;
  final int level;
  final int wins;
  final int losses;
  final DateTime? lastDailyGiftClaim;
  final int dailyGiftStreak;
  final bool isOnline;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    required this.photoUrl,
    this.chips = 1500,
    this.rating = 1200,
    this.level = 1,
    this.wins = 0,
    this.losses = 0,
    this.lastDailyGiftClaim,
    this.dailyGiftStreak = 0,
    this.isOnline = true,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    DateTime? lastClaim;
    if (data['lastDailyGiftClaim'] != null) {
      if (data['lastDailyGiftClaim'] is Timestamp) {
        lastClaim = (data['lastDailyGiftClaim'] as Timestamp).toDate();
      }
    }

    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'لاعب',
      username: data['username'] ?? 'user_${uid.substring(0, 6)}',
      photoUrl: data['photoUrl'] ?? '',
      chips: (data['chips'] as num?)?.toInt() ?? 1500,
      rating: (data['rating'] as num?)?.toInt() ?? 1200,
      level: (data['level'] as num?)?.toInt() ?? 1,
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      losses: (data['losses'] as num?)?.toInt() ?? 0,
      lastDailyGiftClaim: lastClaim,
      dailyGiftStreak: (data['dailyGiftStreak'] as num?)?.toInt() ?? 0,
      isOnline: data['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'username': username,
      'photoUrl': photoUrl,
      'chips': chips,
      'rating': rating,
      'level': level,
      'wins': wins,
      'losses': losses,
      'lastDailyGiftClaim': lastDailyGiftClaim != null ? Timestamp.fromDate(lastDailyGiftClaim!) : null,
      'dailyGiftStreak': dailyGiftStreak,
      'isOnline': isOnline,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? displayName,
    String? username,
    String? photoUrl,
    int? chips,
    int? rating,
    int? level,
    int? wins,
    int? losses,
    DateTime? lastDailyGiftClaim,
    int? dailyGiftStreak,
    bool? isOnline,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      chips: chips ?? this.chips,
      rating: rating ?? this.rating,
      level: level ?? this.level,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      lastDailyGiftClaim: lastDailyGiftClaim ?? this.lastDailyGiftClaim,
      dailyGiftStreak: dailyGiftStreak ?? this.dailyGiftStreak,
      isOnline: isOnline ?? this.isOnline,
    );
  }
}

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AppUser? _currentUser;
  AppUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  void initialize() {
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _fetchOrCreateUser(user);
      } else {
        _userDocSub?.cancel();
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> _fetchOrCreateUser(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        _currentUser = AppUser.fromMap(user.uid, doc.data()!);
        await docRef.update({'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()});
      } else {
        // Generate a clean default unique username based on name or uid
        String cleanName = user.displayName?.replaceAll(RegExp(r'\s+'), '_').toLowerCase() ?? 'player';
        cleanName = cleanName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
        if (cleanName.isEmpty) cleanName = 'player';
        final initialUsername = '${cleanName}_${user.uid.substring(0, 4)}';

        final newUser = AppUser(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'لاعب جديد',
          username: initialUsername,
          photoUrl: user.photoURL ?? '',
          chips: 1500,
          rating: 1200,
          level: 1,
        );

        await docRef.set(newUser.toMap());
        _currentUser = newUser;
      }

      // Realtime listener for balance / level changes
      _userDocSub?.cancel();
      _userDocSub = docRef.snapshots().listen((snapshot) {
        if (snapshot.exists && snapshot.data() != null) {
          _currentUser = AppUser.fromMap(user.uid, snapshot.data()!);
          notifyListeners();
        }
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching/creating user: $e');
    }
  }

  /// تسجيل الدخول عبر Google
  Future<bool> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        final userCredential = await _auth.signInWithPopup(googleProvider);
        if (userCredential.user != null) {
          await _fetchOrCreateUser(userCredential.user!);
          return true;
        }
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return false;

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          await _fetchOrCreateUser(userCredential.user!);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error in signInWithGoogle: $e');
    }
    return false;
  }

  /// الدخول كضيف سريع (Guest Mode)
  Future<bool> signInAsGuest() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      if (userCredential.user != null) {
        await _fetchOrCreateUser(userCredential.user!);
        return true;
      }
    } catch (e) {
      debugPrint('Firebase signInAnonymously info (falling back to guest session): $e');
    }

    // Fallback: إنشاء جلسة ضيف محلية فورية تضمن عمل التطبيق بنسبة 100% دون توقف
    final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    final guestUid = 'guest_$randomSuffix';
    _currentUser = AppUser(
      uid: guestUid,
      email: '',
      displayName: 'ضيف $randomSuffix',
      username: 'player_$randomSuffix',
      photoUrl: '',
      chips: 1500,
      rating: 1200,
      level: 1,
    );
    notifyListeners();
    return true;
  }

  /// التحقق من توفر اسم المستخدم الفريد
  Future<bool> isUsernameAvailable(String username) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.length < 3) return false;
    if (_currentUser != null && _currentUser!.username.toLowerCase() == cleanUsername) return true;

    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: cleanUsername)
        .limit(1)
        .get();

    return query.docs.isEmpty;
  }

  /// تحديث اسم المستخدم الفريد
  Future<bool> updateUsername(String newUsername) async {
    if (_currentUser == null) return false;
    final cleanUsername = newUsername.trim().toLowerCase();
    final available = await isUsernameAvailable(cleanUsername);
    if (!available) return false;

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'username': cleanUsername,
      });
      _currentUser = _currentUser!.copyWith(username: cleanUsername);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating username: $e');
      return false;
    }
  }

  /// تحديث الاسم المعروض والصورة الرمزية
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    if (_currentUser == null) return;
    try {
      final Map<String, dynamic> updates = {};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      await _firestore.collection('users').doc(_currentUser!.uid).update(updates);
      _currentUser = _currentUser!.copyWith(
        displayName: displayName,
        photoUrl: photoUrl,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  /// تحديث رصيد العملات والتقييم بعد المباراة
  Future<void> updateMatchResult({required int chipChange, required int ratingChange, required bool isWin}) async {
    if (_currentUser == null) return;
    try {
      final newChips = (_currentUser!.chips + chipChange).clamp(0, 999999999);
      final newRating = (_currentUser!.rating + ratingChange).clamp(500, 5000);

      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'chips': newChips,
        'rating': newRating,
        if (isWin) 'wins': FieldValue.increment(1) else 'losses': FieldValue.increment(1),
      });

      _currentUser = _currentUser!.copyWith(
        chips: newChips,
        rating: newRating,
        wins: isWin ? _currentUser!.wins + 1 : _currentUser!.wins,
        losses: !isWin ? _currentUser!.losses + 1 : _currentUser!.losses,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating match result: $e');
    }
  }

  /// استلام الهدية اليومية (هدية واحدة كل 24 ساعة بالضبط)
  Future<Map<String, dynamic>> claimDailyGift() async {
    if (_currentUser == null) {
      return {'success': false, 'message': 'يرجى تسجيل الدخول أولاً!'};
    }

    final now = DateTime.now();
    final lastClaim = _currentUser!.lastDailyGiftClaim;

    if (lastClaim != null) {
      final difference = now.difference(lastClaim);
      if (difference.inHours < 24) {
        final remainingHours = 24 - difference.inHours;
        final remainingMinutes = 60 - (difference.inMinutes % 60);
        return {
          'success': false,
          'message': 'لقد استلمت هديتك اليومية بالفعل! متبقي $remainingHours ساعة و $remainingMinutes دقيقة',
          'remainingHours': remainingHours,
          'remainingMinutes': remainingMinutes,
        };
      }
    }

    // Determine streak day (1 to 7)
    int nextStreak = 1;
    if (lastClaim != null && now.difference(lastClaim).inHours <= 48) {
      nextStreak = (_currentUser!.dailyGiftStreak % 7) + 1;
    }

    final rewardCoins = nextStreak * 150 + 200; // Day 1: 350, Day 7: 1250
    final newChips = _currentUser!.chips + rewardCoins;

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'chips': newChips,
        'lastDailyGiftClaim': Timestamp.fromDate(now),
        'dailyGiftStreak': nextStreak,
      });

      _currentUser = _currentUser!.copyWith(
        chips: newChips,
        lastDailyGiftClaim: now,
        dailyGiftStreak: nextStreak,
      );
      notifyListeners();

      return {
        'success': true,
        'reward': rewardCoins,
        'streakDay': nextStreak,
        'message': 'مبروك! استلمت هدية اليوم $nextStreak: +$rewardCoins عملة ذهبية! 🎉',
      };
    } catch (e) {
      debugPrint('Error claiming daily gift: $e');
      return {'success': false, 'message': 'حدث خطأ أثناء استلام الهدية'};
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    try {
      if (_currentUser != null) {
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      await _auth.signOut();
      await _googleSignIn.signOut();
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in signOut: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }
}
