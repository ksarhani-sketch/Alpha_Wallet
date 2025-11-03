import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'finance_repository.dart';
import 'finance_state.dart';
import 'models/models.dart';
import 'remote/finance_api_client.dart';

final financeApiClientProvider = Provider<FinanceApiClient>((ref) {
  final client = FinanceApiClient();
  ref.onDispose(client.close);
  return client;
});

final financeControllerProvider =
    StateNotifierProvider<FinanceController, FinanceState>((ref) {
  final apiClient = ref.watch(financeApiClientProvider);
  return FinanceController(apiClient: apiClient);
});

final primaryCurrencyProvider = Provider<String>((ref) {
  final state = ref.watch(financeControllerProvider);
  return state.settings.primaryCurrency;
});

final totalBalanceProvider = Provider<double>((ref) {
  final state = ref.watch(financeControllerProvider);
  return state.wallets.fold<double>(0, (sum, wallet) {
    final rate = state.fxRates[wallet.currency] ?? 1;
    return sum + wallet.balance / rate;
  });
});

class BudgetInsight {
  BudgetInsight({
    required this.budget,
    required this.spent,
    required this.progress,
    this.category,
  });

  final Budget budget;
  final double spent;
  final double progress;
  final Category? category;

  double get remaining => max(budget.limit - spent, 0);
  bool get isAlert => progress >= budget.alertThreshold;
  bool get isExceeded => spent > budget.limit;
}

final budgetInsightsProvider = Provider<List<BudgetInsight>>((ref) {
  final state = ref.watch(financeControllerProvider);
  return [
    for (final budget in state.budgets)
      () {
        final spent = state.transactions.where((tx) {
          if (tx.kind != TransactionKind.expense) return false;
          final inPeriod = !tx.timestamp.isBefore(budget.periodStart) &&
              !tx.timestamp.isAfter(budget.periodEnd);
          if (!inPeriod) return false;
          if (budget.categoryId == null) return true;
          return tx.categoryId == budget.categoryId;
        }).fold<double>(0, (sum, tx) => sum + tx.amount);
        final progress = budget.limit == 0 ? 0 : min(spent / budget.limit, 2);
        final category = budget.categoryId == null
            ? null
            : state.categories.firstWhereOrNull((cat) => cat.id == budget.categoryId);
        return BudgetInsight(
          budget: budget,
          spent: spent,
          progress: progress,
          category: category,
        );
      }(),
  ];
});

final categoryBreakdownProvider = Provider<Map<Category, double>>((ref) {
  final state = ref.watch(financeControllerProvider);
  final now = DateTime.now();
  final expenseTransactions = state.transactions.where((tx) =>
      tx.kind == TransactionKind.expense &&
      tx.timestamp.year == now.year &&
      tx.timestamp.month == now.month);
  final grouped = groupBy(expenseTransactions, (tx) => tx.categoryId);
  return {
    for (final entry in grouped.entries)
      state.categories.firstWhere((cat) => cat.id == entry.key):
          entry.value.fold<double>(0, (sum, tx) => sum + tx.amount)
  };
});

final recentTransactionsProvider = Provider<List<TransactionRecord>>((ref) {
  final state = ref.watch(financeControllerProvider);
  return state.transactions.take(10).toList(growable: false);
});

final monthlyRecurringProvider = Provider<List<RecurringTemplate>>((ref) {
  final state = ref.watch(financeControllerProvider);
  return state.recurringTemplates
      .where((template) => template.frequency == RecurrenceFrequency.monthly)
      .toList(growable: false);
});
