import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import '../../widgets/category_legend.dart';
import '../../widgets/category_pie_chart.dart';
import '../../widgets/transaction_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(financeControllerProvider);
    final totalBalance = ref.watch(totalBalanceProvider);
    final currency = ref.watch(primaryCurrencyProvider);
    final budgets = ref.watch(budgetInsightsProvider);
    final categoryBreakdown = ref.watch(categoryBreakdownProvider);
    final recurring = ref.watch(monthlyRecurringProvider);
    final recentTransactions = ref.watch(recentTransactionsProvider);

    final now = DateTime.now();
    final spentThisMonth = state.transactions
        .where((tx) =>
            tx.kind == TransactionKind.expense &&
            tx.timestamp.year == now.year &&
            tx.timestamp.month == now.month)
        .fold<double>(0, (sum, tx) => sum + tx.amount);
    final incomeThisMonth = state.transactions
        .where((tx) =>
            tx.kind == TransactionKind.income &&
            tx.timestamp.year == now.year &&
            tx.timestamp.month == now.month)
        .fold<double>(0, (sum, tx) => sum + tx.amount);

    final overallBudget = budgets.firstWhereOrNull((b) => b.budget.isOverall);

    return RefreshIndicator(
      onRefresh: () => ref.read(financeControllerProvider.notifier).syncNow(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BalanceCard(
            totalBalance: totalBalance,
            currency: currency,
            spentThisMonth: spentThisMonth,
            incomeThisMonth: incomeThisMonth,
            wallets: state.wallets,
            lastSync: state.lastSyncedAt,
            isSyncing: state.isSyncing,
          ),
          const SizedBox(height: 16),
          if (categoryBreakdown.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Top categories', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 200,
                      child: CategoryPieChart(data: categoryBreakdown),
                    ),
                    const SizedBox(height: 12),
                    CategoryLegend(data: categoryBreakdown, currency: currency),
                  ],
                ),
              ),
            ),
          if (categoryBreakdown.isNotEmpty) const SizedBox(height: 16),
          if (budgets.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Budget health', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: budgets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final insight = budgets[index];
                          return SizedBox(
                            width: 260,
                            child: _BudgetMiniCard(
                              insight: insight,
                              currency: currency,
                            ),
                          );
                        },
                      ),
                    ),
                    if (overallBudget != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'Remaining this month: ${formatCurrency(overallBudget.remaining, currency)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (budgets.isNotEmpty) const SizedBox(height: 16),
          if (recurring.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upcoming recurring', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    for (final template in recurring)
                      ListTile(
                        leading: const Icon(Icons.repeat),
                        title: Text(template.name),
                        subtitle: Text(
                          'Next run ${formatDate(template.nextRun)}',
                        ),
                        trailing: Text(template.template.kind == TransactionKind.expense
                            ? '−${formatCurrency(template.template.amount, template.template.currency)}'
                            : '+${formatCurrency(template.template.amount, template.template.currency)}'),
                      ),
                  ],
                ),
              ),
            ),
          if (recurring.isNotEmpty) const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recent activity', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  for (final transaction in recentTransactions)
                    Builder(
                      builder: (context) {
                        final category = state.categories
                            .firstWhere((cat) => cat.id == transaction.categoryId);
                        final wallet =
                            state.wallets.firstWhere((wallet) => wallet.id == transaction.walletId);
                        return TransactionTile(
                          transaction: transaction,
                          category: category,
                          wallet: wallet,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.totalBalance,
    required this.currency,
    required this.spentThisMonth,
    required this.incomeThisMonth,
    required this.wallets,
    required this.lastSync,
    required this.isSyncing,
  });

  final double totalBalance;
  final String currency;
  final double spentThisMonth;
  final double incomeThisMonth;
  final List<Wallet> wallets;
  final DateTime lastSync;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Net worth', style: theme.textTheme.titleMedium),
                const Spacer(),
                Icon(
                  isSyncing ? Icons.sync : Icons.cloud_done_outlined,
                  size: 20,
                  color: isSyncing
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Synced ${formatTime(lastSync)}'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              formatCurrency(totalBalance, currency),
              style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MetricTile(
                    label: 'Spent this month',
                    value: formatCurrency(spentThisMonth, currency),
                    valueColor: Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricTile(
                    label: 'Income this month',
                    value: formatCurrency(incomeThisMonth, currency),
                    valueColor: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final wallet in wallets)
                  Chip(
                    label: Text('${wallet.name}: ${formatCurrency(wallet.balance, wallet.currency)}'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceVariant,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(color: valueColor),
          ),
        ],
      ),
    );
  }
}

class _BudgetMiniCard extends StatelessWidget {
  const _BudgetMiniCard({required this.insight, required this.currency});

  final BudgetInsight insight;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = insight.progress.clamp(0.0, 1.5);
    final color = insight.isExceeded
        ? theme.colorScheme.error
        : insight.isAlert
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.budget.isOverall
                ? 'Overall budget'
                : insight.category?.name ?? 'Category budget',
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          LinearProgressIndicator(
            value: progress > 1 ? 1 : progress,
            minHeight: 8,
            color: color,
            backgroundColor: theme.colorScheme.surface,
          ),
          const SizedBox(height: 12),
          Text('${formatCurrency(insight.spent, currency)} spent'),
          Text('Limit ${formatCurrency(insight.budget.limit, currency)}'),
        ],
      ),
    );
  }
}
