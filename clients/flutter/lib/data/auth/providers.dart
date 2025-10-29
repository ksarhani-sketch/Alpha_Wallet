import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_state.dart';
import 'cognito_auth_service.dart';

final cognitoAuthServiceProvider = Provider<CognitoAuthService>((ref) {
  final service = CognitoAuthService();
  return service;
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final service = ref.watch(cognitoAuthServiceProvider);
  return AuthController(service);
});
