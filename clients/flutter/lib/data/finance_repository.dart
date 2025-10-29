import 'dart:async';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'finance_state.dart';
import 'models/models.dart';
import 'remote/finance_api_client.dart';
import 'sample_data.dart';

class FinanceController extends StateNotifier<FinanceState> {
  FinanceController({FinanceApiClient? apiClient})
      : _api = apiClient ?? FinanceApiClient(),
        _uuid = const Uuid(),
        super(_initialState(apiClient ?? FinanceApiClient())) {
    if (_api.isEnabled) {
      _bootstrap();
    }
  }

  final FinanceApiClient _api;
  final Uuid _uuid;

  static FinanceState _initialState(FinanceApiClient api) {
    if (api.isEnabled) {
      return FinanceState(
        categories: const [],
        wallets: const [],
        transactions: const [],
        budgets: const [],
        recurringTemplates: const [],
        settings: const UserSettings(
          userId: 'remote-user',
          primaryCurrency: 'USD',
          locale: 'en',
        ),
        fxRates: const {'USD': 1.0},
        lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(0),
        isSyncing: true,
      );
    }
    return buildSampleState();
  }

  Future<void> _bootstrap() async {
    try {
      await _refreshFromRemote();
    } catch (_) {
      // keep optimistic state; errors will surface on explicit sync actions
    }
  }

  Future<void> _refreshFromRemote() async {
    if (!_api.isEnabled) return;
    state = state.copyWith(isSyncing: true);
    try {
      final remoteState = await _api.fetchState();
      state = remoteState;
    } on FinanceApiException catch (error, stackTrace) {
      debugPrint('FinanceController: failed to sync (${error.statusCode}) ${error.message}\n$stackTrace');
      state = state.copyWith(isSyncing: false);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('FinanceController: unexpected sync error $error\n$stackTrace');
      state = state.copyWith(isSyncing: false);
      rethrow;
    }
  }

  Future<void> addTransaction({
    required double amount,
    required String walletId,
    required String categoryId,
    String? note,
    List<String> tags = const [],
    String? merchant,
    String? locationDescription,
    double? fxRate,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive');
    }

    if (_api.isEnabled) {
      final category = state.categories.firstWhereOrNull((c) => c.id == categoryId);
      if (category == null) {
        throw StateError('Category $categoryId not found');
      }
      final type = category.type == CategoryType.income ? 'income' : 'expense';
      await _api.createTransaction(
        accountId: walletId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        note: note,
        tags: tags,
      );
      await _refreshFromRemote();
      return;
    }

    final wallet = state.wallets.firstWhere((w) => w.id == walletId);
    final category = state.categories.firstWhere((c) => c.id == categoryId);
    final kind = switch (category.type) {
      CategoryType.expense => TransactionKind.expense,
      CategoryType.income => TransactionKind.income,
    };

    final rate = fxRate ?? state.fxRates[wallet.currency] ?? 1;
    final normalizedAmount = amount;

    final transaction = TransactionRecord(
      id: _uuid.v4(),
      walletId: walletId,
      amount: double.parse(amount.toStringAsFixed(2)),
      currency: wallet.currency,
      categoryId: categoryId,
      kind: kind,
      timestamp: DateTime.now(),
      note: note,
      tags: List.unmodifiable(tags.where((tag) => tag.trim().isNotEmpty)),
      merchant: merchant,
      locationDescription: locationDescription,
      fxRate: rate,
    );

    final updatedTransactions = [...state.transactions, transaction]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final updatedWallets = [
      for (final w in state.wallets)
        if (w.id == walletId)
          w.copyWith(
              balance: _applyAmountToBalance(
                balance: w.balance,
                amount: normalizedAmount,
                kind: kind,
              ),
            )
        else
          w,
    ];

    state = state.copyWith(
      transactions: updatedTransactions,
      wallets: updatedWallets,
    );
  }

  void addTransfer({
    required String sourceWalletId,
    required String destinationWalletId,
    required double amount,
    String? note,
  }) {
    if (_api.isEnabled) {
      throw UnsupportedError('Transfers are not yet supported in remote mode.');
    }
    if (amount <= 0) return;
    final source = state.wallets.firstWhereOrNull((w) => w.id == sourceWalletId);
    final destination =
        state.wallets.firstWhereOrNull((w) => w.id == destinationWalletId);
    if (source == null || destination == null) return;

    final transactionOut = TransactionRecord(
      id: _uuid.v4(),
      walletId: sourceWalletId,
      amount: double.parse(amount.toStringAsFixed(2)),
      currency: source.currency,
      categoryId: 'transfer-out',
      kind: TransactionKind.transfer,
      timestamp: DateTime.now(),
      note: note ?? 'Transfer to ${destination.name}',
      counterpartyWalletId: destinationWalletId,
    );

    final transactionIn = transactionOut.copyWith(
      id: _uuid.v4(),
      walletId: destinationWalletId,
      currency: destination.currency,
      note: note ?? 'Transfer from ${source.name}',
      counterpartyWalletId: sourceWalletId,
    );

    final updatedTransactions = [...state.transactions, transactionOut, transactionIn]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final updatedWallets = state.wallets.map((wallet) {
      if (wallet.id == sourceWalletId) {
        return wallet.copyWith(balance: wallet.balance - amount);
      }
      if (wallet.id == destinationWalletId) {
        return wallet.copyWith(balance: wallet.balance + amount);
      }
      return wallet;
    }).toList();

    state = state.copyWith(
      transactions: updatedTransactions,
      wallets: updatedWallets,
    );
  }

  Future<void> deleteTransaction(String transactionId) async {
    if (_api.isEnabled) {
      await _api.deleteTransaction(transactionId);
      await _refreshFromRemote();
      return;
    }
    final transaction =
        state.transactions.firstWhereOrNull((tx) => tx.id == transactionId);
    if (transaction == null) return;

    final updatedTransactions = state.transactions
        .where((tx) => tx.id != transactionId)
        .toList(growable: false);

    final updatedWallets = state.wallets.map((wallet) {
      if (wallet.id != transaction.walletId) return wallet;
      final delta = transaction.kind == TransactionKind.expense
          ? transaction.amount
          : -transaction.amount;
      return wallet.copyWith(balance: wallet.balance + delta);
    }).toList(growable: false);

    state = state.copyWith(
      transactions: updatedTransactions,
      wallets: updatedWallets,
    );
  }

  Future<void> syncNow() async {
    if (state.isSyncing) return;
    if (_api.isEnabled) {
      await _refreshFromRemote();
      return;
    }
    state = state.copyWith(isSyncing: true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    state = state.copyWith(
      isSyncing: false,
      lastSyncedAt: DateTime.now(),
    );
  }

  void togglePremium(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(premium: value),
    );
  }

  void toggleAppLock(bool value) {
    state = state.copyWith(
      settings: state.settings.copyWith(appLockEnabled: value),
    );
  }

  void updateReminder({required bool enabled}) {
    state = state.copyWith(
      settings: state.settings.copyWith(dailyReminderEnabled: enabled),
    );
  }

  double monthlySpent(DateTime month) {
    return state.transactions
        .where((tx) =>
            tx.kind == TransactionKind.expense &&
            tx.timestamp.year == month.year &&
            tx.timestamp.month == month.month)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
  }

  Map<Category, double> categoryBreakdown(DateTime month) {
    final expenseTransactions = state.transactions.where((tx) =>
        tx.kind == TransactionKind.expense &&
        tx.timestamp.year == month.year &&
        tx.timestamp.month == month.month);
    final grouped = groupBy(expenseTransactions, (tx) => tx.categoryId);
    return {
      for (final entry in grouped.entries)
        state.categories.firstWhere((cat) => cat.id == entry.key):
            entry.value.fold<double>(0, (sum, tx) => sum + tx.amount)
    };
  }

  double budgetProgress(Budget budget) {
    final relevantTransactions = state.transactions.where((tx) {
      if (tx.kind != TransactionKind.expense) return false;
      final inPeriod = !tx.timestamp.isBefore(budget.periodStart) &&
          !tx.timestamp.isAfter(budget.periodEnd);
      if (!inPeriod) return false;
      if (budget.categoryId == null) return true;
      return tx.categoryId == budget.categoryId;
    });
    final spent = relevantTransactions.fold<double>(0, (sum, tx) => sum + tx.amount);
    return min(spent / budget.limit, 2);
  }

  double _applyAmountToBalance({
    required double balance,
    required double amount,
    required TransactionKind kind,
  }) {
    final updated = switch (kind) {
      TransactionKind.expense => balance - amount,
      TransactionKind.income => balance + amount,
      TransactionKind.transfer => balance,
    };
    return double.parse(updated.toStringAsFixed(2));
  }
}
