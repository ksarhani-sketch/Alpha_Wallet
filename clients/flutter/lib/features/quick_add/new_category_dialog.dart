import 'package:flutter/material.dart';

import '../../data/models/category.dart';

class NewCategoryData {
  const NewCategoryData({
    required this.name,
    required this.type,
    required this.colorHex,
    required this.iconName,
    this.budgetLimit,
    this.alertThreshold,
    this.rollover = false,
  });

  final String name;
  final CategoryType type;
  final String colorHex;
  final String iconName;
  final double? budgetLimit;
  final double? alertThreshold;
  final bool rollover;
}

class NewCategoryDialog extends StatefulWidget {
  const NewCategoryDialog({super.key, required this.initialType});

  final CategoryType initialType;

  @override
  State<NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<NewCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _limitController = TextEditingController();

  late CategoryType _type = widget.initialType;
  _ColorOption _selectedColor = _colorOptions.first;
  _IconOption _selectedIcon = _iconOptions.first;
  double _alertThreshold = 0.9;
  bool _rollover = false;

  @override
  void dispose() {
    _nameController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create new category'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Category name',
                  hintText: 'e.g. Pets, Gym, Gifts',
                ),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.length < 2) {
                    return 'Enter at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Category type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<CategoryType>(
                segments: const [
                  ButtonSegment(value: CategoryType.expense, label: Text('Expense'), icon: Icon(Icons.remove_circle)),
                  ButtonSegment(value: CategoryType.income, label: Text('Income'), icon: Icon(Icons.add_circle)),
                ],
                selected: {_type},
                onSelectionChanged: (selection) => setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final icon in _iconOptions)
                    ChoiceChip(
                      label: Icon(icon.icon),
                      selected: _selectedIcon == icon,
                      onSelected: (_) => setState(() => _selectedIcon = icon),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Colour', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final color in _colorOptions)
                    GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: CircleAvatar(
                        backgroundColor: color.color,
                        radius: _selectedColor == color ? 18 : 16,
                        child: _selectedColor == color
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _limitController,
                decoration: const InputDecoration(
                  labelText: 'Monthly budget limit (optional)',
                  prefixText: '\$',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return null;
                  }
                  final parsed = double.tryParse(trimmed);
                  if (parsed == null || parsed <= 0) {
                    return 'Enter a positive amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _hasBudget ? 1 : 0.4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alert threshold', style: Theme.of(context).textTheme.labelLarge),
                    Slider(
                      value: _alertThreshold,
                      min: 0.5,
                      max: 1.5,
                      divisions: 10,
                      label: '${(_alertThreshold * 100).round()}%',
                      onChanged: _hasBudget ? (value) => setState(() => _alertThreshold = value) : null,
                    ),
                    SwitchListTile(
                      title: const Text('Enable rollover'),
                      subtitle: const Text('Carry over unspent amount to next month'),
                      contentPadding: EdgeInsets.zero,
                      value: _rollover,
                      onChanged: _hasBudget ? (value) => setState(() => _rollover = value) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }

  bool get _hasBudget => _limitController.text.trim().isNotEmpty;

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final name = _nameController.text.trim();
    final limitText = _limitController.text.trim();
    final limit = limitText.isEmpty ? null : double.parse(limitText);

    Navigator.of(context).pop(NewCategoryData(
      name: name,
      type: _type,
      colorHex: _selectedColor.hex,
      iconName: _selectedIcon.name,
      budgetLimit: limit,
      alertThreshold: limit == null ? null : _alertThreshold,
      rollover: limit == null ? false : _rollover,
    ));
  }
}

class _IconOption {
  const _IconOption(this.name, this.icon);

  final String name;
  final IconData icon;
}

class _ColorOption {
  const _ColorOption(this.hex, this.color);

  final String hex;
  final Color color;
}

const List<_IconOption> _iconOptions = [
  _IconOption('category', Icons.category),
  _IconOption('fastfood', Icons.fastfood),
  _IconOption('local_grocery_store', Icons.local_grocery_store),
  _IconOption('directions_bus', Icons.directions_bus),
  _IconOption('health_and_safety', Icons.health_and_safety),
  _IconOption('savings', Icons.savings),
  _IconOption('vaccines', Icons.vaccines),
  _IconOption('fitness_center', Icons.fitness_center),
  _IconOption('work', Icons.work),
  _IconOption('coffee', Icons.coffee),
  _IconOption('school', Icons.school),
  _IconOption('restaurant', Icons.restaurant),
  _IconOption('home_work', Icons.home_work),
  _IconOption('movie_outlined', Icons.movie_outlined),
  _IconOption('shopping_basket', Icons.shopping_basket),
  _IconOption('shopping_bag', Icons.shopping_bag),
  _IconOption('payments', Icons.payments),
  _IconOption('auto_graph', Icons.auto_graph),
  _IconOption('restaurant_menu', Icons.restaurant_menu),
];

const List<_ColorOption> _colorOptions = [
  _ColorOption('#EF6C00', Color(0xFFEF6C00)),
  _ColorOption('#7B1FA2', Color(0xFF7B1FA2)),
  _ColorOption('#3949AB', Color(0xFF3949AB)),
  _ColorOption('#D81B60', Color(0xFFD81B60)),
  _ColorOption('#00897B', Color(0xFF00897B)),
  _ColorOption('#558B2F', Color(0xFF558B2F)),
  _ColorOption('#455A64', Color(0xFF455A64)),
  _ColorOption('#FFB300', Color(0xFFFFB300)),
  _ColorOption('#00ACC1', Color(0xFF00ACC1)),
  _ColorOption('#5D4037', Color(0xFF5D4037)),
  _ColorOption('#1E88E5', Color(0xFF1E88E5)),
];
