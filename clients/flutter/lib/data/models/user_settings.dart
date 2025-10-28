class UserSettings {
  const UserSettings({
    required this.userId,
    required this.primaryCurrency,
    required this.locale,
    this.premium = false,
    this.appLockEnabled = false,
    this.appLockTimeoutMinutes = 5,
    this.syncEnabled = true,
    this.dailyReminderEnabled = false,
  });

  final String userId;
  final String primaryCurrency;
  final String locale;
  final bool premium;
  final bool appLockEnabled;
  final int appLockTimeoutMinutes;
  final bool syncEnabled;
  final bool dailyReminderEnabled;

  UserSettings copyWith({
    String? userId,
    String? primaryCurrency,
    String? locale,
    bool? premium,
    bool? appLockEnabled,
    int? appLockTimeoutMinutes,
    bool? syncEnabled,
    bool? dailyReminderEnabled,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      primaryCurrency: primaryCurrency ?? this.primaryCurrency,
      locale: locale ?? this.locale,
      premium: premium ?? this.premium,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockTimeoutMinutes: appLockTimeoutMinutes ?? this.appLockTimeoutMinutes,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
    );
  }
}
