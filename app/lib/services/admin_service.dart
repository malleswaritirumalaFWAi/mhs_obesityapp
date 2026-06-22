import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../models/admin_content_model.dart';

const _kAdminEmail = 'admin@gmail.com';
const _kAdminPassword = 'Admin@123';
const _kAdminKey = 'admin_is_logged_in';
const _kAdminJwtKey = 'admin_fq_token';
const _kAllUsers = 'ALL_USERS';

/// Handles admin authentication and per-content unlock state via SharedPreferences.
///
/// Unlock key format:  unlock_{contentKey}_{userId}
/// All-users key:      unlock_{contentKey}_ALL_USERS
///
/// A user-facing check should do:
///   isUnlocked(contentKey, userId)  → returns true if ALL_USERS OR individual key is set.
class AdminService {
  AdminService._();

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<bool> login(String email, String password) async {
    if (email.trim().toLowerCase() != _kAdminEmail || password != _kAdminPassword) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminKey, true);

    // Also authenticate with backend to get a JWT for /admin/users calls.
    // Non-blocking: if backend is offline, local login still works (dummy data only).
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBase,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        headers: {'Content-Type': 'application/json'},
      ));
      final res = await dio.post('/auth/admin-login', data: {
        'email': email.trim(),
        'password': password,
      });
      final token = (res.data as Map?)?['token'] as String?;
      if (token != null) {
        await prefs.setString(_kAdminJwtKey, token);
      }
    } catch (_) {
      // Backend offline — continue with local-only mode (dummy users shown)
    }
    return true;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAdminKey) ?? false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAdminKey);
    await prefs.remove(_kAdminJwtKey);
  }

  // ── Real user data ─────────────────────────────────────────────────────────

  /// Fetches all real users from the backend's /admin/users endpoint.
  /// Returns null if the backend is unreachable or JWT is missing.
  static Future<List<AdminUser>?> fetchRealUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAdminJwtKey);
    if (token == null) return null;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBase,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ));
      final res = await dio.get('/admin/users');
      final raw = ((res.data as Map?)?['users'] as List?) ?? [];
      return raw
          .asMap()
          .entries
          .map((e) => AdminUser.fromJson(
              Map<String, dynamic>.from(e.value as Map), e.key + 1))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ── Unlock helpers ─────────────────────────────────────────────────────────

  static String _prefKey(String contentKey, String userId) =>
      'unlock_${contentKey}_$userId';

  /// Returns true if the content is unlocked for [userId] (or for all users).
  static Future<bool> isUnlocked(String contentKey, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey(contentKey, _kAllUsers)) == true) return true;
    return prefs.getBool(_prefKey(contentKey, userId)) ?? false;
  }

  /// Unlock / lock content for a single user.
  static Future<void> setUnlockForUser(
      String contentKey, String userId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(contentKey, userId), value);
  }

  /// Unlock / lock content for ALL users (sets the ALL_USERS key + each individual key).
  static Future<void> setUnlockForAll(
      String contentKey, bool value, List<String> userIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey(contentKey, _kAllUsers), value);
    for (final uid in userIds) {
      await prefs.setBool(_prefKey(contentKey, uid), value);
    }
  }

  /// Load unlock state for [contentKey] for all [userIds] plus the ALL_USERS flag.
  /// Returns a map: userId → bool (true if unlocked).
  static Future<Map<String, bool>> loadStatesForContent(
      String contentKey, List<String> userIds) async {
    final prefs = await SharedPreferences.getInstance();
    final allUnlocked = prefs.getBool(_prefKey(contentKey, _kAllUsers)) ?? false;
    return {
      _kAllUsers: allUnlocked,
      for (final uid in userIds)
        uid: allUnlocked || (prefs.getBool(_prefKey(contentKey, uid)) ?? false),
    };
  }

  /// Load ALL_USERS unlock state for each content key in one call.
  static Future<Map<String, bool>> loadGlobalUnlockStates(
      List<String> contentKeys) async {
    final prefs = await SharedPreferences.getInstance();
    return {
      for (final k in contentKeys)
        k: prefs.getBool(_prefKey(k, _kAllUsers)) ?? false,
    };
  }
}

// ── Riverpod providers for user-facing screens ────────────────────────────────

/// Emits all-users unlock states for weekly challenges.
/// Watch this in WeeklyChallengeScreen to override API-based lock state.
final adminChallengeUnlocksProvider = FutureProvider<Map<String, bool>>((ref) {
  final keys = kChallengeWeeks.map((w) => w.unlockKey).toList();
  return AdminService.loadGlobalUnlockStates(keys);
});

/// Emits all-users unlock states for lesson modules.
/// Watch this in LearningHubScreen to override API-based lock state.
final adminLessonUnlocksProvider = FutureProvider<Map<String, bool>>((ref) {
  final keys = kLessonModules.map((m) => m.unlockKey).toList();
  return AdminService.loadGlobalUnlockStates(keys);
});
