import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../budget_group/data/budget_repository.dart';
import '../../budget_group/domain/budget_models.dart';
import '../data/expense_repository.dart';
import '../../dashboard/presentation/dashboard_providers.dart';
import '../../../core/database/database.dart';

class AddExpenseDialog extends ConsumerStatefulWidget {
  final double? initialAmount;
  final String? initialNotes;
  final int? initialCategoryId;
  final DateTime? initialDate;
  final Expense? expenseToEdit;

  const AddExpenseDialog({
    super.key,
    this.initialAmount,
    this.initialNotes,
    this.initialCategoryId,
    this.initialDate,
    this.expenseToEdit,
  });

  @override
  ConsumerState<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  late final TextEditingController _locationController;

  DateTime _selectedDate = DateTime.now();
  CategoryWithStats? _selectedCategory;
  CategoryWithStats? _sourceCategory;

  bool _needsReallocation = false;
  double _reallocationAmount = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      _amountController = TextEditingController(
        text: widget.expenseToEdit!.amount.toInt().toString(),
      );
      _notesController = TextEditingController(text: widget.expenseToEdit!.notes ?? '');
      _locationController = TextEditingController(text: widget.expenseToEdit!.location ?? '');
      _selectedDate = widget.expenseToEdit!.date;
    } else {
      _amountController = TextEditingController(
        text: widget.initialAmount != null ? widget.initialAmount!.toInt().toString() : '',
      );
      _notesController = TextEditingController(text: widget.initialNotes ?? '');
      _locationController = TextEditingController();
      if (widget.initialDate != null) {
        _selectedDate = widget.initialDate!;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _checkOverbudget(double amount, List<CategoryGroupWithStats> groups) {
    if (_selectedCategory == null) return;
    
    // Find latest category stats from groups
    CategoryWithStats? currentStat;
    for (var group in groups) {
      for (var cat in group.categories) {
        if (cat.category.id == _selectedCategory!.category.id) {
          currentStat = cat;
          break;
        }
      }
    }

    final stat = currentStat;
    if (stat == null) return;

    setState(() {
      _selectedCategory = stat;
      double effectiveRemaining = stat.remaining;
      if (widget.expenseToEdit != null && widget.expenseToEdit!.categoryId == stat.category.id) {
        effectiveRemaining += widget.expenseToEdit!.amount;
      }

      if (amount > effectiveRemaining) {
        _needsReallocation = true;
        _reallocationAmount = amount - effectiveRemaining;
      } else {
        _needsReallocation = false;
        _reallocationAmount = 0.0;
        _sourceCategory = null;
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).cardTheme.color ?? Colors.blueGrey,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);
    final statsAsync = ref.watch(budgetGroupsWithStatsProvider(_selectedDate));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
          data: (groups) {
            // Synchronize _selectedCategory and _sourceCategory references with the fresh groups data
            if (_selectedCategory != null) {
              CategoryWithStats? found;
              for (var group in groups) {
                for (var cat in group.categories) {
                  if (cat.category.id == _selectedCategory!.category.id) {
                    found = cat;
                    break;
                  }
                }
                if (found != null) break;
              }
              _selectedCategory = found;
            }

            if (_sourceCategory != null) {
              CategoryWithStats? found;
              for (var group in groups) {
                for (var cat in group.categories) {
                  if (cat.category.id == _sourceCategory!.category.id) {
                    found = cat;
                    break;
                  }
                }
                if (found != null) break;
              }
              _sourceCategory = found;
            }

            // Pre-select category if matching initialCategoryId or editing
            if (_selectedCategory == null) {
              final targetCatId = widget.expenseToEdit?.categoryId ?? widget.initialCategoryId;
              if (targetCatId != null) {
                for (var group in groups) {
                  for (var cat in group.categories) {
                    if (cat.category.id == targetCatId) {
                      _selectedCategory = cat;
                      final amt = double.tryParse(_amountController.text) ?? 0.0;
                      if (amt > 0) {
                        _checkOverbudget(amt, groups);
                      }
                      break;
                    }
                  }
                }
              }
            }

            // Flat list of categories with positive remaining budget to pick as source
            // Filter to make sure source category has enough budget to cover reallocation
            final sourceCategories = groups
                .expand((g) => g.categories)
                .where((c) =>
                    c.category.id != _selectedCategory?.category.id &&
                    c.remaining >= _reallocationAmount)
                .toList();

            return SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.expenseToEdit != null ? 'Ubah Pengeluaran' : 'Catat Pengeluaran',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '0',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                      onChanged: (val) {
                        final amt = double.tryParse(val) ?? 0.0;
                        _checkOverbudget(amt, groups);
                      },
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Masukkan jumlah uang';
                        final amount = double.tryParse(val);
                        if (amount == null) return 'Format tidak valid';
                        if (amount <= 0) return 'Nominal harus lebih besar dari 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // KATEGORI DROPDOWN
                    DropdownButtonFormField<CategoryWithStats>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Kategori',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: groups.expand((group) {
                        return [
                          DropdownMenuItem<CategoryWithStats>(
                            enabled: false,
                            child: Text(
                              group.group.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                          ...group.categories.map((cat) {
                            return DropdownMenuItem<CategoryWithStats>(
                              value: cat,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  '${cat.category.name} (${currencyFormatter.format(cat.remaining)})',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            );
                          }),
                        ];
                      }).toList(),
                      onChanged: (cat) {
                        setState(() {
                          _selectedCategory = cat;
                          final amt = double.tryParse(_amountController.text) ?? 0.0;
                          _checkOverbudget(amt, groups);
                        });
                      },
                      validator: (val) => val == null ? 'Pilih kategori' : null,
                    ),
                    const SizedBox(height: 16),
                    // INPUT REALLOCATION (COVER BUDGET) BILA OVERBUDGET
                    if (_needsReallocation) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.error.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.error.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Anggaran kurang ${currencyFormatter.format(_reallocationAmount)}!',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sourceCategories.isEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Peringatan: Tidak ada kategori lain yang memiliki sisa budget cukup untuk menutupi kekurangan ini.',
                                style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ] else ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Pilih kategori budget sumber untuk menutupi kekurangan agar tidak minus:',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<CategoryWithStats>(
                                value: _sourceCategory,
                                decoration: InputDecoration(
                                  labelText: 'Kategori Sumber',
                                  filled: true,
                                  fillColor: Theme.of(context).colorScheme.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: sourceCategories.map((cat) {
                                  return DropdownMenuItem<CategoryWithStats>(
                                    value: cat,
                                    child: Text(
                                      '${cat.category.name} (${currencyFormatter.format(cat.remaining)})',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (cat) {
                                  setState(() {
                                    _sourceCategory = cat;
                                  });
                                },
                                validator: (val) =>
                                    _needsReallocation && val == null ? 'Pilih kategori sumber' : null,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // TANGGAL SELECTOR
                    InkWell(
                      onTap: () => _selectDate(context),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Tanggal Transaksi', style: TextStyle(fontSize: 15)),
                            Row(
                              children: [
                                Text(
                                  DateFormat('dd MMMM yyyy').format(_selectedDate),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.calendar_month, size: 20),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // CATATAN (NOTES)
                    TextFormField(
                      controller: _notesController,
                      maxLength: 100,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Catatan / Deskripsi',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // LOKASI (OPTIONAL)
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Lokasi (Opsional)',
                        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final amount = double.tryParse(_amountController.text) ?? 0.0;
                          final notes = _notesController.text;
                          final location = _locationController.text;

                          int expenseId;
                          if (widget.expenseToEdit != null) {
                            expenseId = widget.expenseToEdit!.id;
                            // Clean up old reallocation budget transfer for this expense first
                            await ref.read(budgetRepositoryProvider).deleteBudgetTransfersForExpense(expenseId);

                            await ref.read(expenseRepositoryProvider).updateExpense(
                              id: expenseId,
                              categoryId: _selectedCategory!.category.id,
                              amount: amount,
                              date: _selectedDate,
                              notes: notes.isNotEmpty ? notes : null,
                              location: location.isNotEmpty ? location : null,
                            );
                          } else {
                            expenseId = await ref.read(expenseRepositoryProvider).addExpense(
                              categoryId: _selectedCategory!.category.id,
                              amount: amount,
                              date: _selectedDate,
                              notes: notes.isNotEmpty ? notes : null,
                              location: location.isNotEmpty ? location : null,
                            );
                          }

                          // Execute Reallocation if required
                          if (_needsReallocation && _sourceCategory != null) {
                            await ref.read(budgetRepositoryProvider).addBudgetTransfer(
                              sourceCategoryId: _sourceCategory!.category.id,
                              targetCategoryId: _selectedCategory!.category.id,
                              amount: _reallocationAmount,
                              date: _selectedDate,
                              reason: 'Cover Overbudget [ExpID: $expenseId]: $notes',
                            );
                          }

                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      child: Text(
                        widget.expenseToEdit != null ? 'Simpan Perubahan' : 'Simpan Pengeluaran',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
