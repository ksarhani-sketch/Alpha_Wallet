import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  TransactionKind? _kindFilter;
  String? _walletFilter;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeControllerProvider);
    final transactions = state.transactions.where((tx) {
      final matchesKind = _kindFilter == null || tx.kind == _kindFilter;
      final matchesWallet = _walletFilter == null || tx.walletId == _walletFilter;
      final matchesSearch = _search.isEmpty ||
          (tx.note?.toLowerCase().contains(_search) ?? false) ||
          state.categories
              .firstWhere((cat) => cat.id == tx.categoryId)
              .name
              .toLowerCase()
              .contains(_search);
      return matchesKind && matchesWallet && matchesSearch;
    }).toList();

    final grouped = groupBy(transactions, (tx) => DateTime(tx.timestamp.year,
        tx.timestamp.month, tx.timestamp.day));
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search notes or categories',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _search = value.toLowerCase()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String?>(
                    value: _walletFilter,
                    hint: const Text('Wallet'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All wallets')),
                      for (final wallet in state.wallets)
                        DropdownMenuItem(
                          value: wallet.id,
                          child: Text(wallet.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _walletFilter = value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _kindFilter == null,
                      onSelected: (_) => setState(() => _kindFilter = null),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Expense'),
                      selected: _kindFilter == TransactionKind.expense,
                      onSelected: (_) => setState(() => _kindFilter = TransactionKind.expense),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Income'),
                      selected: _kindFilter == TransactionKind.income,
                      onSelected: (_) => setState(() => _kindFilter = TransactionKind.income),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Transfer'),
                      selected: _kindFilter == TransactionKind.transfer,
                      onSelected: (_) =>
                          setState(() => _kindFilter = TransactionKind.transfer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              final date = sortedKeys[index];
              final items = [...?grouped[date]]
                ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        '${formatDate(date)} · ${formatCurrency(_dailyTotal(items), state.wallets.first.currency)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    for (final tx in items)
                      TransactionTile(
                        transaction: tx,
                        category: state.categories.firstWhere((cat) => cat.id == tx.categoryId),
                        wallet: state.wallets.firstWhere((wallet) => wallet.id == tx.walletId),
                        onDelete: () => _confirmDelete(tx.id),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  double _dailyTotal(List<TransactionRecord> transactions) {
    double total = 0;
    for (final tx in transactions) {
      total += tx.kind == TransactionKind.expense ? tx.amount : -tx.amount;
    }
    return total;
  }

  Future<void> _confirmDelete(String id) async {
    final controller = ref.read(financeControllerProvider.notifier);
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text('This will remove the transaction from all reports.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      controller.deleteTransaction(id);
    }
  }
}
