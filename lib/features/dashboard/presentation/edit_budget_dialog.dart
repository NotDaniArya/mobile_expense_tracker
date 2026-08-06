import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../budget_group/domain/budget_models.dart';
import '../../budget_group/data/budget_repository.dart';

void showEditBudgetDialog(BuildContext context, WidgetRef ref, List<CategoryGroupWithStats> groups) {
  showDialog(
    context: context,
    builder: (context) => _EditBudgetDialog(groups: groups),
  );
}

class _EditBudgetDialog extends ConsumerStatefulWidget {
  final List<CategoryGroupWithStats> groups;

  const _EditBudgetDialog({required this.groups});

  @override
  ConsumerState<_EditBudgetDialog> createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends ConsumerState<_EditBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<int, TextEditingController> _controllers = {};
  double _totalNewBudget = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize controllers for each category and calculate initial total
    for (var group in widget.groups) {
      for (var cat in group.categories) {
        final initialBudget = cat.category.targetBudget;
        _controllers[cat.category.id] = TextEditingController(text: initialBudget.toInt().toString());
      }
    }
    _recalculateTotal();
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _recalculateTotal() {
    double total = 0.0;
    _controllers.forEach((_, controller) {
      final val = double.tryParse(controller.text) ?? 0.0;
      total += val;
    });
    setState(() {
      _totalNewBudget = total;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);

    return AlertDialog(
      title: const Text('Edit Anggaran Bulanan'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sesuaikan anggaran target untuk masing-masing kategori di bawah ini:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.groups.length,
                  itemBuilder: (context, index) {
                    final group = widget.groups[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 10.0, bottom: 6.0),
                          child: Text(
                            group.group.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        ...group.categories.map((cat) {
                          final controller = _controllers[cat.category.id]!;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    cat.category.name,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.end,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (_) => _recalculateTotal(),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) return 'Wajib diisi';
                                      final num = double.tryParse(val);
                                      if (num == null || num < 0) return 'Tidak valid';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Anggaran Baru:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    currencyFormatter.format(_totalNewBudget),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final repository = ref.read(budgetRepositoryProvider);

              // Update each category target budget in database
              for (var entry in _controllers.entries) {
                final categoryId = entry.key;
                final newBudget = double.parse(entry.value.text);
                await repository.updateCategoryBudget(categoryId, newBudget);
              }

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Total anggaran bulanan berhasil diperbarui!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
