import 'package:flutter/material.dart';

enum CategoryType { income, expense }

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final CategoryType type;
  final Color color;
  final IconData icon;
  final bool isDefault;

  Category copyWith({
    String? id,
    String? name,
    CategoryType? type,
    Color? color,
    IconData? icon,
    bool? isDefault,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
