import 'package:flutter/material.dart';

import 'finance_state.dart';
import 'models/models.dart';

FinanceState buildSampleState() {
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59);

  final categories = [
    const Category(
      id: 'cat-food',
      name: 'Food & Dining',
      type: CategoryType.expense,
      color: Color(0xFFEF6C00),
      icon: Icons.restaurant,
      isDefault: true,
    ),
    const Category(
      id: 'cat-transport',
      name: 'Transport',
      type: CategoryType.expense,
      color: Color(0xFF7B1FA2),
      icon: Icons.directions_bus,
      isDefault: true,
    ),
    const Category(
      id: 'cat-rent',
      name: 'Rent',
      type: CategoryType.expense,
      color: Color(0xFF3949AB),
      icon: Icons.home_work,
      isDefault: true,
    ),
    const Category(
      id: 'cat-entertainment',
      name: 'Entertainment',
      type: CategoryType.expense,
      color: Color(0xFFD81B60),
      icon: Icons.movie_outlined,
    ),
    const Category(
      id: 'cat-groceries',
      name: 'Groceries',
      type: CategoryType.expense,
      color: Color(0xFF00897B),
      icon: Icons.shopping_basket,
    ),
    const Category(
      id: 'cat-salary',
      name: 'Salary',
      type: CategoryType.income,
      color: Color(0xFF558B2F),
      icon: Icons.payments,
    ),
    const Category(
      id: 'cat-freelance',
      name: 'Freelance',
      type: CategoryType.income,
      color: Color(0xFF455A64),
      icon: Icons.auto_graph,
    ),
  ];

  final wallets = [
    const Wallet(
      id: 'wallet-cash',
      name: 'Cash Wallet',
      currency: 'USD',
      balance: 320.0,
      type: WalletType.cash,
    ),
    const Wallet(
      id: 'wallet-bank',
      name: 'Checking Account',
      currency: 'USD',
      balance: 2400.0,
      type: WalletType.bank,
      isShared: true,
    ),
    const Wallet(
      id: 'wallet-card',
      name: 'Credit Card',
      currency: 'USD',
      balance: -450.0,
      type: WalletType.card,
    ),
  ];

  final transactions = [
    TransactionRecord(
      id: 'tx-001',
      walletId: 'wallet-cash',
      amount: 18.5,
      currency: 'USD',
      categoryId: 'cat-food',
      kind: TransactionKind.expense,
      timestamp: now.subtract(const Duration(hours: 3)),
      note: 'Quick lunch',
      tags: const ['lunch'],
      merchant: 'City Bites',
    ),
    TransactionRecord(
      id: 'tx-002',
      walletId: 'wallet-cash',
      amount: 42.0,
      currency: 'USD',
      categoryId: 'cat-groceries',
      kind: TransactionKind.expense,
      timestamp: now.subtract(const Duration(days: 1, hours: 4)),
      note: 'Fresh Market run',
      tags: const ['weekly'],
    ),
    TransactionRecord(
      id: 'tx-003',
      walletId: 'wallet-bank',
      amount: 1200.0,
      currency: 'USD',
      categoryId: 'cat-rent',
      kind: TransactionKind.expense,
      timestamp: DateTime(now.year, now.month, 1, 9),
      note: 'Apartment rent',
    ),
    TransactionRecord(
      id: 'tx-004',
      walletId: 'wallet-bank',
      amount: 3500.0,
      currency: 'USD',
      categoryId: 'cat-salary',
      kind: TransactionKind.income,
      timestamp: DateTime(now.year, now.month, 1, 6),
      note: 'Acme Corp payroll',
    ),
    TransactionRecord(
      id: 'tx-005',
      walletId: 'wallet-card',
      amount: 56.7,
      currency: 'USD',
      categoryId: 'cat-entertainment',
      kind: TransactionKind.expense,
      timestamp: now.subtract(const Duration(days: 4)),
      note: 'Movie night',
    ),
    TransactionRecord(
      id: 'tx-006',
      walletId: 'wallet-bank',
      amount: 220.0,
      currency: 'USD',
      categoryId: 'cat-transport',
      kind: TransactionKind.expense,
      timestamp: now.subtract(const Duration(days: 2)),
      note: 'Monthly metro pass',
    ),
    TransactionRecord(
      id: 'tx-007',
      walletId: 'wallet-bank',
      amount: 640.0,
      currency: 'USD',
      categoryId: 'cat-freelance',
      kind: TransactionKind.income,
      timestamp: now.subtract(const Duration(days: 5)),
      note: 'UX consulting',
    ),
  ];

  final budgets = [
    Budget(
      id: 'budget-overall',
      currency: 'USD',
      limit: 2000,
      period: BudgetPeriod.monthly,
      periodStart: startOfMonth,
      periodEnd: endOfMonth,
    ),
    Budget(
      id: 'budget-food',
      currency: 'USD',
      limit: 450,
      period: BudgetPeriod.monthly,
      periodStart: startOfMonth,
      periodEnd: endOfMonth,
      categoryId: 'cat-food',
      alertThreshold: 0.85,
    ),
    Budget(
      id: 'budget-transport',
      currency: 'USD',
      limit: 250,
      period: BudgetPeriod.monthly,
      periodStart: startOfMonth,
      periodEnd: endOfMonth,
      categoryId: 'cat-transport',
    ),
  ];

  final recurring = [
    RecurringTemplate(
      id: 'recur-rent',
      name: 'Rent',
      frequency: RecurrenceFrequency.monthly,
      nextRun: DateTime(now.year, now.month + 1, 1, 9),
      template: transactions.firstWhere((tx) => tx.id == 'tx-003'),
      reminderMinutesBefore: 60 * 24,
    ),
    RecurringTemplate(
      id: 'recur-salary',
      name: 'Salary',
      frequency: RecurrenceFrequency.monthly,
      nextRun: DateTime(now.year, now.month + 1, 1, 6),
      template: transactions.firstWhere((tx) => tx.id == 'tx-004'),
    ),
  ];

  return FinanceState(
    categories: categories,
    wallets: wallets,
    transactions: transactions,
    budgets: budgets,
    recurringTemplates: recurring,
    settings: const UserSettings(
      userId: 'local-sample-user',
      primaryCurrency: 'USD',
      locale: 'en',
      premium: true,
      dailyReminderEnabled: true,
      appLockEnabled: true,
    ),
    fxRates: const {
      'USD': 1.0,
      'EUR': 0.94,
      'OMR': 0.38,
    },
  );
}
