import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../budget_group/domain/budget_models.dart';
import '../../budget_group/data/budget_repository.dart';
import '../../../core/database/database.dart';
import 'dashboard_providers.dart';

void showEditBudgetDialog(BuildContext context, WidgetRef ref, DateTime selectedMonth) {
  showDialog(
    context: context,
    builder: (context) => _EditBudgetDialog(selectedMonth: selectedMonth),
  );
}

class _EditBudgetDialog extends ConsumerStatefulWidget {
  final DateTime selectedMonth;

  const _EditBudgetDialog({required this.selectedMonth});

  @override
  ConsumerState<_EditBudgetDialog> createState() => _EditBudgetDialogState();
}

class _EditBudgetDialogState extends ConsumerState<_EditBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<int, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double _calculateTotal(List<CategoryGroupWithStats> groups) {
    double total = 0.0;
    _controllers.forEach((id, controller) {
      // Check if this category ID actually exists in the current month's groups
      final exists = groups.any((g) => g.categories.any((c) => c.category.id == id));
      if (exists) {
        total += double.tryParse(controller.text) ?? 0.0;
      }
    });
    return total;
  }

  Future<void> _addCategoryGroup(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kelompok Baru'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nama Kelompok (misal: Investasi)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Tambah')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(budgetRepositoryProvider).addCategoryGroup(name);
    }
  }

  Future<void> _editCategoryGroup(BuildContext context, WidgetRef ref, CategoryGroup group) async {
    final controller = TextEditingController(text: group.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Nama Kelompok'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nama Kelompok'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != group.name) {
      await ref.read(budgetRepositoryProvider).updateCategoryGroup(group.id, name);
    }
  }

  Future<void> _deleteCategoryGroup(BuildContext context, WidgetRef ref, CategoryGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kelompok?'),
        content: Text('Apakah Anda yakin ingin menghapus kelompok "${group.name}"?\n\nPERINGATAN: Menghapus kelompok ini juga akan menghapus semua kategori dan data transaksi di dalamnya!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus Semuanya'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(budgetRepositoryProvider).deleteCategoryGroup(group.id);
    }
  }

  Future<void> _addCategory(BuildContext context, WidgetRef ref, int groupId) async {
    final nameController = TextEditingController();
    final budgetController = TextEditingController(text: '0');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Kategori Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Nama Kategori (misal: Liburan)'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: budgetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Target Anggaran (Rp)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'budget': double.tryParse(budgetController.text) ?? 0.0,
              });
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    if (result != null && result['name']!.isNotEmpty) {
      await ref.read(budgetRepositoryProvider).addCategory(
            groupId: groupId,
            name: result['name']!,
            targetBudget: result['budget']!,
          );
    }
  }

  Future<void> _editCategory(BuildContext context, WidgetRef ref, Category category) async {
    final nameController = TextEditingController(text: category.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Nama Kategori'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Nama Kategori'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, nameController.text.trim()), child: const Text('Simpan')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty && name != category.name) {
      await ref.read(budgetRepositoryProvider).updateCategory(category.id, name, category.targetBudget);
    }
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, Category category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "${category.name}"?\n\nPERINGATAN: Menghapus kategori ini juga akan menghapus semua riwayat transaksi terkait!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(budgetRepositoryProvider).deleteCategory(category.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(budgetGroupsWithStatsProvider(widget.selectedMonth));
    final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);

    return statsAsync.when(
      loading: () => const AlertDialog(
        content: SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      ),
      error: (err, stack) => AlertDialog(
        title: const Text('Error'),
        content: Text(err.toString()),
      ),
      data: (groups) {
        // Synchronize controllers for each category
        for (var group in groups) {
          for (var cat in group.categories) {
            if (!_controllers.containsKey(cat.category.id)) {
              _controllers[cat.category.id] = TextEditingController(
                text: cat.category.targetBudget.toInt().toString(),
              );
            }
          }
        }

        final totalNewBudget = _calculateTotal(groups);

        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Edit Anggaran Bulanan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.create_new_folder, size: 22, color: Colors.blue),
                tooltip: 'Tambah Kelompok',
                onPressed: () => _addCategoryGroup(context, ref),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Kelola kelompok dan sub-kategori, serta sesuaikan anggaran target di bawah ini:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (groups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Text(
                          'Belum ada kelompok anggaran. Ketuk ikon folder di atas untuk membuat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0, bottom: 6.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            group.group.name.toUpperCase(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 14),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          color: Colors.grey,
                                          onPressed: () => _editCategoryGroup(context, ref, group.group),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete, size: 14),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          color: Colors.redAccent,
                                          onPressed: () => _deleteCategoryGroup(context, ref, group.group),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  TextButton.icon(
                                    label: const Text('Kategori', style: TextStyle(fontSize: 10)),
                                    icon: const Icon(Icons.add, size: 12),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () => _addCategory(context, ref, group.group.id),
                                  ),
                                ],
                              ),
                            ),
                            ...group.categories.map((cat) {
                              final controller = _controllers[cat.category.id]!;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 12),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: Colors.grey,
                                      onPressed: () => _editCategory(context, ref, cat.category),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.delete, size: 12),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      color: Colors.redAccent.withOpacity(0.8),
                                      onPressed: () => _deleteCategory(context, ref, cat.category),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cat.category.name,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        controller: controller,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.end,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged: (_) {
                                          setState(() {});
                                        },
                                        validator: (val) {
                                          if (val == null || val.isEmpty) return 'Wajib';
                                          final num = double.tryParse(val);
                                          if (num == null || num < 0) return 'Invalid';
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
                        currencyFormatter.format(totalNewBudget),
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
                    // Check if it exists in active categories list to avoid saving deleted ones
                    final exists = groups.any((g) => g.categories.any((c) => c.category.id == categoryId));
                    if (exists) {
                      final newBudget = double.parse(entry.value.text);
                      await repository.updateCategoryBudget(categoryId, newBudget);
                    }
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
      },
    );
  }
}
