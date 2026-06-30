import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../config.dart';

/// Increments every time a different user logs in or any user logs out.
/// All user-specific providers watch this so they re-fetch automatically.
final currentUserKeyProvider = StateProvider<int>((ref) => 0);

enum AuthStatus { unknown, signedOut, otpSent, signedIn }

class SessionState {
  const SessionState({
    this.status = AuthStatus.unknown,
    this.name,
    this.phone,
    this.email,
    this.error,
    this.busy = false,
    this.onboarded = false,
  });

  final AuthStatus status;
  final String? name;
  final String? phone;
  final String? email;
  final String? error;
  final bool busy;
  final bool onboarded; // completed quiz + payment

  SessionState copyWith({
    AuthStatus? status,
    String? name,
    String? phone,
    String? email,
    String? error,
    bool? busy,
    bool? onboarded,
  }) =>
      SessionState(
        status: status ?? this.status,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        error: error,
        busy: busy ?? this.busy,
        onboarded: onboarded ?? this.onboarded,
      );
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._api, this._ref) : super(const SessionState()) {
    _api.onUnauthorized = _handleUnauthorized;
    _bootstrap();
  }

  void _handleUnauthorized() {
    // Any API call got 401 — token is invalid, force re-login.
    if (state.status != AuthStatus.signedOut) {
      _bumpUserKey();
      state = const SessionState(status: AuthStatus.signedOut);
    }
  }

  void _bumpUserKey() {
    _ref.read(currentUserKeyProvider.notifier).update((n) => n + 1);
  }

  final ApiClient _api;
  final Ref _ref;

  Future<void> _bootstrap() async {
    final token = await _api.readToken();
    if (token == null) {
      state = state.copyWith(status: AuthStatus.signedOut, onboarded: false);
      return;
    }
    // Clear stale demo tokens — they are not real JWTs and must not bypass auth.
    if (token == 'demo-token') {
      await _api.clearToken();
      state = state.copyWith(status: AuthStatus.signedOut, onboarded: false);
      return;
    }
    // Real token — verify it with the backend.
    try {
      final profile = await _api.getJson('/profile');
      final user = profile['user'] as Map?;
      final onboarded = user?['onboarded'] == true;
      state = state.copyWith(
        status: AuthStatus.signedIn,
        onboarded: onboarded,
        name: user?['name'] as String?,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        // HTTP error (401/403) — token invalid or expired, force re-login.
        await _api.clearToken();
        state = state.copyWith(status: AuthStatus.signedOut, onboarded: false);
      } else {
        // Pure network/connection error — backend unreachable, stay signed in.
        state = state.copyWith(status: AuthStatus.signedIn, onboarded: true);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.signedIn, onboarded: true);
    }
  }

  /// Step 1 — request an OTP for [phone] (10-digit Indian number).
  Future<void> requestOtp(String phone) async {
    state = state.copyWith(busy: true, error: null, phone: phone);
    try {
      await _api.postJson('/auth/otp/request', {'phone': '+91$phone'});
      state = state.copyWith(status: AuthStatus.otpSent, busy: false);
    } on DioException catch (e) {
      if (AppConfig.demoMode) {
        // Backend unavailable — proceed with dev fixed OTP (123456).
        state = state.copyWith(status: AuthStatus.otpSent, busy: false);
      } else {
        state = state.copyWith(busy: false, error: _msg(e));
      }
    }
  }

  /// Step 2 — verify the 6-digit [code]. Returns true on success.
  Future<bool> verifyOtp(String code) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final res = await _api.postJson('/auth/otp/verify', {
        'phone': '+91${state.phone}',
        'code': code,
      });
      final token = res['token'] as String?;
      if (token != null) await _api.saveToken(token);
      final onboarded = res['onboarded'] == true;
      _bumpUserKey();
      state = state.copyWith(status: AuthStatus.signedIn, busy: false, onboarded: onboarded);
      return true;
    } on DioException catch (e) {
      if (AppConfig.demoMode && code == '123456') {
        await _api.saveToken('demo-token');
        _bumpUserKey();
        state = state.copyWith(status: AuthStatus.signedIn, busy: false, onboarded: false);
        return true;
      }
      state = state.copyWith(busy: false, error: _msg(e));
      return false;
    }
  }

  /// Sign up with name, phone, email and password. Returns true on success.
  Future<bool> signUp(String name, String phone, String email, String password) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final res = await _api.postJson('/auth/signup', {
        'name': name,
        'phone': phone.startsWith('+') ? phone : '+91$phone',
        'email': email,
        'password': password,
      });
      final token = res['token'] as String?;
      if (token != null) await _api.saveToken(token);
      _bumpUserKey();
      state = state.copyWith(
        status: AuthStatus.signedIn,
        busy: false,
        name: name,
        email: email,
        phone: phone,
        onboarded: res['onboarded'] == true,
      );
      return true;
    } on DioException catch (e) {
      if (AppConfig.demoMode) {
        // Backend unreachable — continue demo flow without persisting a token.
        _bumpUserKey();
        state = state.copyWith(
          status: AuthStatus.signedIn,
          busy: false,
          name: name,
          email: email,
          phone: phone,
          onboarded: false, // new user → goes to quiz
        );
        return true;
      }
      state = state.copyWith(busy: false, error: _msg(e));
      return false;
    }
  }

  /// Sign in with email and password. Returns true on success.
  Future<bool> signIn(String email, String password) async {
    state = state.copyWith(busy: true, error: null);
    try {
      final res = await _api.postJson('/auth/signin', {
        'email': email,
        'password': password,
      });
      final token = res['token'] as String?;
      if (token != null) await _api.saveToken(token);
      _bumpUserKey();
      state = state.copyWith(
        status: AuthStatus.signedIn,
        busy: false,
        email: email,
        name: res['name'] as String?,
        onboarded: res['onboarded'] == true,
      );
      return true;
    } on DioException catch (e) {
      if (AppConfig.demoMode) {
        // Backend unreachable — continue demo flow without persisting a token.
        _bumpUserKey();
        state = state.copyWith(
          status: AuthStatus.signedIn,
          busy: false,
          email: email,
          onboarded: true, // returning user → skip quiz, go to home
        );
        return true;
      }
      state = state.copyWith(busy: false, error: _msg(e));
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);

  void completeOnboarding() => state = state.copyWith(onboarded: true);

  /// Return from the OTP step back to phone entry.
  void resetToPhone() =>
      state = state.copyWith(status: AuthStatus.signedOut, error: null);

  Future<void> signOut() async {
    await _api.clearToken();
    _bumpUserKey();
    state = const SessionState(status: AuthStatus.signedOut);
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    return 'Something went wrong. Please try again.';
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, SessionState>((ref) {
  return SessionController(ref.watch(apiClientProvider), ref);
});
