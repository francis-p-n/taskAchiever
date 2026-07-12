import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:life_os/core/theme.dart';
import 'package:life_os/features/spending/data/spending_repository.dart';

typedef _ExpenseDraft = ({int cents, String merchant, String category});

/// Opens the add-expense sheet and persists the result. Public so the
/// dashboard quick action, the Gold screen and the home-screen widget deep
/// link all share one flow.
Future<void> showAddExpenseSheet(BuildContext context, WidgetRef ref) async {
  final draft = await showModalBottomSheet<_ExpenseDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: NotionColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
      side: BorderSide(color: NotionColors.border),
    ),
    builder: (_) => const _AddExpenseSheet(),
  );
  if (draft == null) return;

  final ok = await ref.read(spendingRepositoryProvider).addTransaction(
        amountCents: draft.cents,
        category: draft.category,
        merchant: draft.merchant,
      );
  if (ok) {
    ref.invalidate(recentSpendingProvider);
    ref.invalidate(spendingSummaryProvider);
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '\$${(draft.cents / 100).toStringAsFixed(2)} at ${draft.merchant} logged.'
            : 'Could not save expense — backend offline.'),
      ),
    );
  }
}

class _AddExpenseSheet extends StatefulWidget {
  const _AddExpenseSheet();

  @override
  State<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<_AddExpenseSheet> {
  static const _categories = ['Food', 'Transport', 'Fun', 'Bills', 'Other'];

  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  String _category = 'Food';

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) return;
    final merchant = _merchantController.text.trim();
    Navigator.of(context).pop<_ExpenseDraft>((
      cents: (amount * 100).round(),
      merchant: merchant.isEmpty ? 'Expense' : merchant,
      category: _category,
    ));
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontSize: 12, color: NotionColors.textMuted),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: NotionColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: NotionColors.textMuted),
        ),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add expense', style: NotionType.display(size: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(fontSize: 13),
                  decoration: _decoration('Amount (\$)'),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _merchantController,
                  style: const TextStyle(fontSize: 13),
                  decoration: _decoration('Where / what'),
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final category in _categories)
                ChoiceChip(
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                  label: Text(category, style: const TextStyle(fontSize: 12)),
                  selectedColor: NotionColors.surfaceHover,
                  backgroundColor: NotionColors.surface,
                  side: BorderSide(
                    color: _category == category
                        ? const Color(0xFF5A5A5A)
                        : NotionColors.border,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NotionColors.surfaceHover,
                foregroundColor: NotionColors.textPrimary,
              ),
              onPressed: _submit,
              child: const Text('Save', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
