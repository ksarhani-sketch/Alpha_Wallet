// lib/models/category.dart
// UI-free domain model: no Flutter imports.

enum CategoryType { income, expense }

/// Domain model for a spending/earning category.
/// - `colorHex`: "#RRGGBB" (or "#AARRGGBB" accepted on input; store/output as "#RRGGBB").
/// - `iconName`: stable identifier like "shopping_bag", "restaurant", etc.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.type,
    required this.colorHex,
    required this.iconName,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final CategoryType type;
  final String colorHex; // e.g. "#FF9800"
  final String iconName; // e.g. "shopping_bag"
  final bool isDefault;

  Category copyWith({
    String? id,
    String? name,
    CategoryType? type,
    String? colorHex,
    String? iconName,
    bool? isDefault,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      colorHex: colorHex ?? this.colorHex,
      iconName: iconName ?? this.iconName,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  /// Optional helpers if you want easy (de)serialization in the domain layer.
  factory Category.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String? ?? 'expense').toLowerCase();
    return Category(
      id: json['categoryId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Category',
      type: rawType == 'income' ? CategoryType.income : CategoryType.expense,
      colorHex: _normalizeHex(json['color'] as String?),
      iconName: ((json['icon'] as String?) ?? 'category').trim().isEmpty
          ? 'category'
          : (json['icon'] as String).trim(),
      isDefault: json['isDefault'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'categoryId': id,
        'name': name,
        'type': type == CategoryType.income ? 'income' : 'expense',
        'color': colorHex,
        'icon': iconName,
        'isDefault': isDefault,
      };
}

/// Keep hex normalized as "#RRGGBB" (drop alpha if present). Fallback = "#607D8B".
String _normalizeHex(String? hex) {
  final raw = (hex ?? '').replaceAll('#', '').trim();
  if (raw.isEmpty) return '#607D8B';
  // Accept 6 (RRGGBB) or 8 (AARRGGBB). Store/output as #RRGGBB.
  final six = raw.length == 6
      ? raw
      : raw.length == 8
          ? raw.substring(2)
          : '607D8B';
  final upper = six.toUpperCase();
  final valid = RegExp(r'^[0-9A-F]{6}$').hasMatch(upper);
  return '#${valid ? upper : '607D8B'}';
}
