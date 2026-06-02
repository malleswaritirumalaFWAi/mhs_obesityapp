import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../config.dart';

enum AuthStatus { unknown, signedOut, otpSent, signedIn }

class SessionState {
  const SessionState({
    this.status = AuthStatus.unknown,
    this.phone,
    this.error,
    this.busy = false,
    this.onboarded = false,
  });

  final AuthStatus status;
  final String? phone;
  final String? error;
  final bool busy;
  final bool onboarded; // completed quiz + payment

  SessionState copyWith({
    AuthStatus? status,
    String? phone,
    String? error,
    bool? busy,
    bool? onboarded,
  }) =>
      SessionState(
        status: status ?? this.status,
        phone: phone ?? this.phone,
        error: error,
        busy: busy ?? this.busy,
        onboarded: onboarded ?? this.onboarded,
      );
}

class SessionController extends StateNotifier<SessionState> {
  SessionController(this._api) : super(const SessionState()) {
    _bootstrap();
  }

  final ApiClient _api;

  Future<void> _bootstrap() async {
    final token = await _api.readToken();
    state = state.copyWith(
      status: token != null ? AuthStatus.signedIn : AuthStatus.signedOut,
      onboarded: token != null,
    );
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
      state = state.copyWith(status: AuthStatus.signedIn, busy: false, onboarded: onboarded);
      return true;
    } on DioException catch (e) {
      if (AppConfig.demoMode && code == '123456') {
        await _api.saveToken('demo-token');
        state = state.copyWith(status: AuthStatus.signedIn, busy: false, onboarded: false);
        return true;
      }
      state = state.copyWith(busy: false, error: _msg(e));
      return false;
    }
  }

  void completeOnboarding() => state = state.copyWith(onboarded: true);

  /// Return from the OTP step back to phone entry.
  void resetToPhone() =>
      state = state.copyWith(status: AuthStatus.signedOut, error: null);

  Future<void> signOut() async {
    await _api.clearToken();
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
  return SessionController(ref.watch(apiClientProvider));
});
