import 'package:equatable/equatable.dart';

enum AuthStatus {
  initializing,
  signedOut,
  signingIn,
  signedIn,
  error,
}

class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.username,
    this.errorMessage,
    this.lastUpdated,
  });

  const AuthState.initial()
      : status = AuthStatus.initializing,
        username = null,
        errorMessage = null,
        lastUpdated = null;

  final AuthStatus status;
  final String? username;
  final String? errorMessage;
  final DateTime? lastUpdated;

  AuthState copyWith({
    AuthStatus? status,
    String? username,
    String? errorMessage,
    DateTime? lastUpdated,
  }) {
    return AuthState(
      status: status ?? this.status,
      username: username ?? this.username,
      errorMessage: errorMessage,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [status, username, errorMessage, lastUpdated];
}
