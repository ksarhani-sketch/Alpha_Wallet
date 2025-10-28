import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../data/models/category.dart';

class CategoryLegend extends StatelessWidget {
  const CategoryLegend({super.key, required this.data, required this.currency});

  final Map<Category, double> data;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final entry in data.entries)
          _LegendItem(
            category: entry.key,
            amount: entry.value,
            currency: currency,
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.category,
    required this.amount,
    required this.currency,
  });

  final Category category;
  final double amount;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(backgroundColor: category.color),
      label: Text('${category.name} · ${formatCurrency(amount, currency)}'),
    );
  }
}
