/// UI-free user settings model that can be serialized for persistence.
class UserSettings {
  const UserSettings({
    required this.userId,
    required this.primaryCurrency,
    required this.locale,
    required this.syncEnabled,
    this.premium = false,
    this.appLockEnabled = false,
    this.appLockTimeoutMinutes = 5,
    this.dailyReminderEnabled = false,
  });

  final String userId;
  final String primaryCurrency;
  final String locale;
  final bool syncEnabled;
  final bool premium;
  final bool appLockEnabled;
  final int appLockTimeoutMinutes;
  final bool dailyReminderEnabled;

  UserSettings copyWith({
    String? userId,
    String? primaryCurrency,
    String? locale,
    bool? syncEnabled,
    bool? premium,
    bool? appLockEnabled,
    int? appLockTimeoutMinutes,
    bool? dailyReminderEnabled,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      primaryCurrency: primaryCurrency ?? this.primaryCurrency,
      locale: locale ?? this.locale,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      premium: premium ?? this.premium,
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      appLockTimeoutMinutes: appLockTimeoutMinutes ?? this.appLockTimeoutMinutes,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        userId: (json['userId'] as String?) ?? '',
        primaryCurrency: (json['primaryCurrency'] as String?)?.toUpperCase() ?? 'USD',
        locale: (json['locale'] as String?) ?? 'en',
        syncEnabled: json['syncEnabled'] != false,
        premium: json['premium'] == true,
        appLockEnabled: json['appLockEnabled'] == true,
        appLockTimeoutMinutes:
            (json['appLockTimeoutMinutes'] as num?)?.round() ?? 5,
        dailyReminderEnabled: json['dailyReminderEnabled'] == true,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'primaryCurrency': primaryCurrency,
        'locale': locale,
        'syncEnabled': syncEnabled,
        'premium': premium,
        'appLockEnabled': appLockEnabled,
        'appLockTimeoutMinutes': appLockTimeoutMinutes,
        'dailyReminderEnabled': dailyReminderEnabled,
      };
}
