import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'new_category_dialog.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key});

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagsController = TextEditingController();
  CategoryType _categoryType = CategoryType.expense;
  String? _categoryId;
  String? _walletId;
  bool _includeReceipt = false;
  bool _includeLocation = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(financeControllerProvider);
    final categories = state.categories
        .where((category) => category.type == _categoryType)
        .toList(growable: false);
    _categoryId ??= categories.isNotEmpty ? categories.first.id : null;
    _walletId ??= state.wallets.isNotEmpty ? state.wallets.first.id : null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Quick add transaction', style: TextStyle(fontSize: 18)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedButton<CategoryType>(
                  segments: const [
                    ButtonSegment(value: CategoryType.expense, label: Text('Expense'), icon: Icon(Icons.remove_circle_outline)),
                    ButtonSegment(value: CategoryType.income, label: Text('Income'), icon: Icon(Icons.add_circle_outline)),
                  ],
                  selected: {_categoryType},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _categoryType = selection.first;
                      _categoryId = null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a positive amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Text('Category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                if (categories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add your first category'),
                      onPressed: _isSubmitting ? null : _openNewCategoryDialog,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final category in categories)
                            ChoiceChip(
                              label: Text(category.name),
                              avatar: Icon(category.icon, size: 18),
                              selected: _categoryId == category.id,
                              onSelected: (_) => setState(() => _categoryId = category.id),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add new category'),
                        onPressed: _isSubmitting ? null : _openNewCategoryDialog,
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _walletId,
                  decoration: const InputDecoration(labelText: 'Wallet'),
                  items: [
                    for (final wallet in state.wallets)
                      DropdownMenuItem(
                        value: wallet.id,
                        child: Text('${wallet.name} (${wallet.currency})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _walletId = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    hintText: 'What was this for?',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'Comma separated (e.g. lunch,team)',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  children: [
                    FilterChip(
                      label: const Text('Add receipt photo'),
                      selected: _includeReceipt,
                      onSelected: (value) => setState(() => _includeReceipt = value),
                    ),
                    FilterChip(
                      label: const Text('Attach location'),
                      selected: _includeLocation,
                      onSelected: (value) => setState(() => _includeLocation = value),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isSubmitting ? 'Saving...' : 'Save transaction'),
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNewCategoryDialog() async {
    final result = await showDialog<NewCategoryData>(
      context: context,
      builder: (context) => NewCategoryDialog(initialType: _categoryType),
    );
    if (result == null) return;

    final controller = ref.read(financeControllerProvider.notifier);
    try {
      final created = await controller.createCategory(
        name: result.name,
        type: result.type,
        color: result.color,
        icon: result.icon,
        budgetLimit: result.budgetLimit,
        alertThreshold: result.alertThreshold,
        rollover: result.rollover,
      );
      if (!mounted) return;
      setState(() {
        _categoryType = created.type;
        _categoryId = created.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "${created.name}" created.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create category: $error')),
      );
    }
  }

  Future<void> _submit() async {
    final controller = ref.read(financeControllerProvider.notifier);
    if (!_formKey.currentState!.validate() || _categoryId == null || _walletId == null) {
      return;
    }
    setState(() => _isSubmitting = true);
    final amount = double.parse(_amountController.text);
    final tags = _tagsController.text
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    if (_includeReceipt) {
      tags.add('receipt');
    }
    if (_includeLocation) {
      tags.add('location');
    }
    try {
      await controller.addTransaction(
        amount: amount,
        walletId: _walletId!,
        categoryId: _categoryId!,
        note: _noteController.text.isEmpty ? null : _noteController.text,
        tags: tags,
        merchant: _noteController.text,
        locationDescription: _includeLocation ? 'Current location' : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved.')),
      );
    } on Exception catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save transaction: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
