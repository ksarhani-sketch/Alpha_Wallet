import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../data/models/models.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.category,
    required this.wallet,
    this.onDelete,
  });

  final TransactionRecord transaction;
  final Category category;
  final Wallet wallet;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.kind == TransactionKind.expense;
    final amountText = formatCurrency(
      isExpense ? -transaction.amount : transaction.amount,
      wallet.currency,
    );
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.color.withOpacity(0.12),
          child: Icon(category.icon, color: category.color),
        ),
        title: Text(transaction.note ?? category.name),
        subtitle: Text(
          '${category.name} • ${wallet.name} • ${formatShortDate(transaction.timestamp)} ${formatTime(transaction.timestamp)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amountText,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isExpense ? Colors.redAccent : Colors.teal,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (transaction.tags.isNotEmpty)
              Text(
                transaction.tags.join(', '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        onLongPress: onDelete,
      ),
    );
  }
}
