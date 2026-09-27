import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'rewards_service.dart';
import 'store_service.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String username;
  final String photoUrl;
  final int chips;
  final int gems;
  final int rating;
  final int level;
  final int wins;
  final int losses;
  final DateTime? lastDailyGiftClaim;
  final int dailyGiftStreak;
  final DateTime? lastWheelSpin;
  final int wheelSpinCount;
  final DateTime? vipUntil;

  /// 'vip' أو 'vipPlus' — فارغ بلا اشتراك
  final String vipTier;
  final DateTime? lastLootBox;
  final String? referredBy;
  final bool isOnline;
  final List<String> ownedSkins;
  final Map<String, String> equippedSkins;

  /// اشتراك VIP فعّال حالياً؟
  bool get isVip => vipUntil != null && vipUntil!.isAfter(DateTime.now());

  /// مشترك VIP+ (الباقة الأعلى)؟
  bool get isVipPlus => isVip && vipTier == 'vipPlus';

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.username,
    required this.photoUrl,
    this.chips = 1500,
    this.gems = 25,
    this.rating = 1200,
    this.level = 1,
    this.wins = 0,
    this.losses = 0,
    this.lastDailyGiftClaim,
    this.dailyGiftStreak = 0,
    this.lastWheelSpin,
    this.wheelSpinCount = 0,
    this.vipUntil,
    this.vipTier = '',
    this.lastLootBox,
    this.referredBy,
    this.isOnline = true,
    this.ownedSkins = const [],
    this.equippedSkins = const {},
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    DateTime? lastClaim;
    if (data['lastDailyGiftClaim'] is Timestamp) {
      lastClaim = (data['lastDailyGiftClaim'] as Timestamp).toDate();
    }
    DateTime? lastSpin;
    if (data['lastWheelSpin'] is Timestamp) {
      lastSpin = (data['lastWheelSpin'] as Timestamp).toDate();
    }
    DateTime? vipUntil;
    if (data['vipUntil'] is Timestamp) {
      vipUntil = (data['vipUntil'] as Timestamp).toDate();
    }
    DateTime? lastLootBox;
    if (data['lastLootBox'] is Timestamp) {
      lastLootBox = (data['lastLootBox'] as Timestamp).toDate();
    }

    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'لاعب',
      username: data['username'] ?? 'user_${uid.substring(0, 6)}',
      photoUrl: data['photoUrl'] ?? '',
      chips: (data['chips'] as num?)?.toInt() ?? 1500,
      gems: (data['gems'] as num?)?.toInt() ?? 25,
      rating: (data['rating'] as num?)?.toInt() ?? 1200,
      level: (data['level'] as num?)?.toInt() ?? 1,
      wins: (data['wins'] as num?)?.toInt() ?? 0,
      losses: (data['losses'] as num?)?.toInt() ?? 0,
      lastDailyGiftClaim: lastClaim,
      dailyGiftStreak: (data['dailyGiftStreak'] as num?)?.toInt() ?? 0,
      lastWheelSpin: lastSpin,
      wheelSpinCount: (data['wheelSpinCount'] as num?)?.toInt() ?? 0,
      vipUntil: vipUntil,
      vipTier: data['vipTier'] ?? '',
      lastLootBox: lastLootBox,
      referredBy: data['referredBy'],
      isOnline: data['isOnline'] ?? true,
      ownedSkins:
          (data['ownedSkins'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      equippedSkins:
          (data['equippedSkins'] as Map?)?.map(
                (k, v) => MapEntry(k.toString(), v.toString()),
              ) ??
              const {},
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
      'gems': gems,
      'rating': rating,
      'level': level,
      'wins': wins,
      'losses': losses,
      'lastDailyGiftClaim': lastDailyGiftClaim != null
          ? Timestamp.fromDate(lastDailyGiftClaim!)
          : null,
      'dailyGiftStreak': dailyGiftStreak,
      'lastWheelSpin':
          lastWheelSpin != null ? Timestamp.fromDate(lastWheelSpin!) : null,
      'wheelSpinCount': wheelSpinCount,
      'vipUntil': vipUntil != null ? Timestamp.fromDate(vipUntil!) : null,
      'vipTier': vipTier,
      'lastLootBox':
          lastLootBox != null ? Timestamp.fromDate(lastLootBox!) : null,
      'referredBy': referredBy,
      'isOnline': isOnline,
      'ownedSkins': ownedSkins,
      'equippedSkins': equippedSkins,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? displayName,
    String? username,
    String? photoUrl,
    int? chips,
    int? gems,
    int? rating,
    int? level,
    int? wins,
    int? losses,
    DateTime? lastDailyGiftClaim,
    int? dailyGiftStreak,
    DateTime? lastWheelSpin,
    int? wheelSpinCount,
    DateTime? vipUntil,
    String? vipTier,
    DateTime? lastLootBox,
    String? referredBy,
    bool clearVip = false,
    bool? isOnline,
    List<String>? ownedSkins,
    Map<String, String>? equippedSkins,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      chips: chips ?? this.chips,
      gems: gems ?? this.gems,
      rating: rating ?? this.rating,
      level: level ?? this.level,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      lastDailyGiftClaim: lastDailyGiftClaim ?? this.lastDailyGiftClaim,
      dailyGiftStreak: dailyGiftStreak ?? this.dailyGiftStreak,
      lastWheelSpin: lastWheelSpin ?? this.lastWheelSpin,
      wheelSpinCount: wheelSpinCount ?? this.wheelSpinCount,
      vipUntil: clearVip ? null : (vipUntil ?? this.vipUntil),
      vipTier: clearVip ? '' : (vipTier ?? this.vipTier),
      lastLootBox: lastLootBox ?? this.lastLootBox,
      referredBy: referredBy ?? this.referredBy,
      isOnline: isOnline ?? this.isOnline,
      ownedSkins: ownedSkins ?? this.ownedSkins,
      equippedSkins: equippedSkins ?? this.equippedSkins,
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
  bool get isAuthenticated => _currentUser != null && !_pendingUsernameSetup;

  /// يمنع الانتقال للواجهة الرئيسية قبل اختيار اسم المستخدم
  bool _pendingUsernameSetup = false;
  bool get needsUsernameSetup => _pendingUsernameSetup;

  void beginUsernameSetup() {
    _pendingUsernameSetup = true;
  }

  void completeUsernameSetup() {
    if (!_pendingUsernameSetup) return;
    _pendingUsernameSetup = false;
    notifyListeners();
  }

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  void initialize() {
    _authSub = _auth.authStateChanges().listen((user) async {
      if (user != null) {
        await _fetchOrCreateUser(user);
      } else {
        // جلسة الضيف المحلية لا ترتبط بحساب Firebase، فلا يجوز مسحها هنا
        if (_currentUser?.uid.startsWith('guest_') ?? false) return;
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
        await docRef.update(
            {'isOnline': true, 'lastSeen': FieldValue.serverTimestamp()});
      } else {
        // Generate a clean default unique username based on name or uid
        String cleanName =
            user.displayName?.replaceAll(RegExp(r'\s+'), '_').toLowerCase() ??
                'player';
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

      // مزايا تلقائية عند الدخول: إطار VIP الذهبي + مطالبات الهدايا/الإحالة
      unawaited(_applyVipPerks());
      unawaited(_processPendingClaims());
    } catch (e) {
      debugPrint('Error fetching/creating user: $e');
    }
  }

  /// يجهّز إطار VIP الذهبي تلقائياً للمشترك إن لم يكن لديه إطار مجهز
  Future<void> _applyVipPerks() async {
    final user = _currentUser;
    if (user == null || !user.isVip || user.uid.startsWith('guest_')) {
      return;
    }
    const vipFrameId = 'builtin_frame_vip_gold';
    final equipped = Map<String, String>.from(user.equippedSkins);
    if (equipped.containsKey(StoreCategory.frame)) return;

    equipped[StoreCategory.frame] = vipFrameId;
    final owned = List<String>.from(user.ownedSkins);
    if (!owned.contains(vipFrameId)) owned.add(vipFrameId);

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'equippedSkins': equipped,
        'ownedSkins': owned,
      });
      _currentUser = user.copyWith(
          equippedSkins: equipped, ownedSkins: owned);
      notifyListeners();
    } catch (e) {
      debugPrint('Error applying VIP perks: $e');
    }
  }

  /// معالجة مطالبات الهدايا والإحالة الواردة — تُرصَّد عند فتح التطبيق
  Future<void> _processPendingClaims() async {
    final user = _currentUser;
    if (user == null || user.uid.startsWith('guest_')) return;
    try {
      final snap = await _firestore
          .collection('claims')
          .where('toUid', isEqualTo: user.uid)
          .where('claimed', isEqualTo: false)
          .limit(50)
          .get();
      if (snap.docs.isEmpty) return;

      int chips = 0;
      int gems = 0;
      final skins = <String>[];
      final batch = _firestore.batch();

      for (final d in snap.docs) {
        final data = d.data();
        chips += (data['chips'] as num?)?.toInt() ?? 0;
        gems += (data['gems'] as num?)?.toInt() ?? 0;
        final skin = data['skinId'] as String?;
        if (skin != null &&
            skin.isNotEmpty &&
            !user.ownedSkins.contains(skin)) {
          skins.add(skin);
        }
        batch.update(d.reference, {'claimed': true});
      }

      final owned = [...user.ownedSkins, ...skins];
      await _firestore.collection('users').doc(user.uid).update({
        'chips': user.chips + chips,
        'gems': user.gems + gems,
        'ownedSkins': owned,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();

      _currentUser = user.copyWith(
        chips: user.chips + chips,
        gems: user.gems + gems,
        ownedSkins: owned,
      );
      notifyListeners();
      if (chips + gems > 0 || skins.isNotEmpty) {
        debugPrint(
            'Claims processed: +$chips chips, +$gems gems, ${skins.length} skins');
      }
    } catch (e) {
      debugPrint('Error processing claims: $e');
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

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
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
      debugPrint(
          'Firebase signInAnonymously info (falling back to guest session): $e');
    }

    // Fallback: إنشاء جلسة ضيف محلية فورية تضمن عمل التطبيق بنسبة 100% دون توقف
    final randomSuffix = (DateTime.now().millisecondsSinceEpoch % 10000)
        .toString()
        .padLeft(4, '0');
    final guestUid = 'guest_$randomSuffix';
    _pendingUsernameSetup = true;
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
    if (_currentUser == null) return false;
    if (_currentUser!.uid.startsWith('guest_') ||
        _currentUser!.username.toLowerCase() == cleanUsername) {
      return true;
    }

    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      return query.docs.isEmpty;
    } catch (e) {
      debugPrint('Error checking username availability: $e');
      return false;
    }
  }

  /// تحديث اسم المستخدم الفريد
  Future<bool> updateUsername(String newUsername) async {
    if (_currentUser == null) return false;
    final cleanUsername = newUsername.trim().toLowerCase();
    final available = await isUsernameAvailable(cleanUsername);
    if (!available) return false;

    if (_currentUser!.uid.startsWith('guest_')) {
      _currentUser = _currentUser!.copyWith(username: cleanUsername);
      notifyListeners();
      return true;
    }

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
    if (_currentUser!.uid.startsWith('guest_')) {
      _currentUser = _currentUser!.copyWith(
        displayName: displayName,
        photoUrl: photoUrl,
      );
      notifyListeners();
      return;
    }
    try {
      final Map<String, dynamic> updates = {};
      if (displayName != null) updates['displayName'] = displayName;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updates);
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
  Future<bool> updateMatchResult({
    required int chipChange,
    required int ratingChange,
    required bool isWin,
    bool recordResult = true,
  }) async {
    final user = _currentUser;
    if (user == null) return false;

    if (user.uid.startsWith('guest_')) {
      _currentUser = user.copyWith(
        chips: (user.chips + chipChange).clamp(0, 999999999),
        rating: (user.rating + ratingChange).clamp(500, 5000),
        wins: recordResult && isWin ? user.wins + 1 : user.wins,
        losses: recordResult && !isWin ? user.losses + 1 : user.losses,
      );
      notifyListeners();
      return true;
    }

    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      late AppUser updatedUser;
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final latest = snapshot.exists && snapshot.data() != null
            ? AppUser.fromMap(user.uid, snapshot.data()!)
            : user;
        updatedUser = latest.copyWith(
          chips: (latest.chips + chipChange).clamp(0, 999999999),
          rating: (latest.rating + ratingChange).clamp(500, 5000),
          wins: recordResult && isWin ? latest.wins + 1 : latest.wins,
          losses: recordResult && !isWin ? latest.losses + 1 : latest.losses,
        );
        transaction.set(
            docRef,
            {
              'chips': updatedUser.chips,
              'rating': updatedUser.rating,
              'wins': updatedUser.wins,
              'losses': updatedUser.losses,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });
      _currentUser = updatedUser;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating match result: $e');
      return false;
    }
  }

  /// تعديل رصيد العملات (شحن أو خصم عند الشراء من المتجر)
  Future<bool> adjustChips(int change) async {
    final user = _currentUser;
    if (user == null) return false;
    final newChips = (user.chips + change).clamp(0, 999999999);

    if (user.uid.startsWith('guest_')) {
      _currentUser = user.copyWith(chips: newChips);
      notifyListeners();
      return true;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'chips': newChips,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _currentUser = user.copyWith(chips: newChips);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adjusting chips: $e');
      return false;
    }
  }

  /// تعديل رصيد المجوهرات الزرقاء 💎
  Future<bool> adjustGems(int change) async {
    final user = _currentUser;
    if (user == null) return false;
    final newGems = (user.gems + change).clamp(0, 999999999);

    if (user.uid.startsWith('guest_')) {
      _currentUser = user.copyWith(gems: newGems);
      notifyListeners();
      return true;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'gems': newGems,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _currentUser = user.copyWith(gems: newGems);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adjusting gems: $e');
      return false;
    }
  }

  /// تحديث بيانات الكسنات المملوكة والمجهزة للمستخدم
  Future<bool> updateSkinData({
    List<String>? ownedSkins,
    Map<String, String>? equippedSkins,
  }) async {
    final user = _currentUser;
    if (user == null) return false;

    final newOwned = ownedSkins ?? user.ownedSkins;
    final newEquipped = equippedSkins ?? user.equippedSkins;

    if (user.uid.startsWith('guest_')) {
      _currentUser = user.copyWith(
        ownedSkins: newOwned,
        equippedSkins: newEquipped,
      );
      notifyListeners();
      return true;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'ownedSkins': newOwned,
        'equippedSkins': newEquipped,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _currentUser = user.copyWith(
        ownedSkins: newOwned,
        equippedSkins: newEquipped,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating skin data: $e');
      return false;
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
          'message':
              'لقد استلمت هديتك اليومية بالفعل! متبقي $remainingHours ساعة و $remainingMinutes دقيقة',
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

    // جائزة اليوم من خطة الأسبوع الدوّارة (عملات/جواهر/سكن — تتبدل أسبوعياً)
    final def = RewardsService.currentWeekRewards[nextStreak - 1];
    final isVip = _currentUser!.isVip;
    final isVipPlus = _currentUser!.isVipPlus;

    int chipsDelta = 0;
    int gemsDelta = 0;
    String? grantedSkinId;
    String? skinName;
    String rewardLabel;

    int boost(int amount) => isVipPlus
        ? RewardsService.vipPlusBoost(amount)
        : (isVip ? RewardsService.vipBoost(amount) : amount);

    switch (def.type) {
      case RewardType.chips:
        chipsDelta = boost(def.amount);
        rewardLabel = '+$chipsDelta 🪙 عملة ذهبية';
      case RewardType.gems:
        gemsDelta = boost(def.amount);
        rewardLabel = '+$gemsDelta 💎 جوهرة (شذر)';
      case RewardType.skin:
        if (_currentUser!.ownedSkins.contains(def.skinId)) {
          // يمتلك السكن مسبقاً → تعويض بالجواهر
          gemsDelta = RewardsService.skinFallbackGems;
          rewardLabel = '+$gemsDelta 💎 (السكن مملوك مسبقاً)';
        } else {
          grantedSkinId = def.skinId;
          skinName = StoreService().itemName(def.skinId) ?? 'سكن حصري';
          rewardLabel = '🎨 سكن: $skinName';
        }
    }

    final newChips = _currentUser!.chips + chipsDelta;
    final newGems = _currentUser!.gems + gemsDelta;
    final newOwned = grantedSkinId != null
        ? [..._currentUser!.ownedSkins, grantedSkinId]
        : _currentUser!.ownedSkins;
    final vipNote = isVipPlus && def.type != RewardType.skin
        ? ' (+50% VIP+ 👑)'
        : (isVip && def.type != RewardType.skin ? ' (+25% VIP 👑)' : '');

    final result = {
      'success': true,
      'reward': chipsDelta,
      'type': def.type.name,
      'amount': chipsDelta + gemsDelta,
      'skinId': grantedSkinId,
      'skinName': skinName,
      'streakDay': nextStreak,
      'message':
          'مبروك! استلمت هدية اليوم $nextStreak: $rewardLabel$vipNote 🎉',
    };

    if (_currentUser!.uid.startsWith('guest_')) {
      _currentUser = _currentUser!.copyWith(
        chips: newChips,
        gems: newGems,
        ownedSkins: newOwned,
        lastDailyGiftClaim: now,
        dailyGiftStreak: nextStreak,
      );
      notifyListeners();
      return result;
    }

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        'chips': newChips,
        'gems': newGems,
        'ownedSkins': newOwned,
        'lastDailyGiftClaim': Timestamp.fromDate(now),
        'dailyGiftStreak': nextStreak,
      });

      _currentUser = _currentUser!.copyWith(
        chips: newChips,
        gems: newGems,
        ownedSkins: newOwned,
        lastDailyGiftClaim: now,
        dailyGiftStreak: nextStreak,
      );
      notifyListeners();

      return result;
    } catch (e) {
      debugPrint('Error claiming daily gift: $e');
      return {'success': false, 'message': 'حدث خطأ أثناء استلام الهدية'};
    }
  }

  // ══════════════════════════════════════════════════════
  // عجلة الحظ اليومية 🎡 — لفة مجانية يومياً (لفتان لـVIP)
  // ══════════════════════════════════════════════════════

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// عدد اللفات المتبقية اليوم (1 للعادي، 2 لـVIP، 3 لـVIP+)
  int get wheelSpinsRemaining {
    final user = _currentUser;
    if (user == null) return 0;
    final limit = user.isVipPlus ? 3 : (user.isVip ? 2 : 1);
    final last = user.lastWheelSpin;
    if (last == null || !_sameDay(last, DateTime.now())) return limit;
    return (limit - user.wheelSpinCount).clamp(0, limit);
  }

  /// تدوير العجلة — يعيد فهرس المقطع الفائز لتوجيه الأنيميشن عليه
  Future<Map<String, dynamic>> spinDailyWheel() async {
    final user = _currentUser;
    if (user == null) {
      return {'success': false, 'message': 'يرجى تسجيل الدخول أولاً!'};
    }
    if (wheelSpinsRemaining <= 0) {
      return {
        'success': false,
        'message': 'استخدمت لفات اليوم! عُد غداً أو اشترك بـVIP للفة إضافية 👑',
      };
    }

    final now = DateTime.now();
    final sameDay =
        user.lastWheelSpin != null && _sameDay(user.lastWheelSpin!, now);
    final newCount = sameDay ? user.wheelSpinCount + 1 : 1;

    // اختيار المقطع موزوناً — الحظ مركّز على الأموال
    final segIndex = RewardsService.pickWheelIndex(math.Random());
    final seg = RewardsService.wheel[segIndex];

    int chipsDelta = 0;
    int gemsDelta = 0;
    String? grantedSkinId;
    String? skinName;
    String rewardLabel;

    switch (seg.type) {
      case RewardType.chips:
        chipsDelta = seg.amount;
        rewardLabel = '+${seg.amount} 🪙 عملة ذهبية';
      case RewardType.gems:
        gemsDelta = seg.amount;
        rewardLabel = '+${seg.amount} 💎 جوهرة (شذر)';
      case RewardType.skin:
        final skinId = RewardsService.wheelSkinThisWeek;
        if (user.ownedSkins.contains(skinId)) {
          gemsDelta = RewardsService.skinFallbackGems;
          rewardLabel = '+$gemsDelta 💎 (السكن مملوك مسبقاً)';
        } else {
          grantedSkinId = skinId;
          skinName = StoreService().itemName(skinId) ?? 'سكن حصري';
          rewardLabel = '🎨 سكن مجاني: $skinName';
        }
    }

    final newChips = user.chips + chipsDelta;
    final newGems = user.gems + gemsDelta;
    final newOwned = grantedSkinId != null
        ? [...user.ownedSkins, grantedSkinId]
        : user.ownedSkins;
    final limit = user.isVipPlus ? 3 : (user.isVip ? 2 : 1);

    final result = {
      'success': true,
      'segmentIndex': segIndex,
      'type': seg.type.name,
      'amount': chipsDelta + gemsDelta,
      'skinName': skinName,
      'rewardLabel': rewardLabel,
      'spinsLeft': limit - newCount,
      'message': 'العجلة اختارت لك: $rewardLabel 🎉',
    };

    if (user.uid.startsWith('guest_')) {
      _currentUser = user.copyWith(
        chips: newChips,
        gems: newGems,
        ownedSkins: newOwned,
        lastWheelSpin: now,
        wheelSpinCount: newCount,
      );
      notifyListeners();
      return result;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'chips': newChips,
        'gems': newGems,
        'ownedSkins': newOwned,
        'lastWheelSpin': Timestamp.fromDate(now),
        'wheelSpinCount': newCount,
      });
      _currentUser = user.copyWith(
        chips: newChips,
        gems: newGems,
        ownedSkins: newOwned,
        lastWheelSpin: now,
        wheelSpinCount: newCount,
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error spinning wheel: $e');
      return {'success': false, 'message': 'حدث خطأ أثناء تدوير العجلة'};
    }
  }

  // ══════════════════════════════════════════════════════
  // اشتراك VIP — 10$ شهرياً / VIP+ بـ20$ (تفعيل من الإدارة)
  // ══════════════════════════════════════════════════════
  Future<Map<String, dynamic>> submitVipRequest(
      {String plan = 'vip'}) async {
    final user = _currentUser;
    if (user == null) {
      return {'success': false, 'message': 'يرجى تسجيل الدخول أولاً!'};
    }
    if (user.uid.startsWith('guest_')) {
      return {
        'success': false,
        'message': 'اشتراك VIP يتطلب حساباً مسجلاً عبر Google',
      };
    }
    final isPlus = plan == 'vipPlus';
    if (user.isVipPlus || (user.isVip && !isPlus)) {
      return {'success': false, 'message': 'أنت مشترك بالفعل! 👑'};
    }
    final price = isPlus ? 20 : 10;

    try {
      await _firestore.collection('vip_requests').add({
        'uid': user.uid,
        'username': user.username,
        'displayName': user.displayName,
        'plan': isPlus ? 'vipPlus' : 'vip',
        'priceUsd': price,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return {
        'success': true,
        'message':
            'تم إرسال طلب ${isPlus ? 'VIP+' : 'VIP'} ✅ سيُفعَّل خلال 24 ساعة بعد تأكيد الدفع',
      };
    } catch (e) {
      debugPrint('Error submitting VIP request: $e');
      return {'success': false, 'message': 'تعذر إرسال الطلب، حاول لاحقاً'};
    }
  }

  // ══════════════════════════════════════════════════════
  // صندوق الغنائم اليومي 📦 — مرة كل 24 ساعة
  // ══════════════════════════════════════════════════════

  /// هل يمكن فتح صندوق اليوم؟
  bool get canClaimLootBox {
    final user = _currentUser;
    if (user == null) return false;
    final last = user.lastLootBox;
    return last == null || DateTime.now().difference(last).inHours >= 24;
  }

  /// فتح صندوق الغنائم اليومي — الحظ مركّز على الأموال
  Future<Map<String, dynamic>> claimLootBox() async {
    final user = _currentUser;
    if (user == null) {
      return {'success': false, 'message': 'يرجى تسجيل الدخول أولاً!'};
    }
    if (!canClaimLootBox) {
      final diff = DateTime.now().difference(user.lastLootBox!);
      final h = 23 - diff.inHours;
      return {'success': false, 'message': 'الصندوق يتجدد بعد ${h}س ⏳'};
    }

    final now = DateTime.now();
    final segIndex = RewardsService.pickLootBoxIndex(math.Random());
    final seg = RewardsService.lootBox[segIndex];

    int chipsDelta = 0, gemsDelta = 0;
    String? grantedSkinId, skinName;
    String rewardLabel;

    switch (seg.type) {
      case RewardType.chips:
        chipsDelta = seg.amount;
        rewardLabel = '+${seg.amount} 🪙 عملة ذهبية';
      case RewardType.gems:
        gemsDelta = seg.amount;
        rewardLabel = '+${seg.amount} 💎 جوهرة (شذر)';
      case RewardType.skin:
        final skinId = RewardsService.lootBoxSkinThisWeek;
        if (user.ownedSkins.contains(skinId)) {
          gemsDelta = RewardsService.skinFallbackGems;
          rewardLabel = '+$gemsDelta 💎 (السكن مملوك مسبقاً)';
        } else {
          grantedSkinId = skinId;
          skinName = StoreService().itemName(skinId) ?? 'سكن حصري';
          rewardLabel = '🎨 سكن مجاني: $skinName';
        }
    }

    final newOwned = grantedSkinId != null
        ? [...user.ownedSkins, grantedSkinId]
        : user.ownedSkins;
    final result = {
      'success': true,
      'type': seg.type.name,
      'amount': chipsDelta + gemsDelta,
      'skinName': skinName,
      'rewardLabel': rewardLabel,
      'message': 'الصندوق أعطاك: $rewardLabel 🎉',
    };

    if (user.uid.startsWith('guest_')) {
      _currentUser = user.copyWith(
        chips: user.chips + chipsDelta,
        gems: user.gems + gemsDelta,
        ownedSkins: newOwned,
        lastLootBox: now,
      );
      notifyListeners();
      return result;
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'chips': user.chips + chipsDelta,
        'gems': user.gems + gemsDelta,
        'ownedSkins': newOwned,
        'lastLootBox': Timestamp.fromDate(now),
      });
      _currentUser = user.copyWith(
        chips: user.chips + chipsDelta,
        gems: user.gems + gemsDelta,
        ownedSkins: newOwned,
        lastLootBox: now,
      );
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('Error claiming loot box: $e');
      return {'success': false, 'message': 'حدث خطأ أثناء فتح الصندوق'};
    }
  }

  // ══════════════════════════════════════════════════════
  // حماية السلسلة 🔥 — 10💎 لاسترجاع Streak منقطع (حتى 4 أيام)
  // ══════════════════════════════════════════════════════

  /// هل السلسلة قابلة للاسترجاع الآن؟ (انقطعت خلال 48س-4أيام وكان streak>0)
  bool get canRestoreStreak {
    final user = _currentUser;
    if (user == null || user.lastDailyGiftClaim == null) return false;
    if (user.dailyGiftStreak <= 0) return false;
    final diff = DateTime.now().difference(user.lastDailyGiftClaim!);
    return diff.inHours >= 48 && diff.inDays < 4;
  }

  /// شراء حماية/استرجاع السلسلة بـ10 جواهر
  Future<Map<String, dynamic>> buyStreakProtection() async {
    final user = _currentUser;
    if (user == null) {
      return {'success': false, 'message': 'يرجى تسجيل الدخول أولاً!'};
    }
    const cost = 10;
    if (user.gems < cost) {
      return {
        'success': false,
        'message': 'تحتاج $cost 💎 لحماية السلسلة — رصيدك ${user.gems} 💎',
      };
    }
    if (!canRestoreStreak) {
      return {
        'success': false,
        'message': 'السلسلة لم تنقطع أو مضى عليها أكثر من 4 أيام',
      };
    }

    // نُرجع آخر استلام ليصبح الاستلام القادم استكمالاً للسلسلة
    final restored = DateTime.now().subtract(const Duration(hours: 25));

    if (user.uid.startsWith('guest_')) {
      _currentUser = user.copyWith(
        gems: user.gems - cost,
        lastDailyGiftClaim: restored,
      );
      notifyListeners();
      return {'success': true, 'message': 'تم حماية سلسلتك! 🔥 استلم هديتك الآن'};
    }

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'gems': user.gems - cost,
        'lastDailyGiftClaim': Timestamp.fromDate(restored),
      });
      _currentUser = user.copyWith(
        gems: user.gems - cost,
        lastDailyGiftClaim: restored,
      );
      notifyListeners();
      return {'success': true, 'message': 'تم حماية سلسلتك! 🔥 استلم هديتك الآن'};
    } catch (e) {
      debugPrint('Error buying streak protection: $e');
      return {'success': false, 'message': 'تعذر تنفيذ الحماية'};
    }
  }

  // ══════════════════════════════════════════════════════
  // نظام الإحالة 🤝 — شارك كودك: صديقك +300🪙 وأنت +500🪙
  // ══════════════════════════════════════════════════════

  /// كود الإحالة الخاص بالمستخدم = اسم المستخدم
  String? get referralCode => _currentUser?.username;

  /// استبدال كود إحالة صديق (مرة واحدة لكل حساب)
  Future<Map<String, dynamic>> redeemReferral(String code) async {
    final user = _currentUser;
    if (user == null) {
      return {'success': false, 'message': 'يرجى تسجيل الدخول أولاً!'};
    }
    if (user.uid.startsWith('guest_')) {
      return {
        'success': false,
        'message': 'الإحالة تتطلب حساباً مسجلاً عبر Google',
      };
    }
    if (user.referredBy != null) {
      return {'success': false, 'message': 'استخدمت كود إحالة مسبقاً!'};
    }
    final clean = code.trim().toLowerCase();
    if (clean.isEmpty || clean == user.username.toLowerCase()) {
      return {'success': false, 'message': 'كود غير صالح!'};
    }

    try {
      final snap = await _firestore
          .collection('users')
          .where('username', isEqualTo: clean)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        return {'success': false, 'message': 'لا يوجد لاعب بهذا الكود!'};
      }
      final referrer = snap.docs.first;

      // مكافأة المُحال فوراً +300🪙
      await _firestore.collection('users').doc(user.uid).update({
        'chips': user.chips + 300,
        'referredBy': clean,
      });
      // مكافأة المُحيل +500🪙 عبر مطالبة تُرصَّد عند دخوله
      await _firestore.collection('claims').add({
        'toUid': referrer.id,
        'fromUid': user.uid,
        'fromName': user.displayName,
        'type': 'referral',
        'chips': 500,
        'claimed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _currentUser = user.copyWith(
          chips: user.chips + 300, referredBy: clean);
      notifyListeners();
      return {
        'success': true,
        'message': 'تم تفعيل الكود! +300 🪙 لك و +500 🪙 لصديقك 🎉',
      };
    } catch (e) {
      debugPrint('Error redeeming referral: $e');
      return {'success': false, 'message': 'تعذر تفعيل الكود'};
    }
  }

  // ══════════════════════════════════════════════════════
  // إهداء العملات لصديق 🎁 — يستلمها عند فتحه التطبيق
  // ══════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendGift(
      String username, int chips) async {
    final user = _currentUser;
    if (user == null) {
      return {'success': false, 'message': 'يرجى تسجيل الدخول أولاً!'};
    }
    if (user.uid.startsWith('guest_')) {
      return {
        'success': false,
        'message': 'الإهداء يتطلب حساباً مسجلاً عبر Google',
      };
    }
    final clean = username.trim().toLowerCase();
    if (clean.isEmpty || clean == user.username.toLowerCase()) {
      return {'success': false, 'message': 'اسم مستخدم غير صالح!'};
    }
    if (chips < 50) {
      return {'success': false, 'message': 'أقل هدية 50 🪙'};
    }
    if (chips > 10000) {
      return {'success': false, 'message': 'أكبر هدية 10000 🪙'};
    }
    if (user.chips < chips) {
      return {'success': false, 'message': 'رصيدك غير كافٍ!'};
    }

    try {
      final snap = await _firestore
          .collection('users')
          .where('username', isEqualTo: clean)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        return {'success': false, 'message': 'لا يوجد لاعب بهذا الاسم!'};
      }

      // خصم من المرسل فوراً + إنشاء مطالبة للمستلم
      await _firestore.collection('users').doc(user.uid).update({
        'chips': user.chips - chips,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('claims').add({
        'toUid': snap.docs.first.id,
        'fromUid': user.uid,
        'fromName': user.displayName,
        'type': 'gift',
        'chips': chips,
        'claimed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _currentUser = user.copyWith(chips: user.chips - chips);
      notifyListeners();
      return {
        'success': true,
        'message': 'أُرسلت $chips 🪙 هدية إلى @$clean 🎁 تصله عند دخوله',
      };
    } catch (e) {
      debugPrint('Error sending gift: $e');
      return {'success': false, 'message': 'تعذر إرسال الهدية'};
    }
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    try {
      if (_currentUser != null && !_currentUser!.uid.startsWith('guest_')) {
        await _firestore.collection('users').doc(_currentUser!.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      await _auth.signOut();
      await _googleSignIn.signOut();
      _pendingUsernameSetup = false;
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
