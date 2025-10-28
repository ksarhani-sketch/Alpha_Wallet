import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'budget_progress.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  _BudgetFilter _filter = _BudgetFilter.all;

  @override
  Widget build(BuildContext context) {
    final insights = ref.watch(budgetInsightsProvider);
    final currency = ref.watch(primaryCurrencyProvider);
    final filtered = insights.where((insight) {
      switch (_filter) {
        case _BudgetFilter.all:
          return true;
        case _BudgetFilter.alerts:
          return insight.isAlert || insight.isExceeded;
        case _BudgetFilter.exceeded:
          return insight.isExceeded;
      }
    }).toList();

    if (insights.isEmpty) {
      return const Center(
        child: Text('Create your first budget to start tracking spending.'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<_BudgetFilter>(
            segments: const [
              ButtonSegment(value: _BudgetFilter.all, label: Text('All')),
              ButtonSegment(value: _BudgetFilter.alerts, label: Text('Alerts')),
              ButtonSegment(value: _BudgetFilter.exceeded, label: Text('Over budget')),
            ],
            selected: {_filter},
            onSelectionChanged: (selection) {
              setState(() => _filter = selection.first);
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final insight = filtered[index];
              return BudgetProgressMeter(insight: insight, currency: currency);
            },
          ),
        ),
      ],
    );
  }
}

enum _BudgetFilter { all, alerts, exceeded }
