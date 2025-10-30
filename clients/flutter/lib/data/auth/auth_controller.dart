import 'dart:async';

import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';
import 'cognito_auth_service.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._authService) : super(const AuthState.initial()) {
    unawaited(_bootstrap());
  }

  final CognitoAuthService _authService;

  Future<void> _bootstrap() async {
    try {
      await _authService.ensureConfigured();
      final signedIn = await _authService.isSignedIn();
      if (signedIn) {
        final user = await _authService.currentUser();
        state = state.copyWith(
          status: AuthStatus.signedIn,
          username: user?.username,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.signedOut,
          username: null,
          errorMessage: null,
        );
      }
    } on AmplifyConfigValidationException catch (error, stackTrace) {
      debugPrint('AuthController: Amplify config validation failed $error\n$stackTrace');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.message,
      );
    } on AmplifyException catch (error, stackTrace) {
      debugPrint('AuthController: Amplify configuration failed $error\n$stackTrace');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.message,
      );
    } catch (error, stackTrace) {
      debugPrint('AuthController: unexpected error $error\n$stackTrace');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> signIn() async {
    if (state.status == AuthStatus.signingIn) return;
    state = state.copyWith(status: AuthStatus.signingIn, errorMessage: null);
    try {
      await _authService.signIn();
      final user = await _authService.currentUser();
      state = state.copyWith(
        status: AuthStatus.signedIn,
        username: user?.username,
        errorMessage: null,
      );
    } on AmplifyConfigValidationException catch (error, stackTrace) {
      debugPrint('AuthController: sign-in validation failed $error\n$stackTrace');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.message,
      );
    } on AmplifyException catch (error, stackTrace) {
      debugPrint('AuthController: sign-in failed $error\n$stackTrace');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.message,
      );
    } catch (error, stackTrace) {
      debugPrint('AuthController: unexpected sign-in error $error\n$stackTrace');
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = state.copyWith(
      status: AuthStatus.signedOut,
      username: null,
      errorMessage: null,
    );
  }

  Future<void> retryConfiguration() async {
    state = const AuthState.initial();
    await _authService.reset();
    await _bootstrap();
  }

  Future<String?> refreshedToken() {
    return _authService.getLatestIdToken(forceRefresh: true);
  }
}
