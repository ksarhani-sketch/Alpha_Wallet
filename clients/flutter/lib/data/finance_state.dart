import 'models/budget.dart';
import 'models/category.dart';
import 'models/recurring_transaction.dart';
import 'models/transaction_record.dart';
import 'models/user_settings.dart';
import 'models/wallet.dart';

/// Domain-level finance state shared between the data layer and UI.
class FinanceState {
  final List<Category> categories;
  final List<Wallet> wallets;
  final List<TransactionRecord> transactions;
  final List<Budget> budgets;
  final List<RecurringTemplate> recurringTemplates;
  final UserSettings settings;
  final Map<String, double> fxRates;
  final DateTime lastSyncedAt;
  final bool isSyncing;

  FinanceState({
    this.categories = const [],
    this.wallets = const [],
    this.transactions = const [],
    this.budgets = const [],
    this.recurringTemplates = const [],
    UserSettings? settings,
    this.fxRates = const {},
    DateTime? lastSyncedAt,
    this.isSyncing = false,
  })  : settings = settings ??
            const UserSettings(
              userId: 'demo-user',
              primaryCurrency: 'USD',
              locale: 'en',
              syncEnabled: true,
            ),
        lastSyncedAt =
            lastSyncedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  FinanceState copyWith({
    List<Category>? categories,
    List<Wallet>? wallets,
    List<TransactionRecord>? transactions,
    List<Budget>? budgets,
    List<RecurringTemplate>? recurringTemplates,
    UserSettings? settings,
    Map<String, double>? fxRates,
    DateTime? lastSyncedAt,
    bool? isSyncing,
  }) {
    return FinanceState(
      categories: categories ?? this.categories,
      wallets: wallets ?? this.wallets,
      transactions: transactions ?? this.transactions,
      budgets: budgets ?? this.budgets,
      recurringTemplates: recurringTemplates ?? this.recurringTemplates,
      settings: settings ?? this.settings,
      fxRates: fxRates ?? this.fxRates,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}
