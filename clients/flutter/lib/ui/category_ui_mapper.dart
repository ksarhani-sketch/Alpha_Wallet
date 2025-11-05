import 'package:flutter/material.dart';

import '../data/models/category.dart';

/// Central icon registry used by the UI only.
/// Expand as your app grows; keep keys stable (stored in DB / API).
const Map<String, IconData> kIconRegistry = {
  'category': Icons.category,
  'fastfood': Icons.fastfood,
  'local_grocery_store': Icons.local_grocery_store,
  'directions_bus': Icons.directions_bus,
  'health_and_safety': Icons.health_and_safety,
  'savings': Icons.savings,
  'vaccines': Icons.vaccines,
  'fitness_center': Icons.fitness_center,
  'work': Icons.work,
  'coffee': Icons.coffee,
  'school': Icons.school,
  'restaurant': Icons.restaurant,
  'home_work': Icons.home_work,
  'movie': Icons.movie,
  'movie_outlined': Icons.movie_outlined,
  'shopping_basket': Icons.shopping_basket,
  'shopping_bag': Icons.shopping_bag,
  'payments': Icons.payments,
  'auto_graph': Icons.auto_graph,
  'restaurant_menu': Icons.restaurant_menu,
};

IconData iconFor(String? name) =>
    kIconRegistry[(name ?? '').trim()] ?? Icons.category;

Color colorFromHex(String? hex) {
  final raw = (hex ?? '').replaceAll('#', '').trim();
  if (raw.isEmpty) return const Color(0xFF607D8B); // blueGrey
  final six = raw.length == 6 ? raw : raw.length == 8 ? raw.substring(2) : '607D8B';
  final value = int.tryParse(six, radix: 16) ?? 0x607D8B;
  return Color(0xFF000000 | value);
}

/// Example UI view-model if you want to keep UI tidy
class UiCategory {
  final String id;
  final String name;
  final CategoryType type;
  final Color color;
  final IconData icon;

  UiCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
  });

  factory UiCategory.fromDomain(Category c) => UiCategory(
        id: c.id,
        name: c.name,
        type: c.type,
        color: colorFromHex(c.colorHex),
        icon: iconFor(c.iconName),
      );
}
