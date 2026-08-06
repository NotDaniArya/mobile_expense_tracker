import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database.dart';
import '../../expense/data/expense_repository.dart';
import 'dashboard_providers.dart';

/// Dialog to manage all presets (shows a list of presets with edit/delete options)
void showManagePresetsDialog(BuildContext context, WidgetRef ref, List<QuickPreset> presets) {
  showDialog(
    context: context,
    builder: (context) => _ManagePresetsDialog(presets: presets),
  );
}

/// Dialog to add or edit a specific preset
void showAddEditPresetDialog(BuildContext context, {QuickPreset? presetToEdit}) {
  showDialog(
    context: context,
    builder: (context) => _AddEditPresetDialog(presetToEdit: presetToEdit),
  );
}

class _ManagePresetsDialog extends ConsumerWidget {
  final List<QuickPreset> presets;

  const _ManagePresetsDialog({required this.presets});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);

    return AlertDialog(
      title: const Text('Kelola Pencatatan Cepat'),
      content: SizedBox(
        width: double.maxFinite,
        child: categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error: $err'),
          data: (categories) {
            if (presets.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    'Belum ada preset pencatatan cepat.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              itemCount: presets.length,
              itemBuilder: (context, index) {
                final preset = presets[index];
                final category = categories.firstWhere(
                  (c) => c.id == preset.categoryId,
                  orElse: () => Category(id: 0, groupId: 0, name: 'Umum', targetBudget: 0),
                );

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(preset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${category.name} • ${currencyFormatter.format(preset.amount)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.pop(context); // Close manage dialog
                          showAddEditPresetDialog(context, presetToEdit: preset);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Hapus Preset?'),
                              content: Text('Apakah Anda yakin ingin menghapus preset "${preset.name}"?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Batal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Hapus'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            await ref.read(expenseRepositoryProvider).deleteQuickPreset(preset.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Preset "${preset.name}" berhasil dihapus'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context); // Close manage dialog
            showAddEditPresetDialog(context);
          },
          icon: const Icon(Icons.add),
          label: const Text('Tambah Preset'),
        ),
      ],
    );
  }
}

class _AddEditPresetDialog extends ConsumerStatefulWidget {
  final QuickPreset? presetToEdit;

  const _AddEditPresetDialog({this.presetToEdit});

  @override
  ConsumerState<_AddEditPresetDialog> createState() => _AddEditPresetDialogState();
}

class _AddEditPresetDialogState extends ConsumerState<_AddEditPresetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  Category? _selectedCategory;
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.presetToEdit?.name ?? '');
    _amountController = TextEditingController(
      text: widget.presetToEdit?.amount != null ? widget.presetToEdit!.amount.toInt().toString() : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: Text(widget.presetToEdit != null ? 'Ubah Preset Cepat' : 'Tambah Preset Cepat'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Preset',
                  hintText: 'misal: Kopi Pagi, Parkir Mall',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Masukkan nama preset';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nominal (Rp)',
                  hintText: 'misal: 15000',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Masukkan nominal uang';
                  final amount = double.tryParse(val);
                  if (amount == null || amount <= 0) return 'Nominal harus lebih besar dari 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
                data: (categories) {
                  if (_isInit && widget.presetToEdit != null) {
                    _selectedCategory = categories.firstWhere(
                      (c) => c.id == widget.presetToEdit!.categoryId,
                      orElse: () => categories.first,
                    );
                    _isInit = false;
                  } else if (_selectedCategory == null && categories.isNotEmpty) {
                    _selectedCategory = categories.first;
                  }

                  return DropdownButtonFormField<Category>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: categories.map((cat) {
                      return DropdownMenuItem<Category>(
                        value: cat,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (cat) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                    validator: (val) => val == null ? 'Pilih kategori' : null,
                  );
                },
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
            if (_formKey.currentState!.validate() && _selectedCategory != null) {
              final name = _nameController.text.trim();
              final amount = double.parse(_amountController.text);
              final categoryId = _selectedCategory!.id;

              if (widget.presetToEdit != null) {
                await ref.read(expenseRepositoryProvider).updateQuickPreset(
                      id: widget.presetToEdit!.id,
                      categoryId: categoryId,
                      name: name,
                      amount: amount,
                    );
              } else {
                await ref.read(expenseRepositoryProvider).addQuickPreset(
                      categoryId: categoryId,
                      name: name,
                      amount: amount,
                    );
              }

              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Preset "$name" berhasil disimpan'),
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
