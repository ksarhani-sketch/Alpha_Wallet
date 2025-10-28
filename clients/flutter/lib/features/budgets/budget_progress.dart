import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../data/providers.dart';

class BudgetProgressMeter extends StatelessWidget {
  const BudgetProgressMeter({super.key, required this.insight, required this.currency});

  final BudgetInsight insight;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final progress = insight.progress.clamp(0.0, 1.5);
    final theme = Theme.of(context);
    final color = insight.isExceeded
        ? theme.colorScheme.error
        : insight.isAlert
            ? theme.colorScheme.tertiary
            : theme.colorScheme.primary;
    final title = insight.budget.isOverall
        ? 'Overall budget'
        : insight.category?.name ?? 'Category budget';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  height: 64,
                  width: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress > 1 ? 1 : progress,
                        color: color,
                        strokeWidth: 6,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                      ),
                      Text('${(progress * 100).clamp(0, 199).round()}%'),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${formatCurrency(insight.spent, currency)} spent'),
                      const SizedBox(height: 4),
                      Text('Limit ${formatCurrency(insight.budget.limit, currency)}'),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress > 1 ? 1 : progress,
                        color: color,
                        backgroundColor: theme.colorScheme.surfaceVariant,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (insight.isExceeded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Over budget by ${formatCurrency(insight.spent - insight.budget.limit, currency)}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Remaining ${formatCurrency(insight.remaining, currency)}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
