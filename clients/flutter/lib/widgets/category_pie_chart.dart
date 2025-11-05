import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/models/category.dart';
import '../ui/category_ui_mapper.dart';

class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.data});

  final Map<Category, double> data;

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<double>(0, (sum, value) => sum + value);
    if (data.isEmpty || total == 0) {
      return const Center(child: Text('No expense data yet.'));
    }
    final textStyle = Theme.of(context).textTheme.labelLarge;
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: [
          for (final entry in data.entries)
            PieChartSectionData(
              color: UiCategory.fromDomain(entry.key).color,
              value: entry.value,
              title: '${(entry.value / total * 100).round()}%',
              titleStyle: textStyle?.copyWith(color: Colors.white),
              radius: 60,
            ),
        ],
      ),
    );
  }
}
