import 'package:flutter/material.dart';

import '../../data/models/category.dart';

class NewCategoryData {
  const NewCategoryData({
    required this.name,
    required this.type,
    required this.color,
    required this.icon,
    this.budgetLimit,
    this.alertThreshold,
    this.rollover = false,
  });

  final String name;
  final CategoryType type;
  final Color color;
  final IconData icon;
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
  Color _selectedColor = _colorOptions.first;
  IconData _selectedIcon = _iconOptions.first;
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
                      label: Icon(icon),
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
                        backgroundColor: color,
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
      color: _selectedColor,
      icon: _selectedIcon,
      budgetLimit: limit,
      alertThreshold: limit == null ? null : _alertThreshold,
      rollover: limit == null ? false : _rollover,
    ));
  }
}

const List<IconData> _iconOptions = [
  Icons.category,
  Icons.fastfood,
  Icons.local_grocery_store,
  Icons.directions_bus,
  Icons.health_and_safety,
  Icons.savings,
  Icons.vaccines,
  Icons.fitness_center,
  Icons.work,
  Icons.coffee,
  Icons.school,
];

const List<Color> _colorOptions = [
  Color(0xFFEF6C00),
  Color(0xFF7B1FA2),
  Color(0xFF3949AB),
  Color(0xFFD81B60),
  Color(0xFF00897B),
  Color(0xFF558B2F),
  Color(0xFF455A64),
  Color(0xFFFFB300),
  Color(0xFF00ACC1),
  Color(0xFF5D4037),
  Color(0xFF1E88E5),
];
