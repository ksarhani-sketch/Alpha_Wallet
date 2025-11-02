import 'dart:collection';

import 'models/models.dart';

class FinanceState {
  FinanceState({
    Iterable<Category>? categories,
    Iterable<Wallet>? wallets,
    Iterable<TransactionRecord>? transactions,
    Iterable<Budget>? budgets,
    Iterable<RecurringTemplate>? recurringTemplates,
    UserSettings? settings,
    Map<String, double>? fxRates,
    DateTime? lastSyncedAt,
    this.isSyncing = false,
  })  : _categories = List<Category>.unmodifiable(categories ?? const []),
        _wallets = List<Wallet>.unmodifiable(wallets ?? const []),
        _transactions = List<TransactionRecord>.unmodifiable(transactions ?? const []),
        _budgets = List<Budget>.unmodifiable(budgets ?? const []),
        _recurringTemplates =
            List<RecurringTemplate>.unmodifiable(recurringTemplates ?? const []),
        settings = settings ??
            const UserSettings(
              userId: 'local-sample-user',
              primaryCurrency: 'USD',
              locale: 'en',
            ),
        fxRates = Map.unmodifiable(fxRates ?? const {'USD': 1.0}),
        lastSyncedAt = lastSyncedAt ?? DateTime.now().subtract(const Duration(minutes: 15));

  final List<Category> _categories;
  final List<Wallet> _wallets;
  final List<TransactionRecord> _transactions;
  final List<Budget> _budgets;
  final List<RecurringTemplate> _recurringTemplates;
  final Map<String, double> fxRates;
  final UserSettings settings;
  final DateTime lastSyncedAt;
  final bool isSyncing;

  UnmodifiableListView<Category> get categories => UnmodifiableListView(_categories);
  UnmodifiableListView<Wallet> get wallets => UnmodifiableListView(_wallets);
  UnmodifiableListView<TransactionRecord> get transactions =>
      UnmodifiableListView(_transactions);
  UnmodifiableListView<Budget> get budgets => UnmodifiableListView(_budgets);
  UnmodifiableListView<RecurringTemplate> get recurringTemplates =>
      UnmodifiableListView(_recurringTemplates);

  FinanceState copyWith({
    Iterable<Category>? categories,
    Iterable<Wallet>? wallets,
    Iterable<TransactionRecord>? transactions,
    Iterable<Budget>? budgets,
    Iterable<RecurringTemplate>? recurringTemplates,
    UserSettings? settings,
    Map<String, double>? fxRates,
    DateTime? lastSyncedAt,
    bool? isSyncing,
  }) {
    return FinanceState(
      categories: categories ?? _categories,
      wallets: wallets ?? _wallets,
      transactions: transactions ?? _transactions,
      budgets: budgets ?? _budgets,
      recurringTemplates: recurringTemplates ?? _recurringTemplates,
      settings: settings ?? this.settings,
      fxRates: fxRates ?? this.fxRates,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}
