import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dashboard_providers.dart';
import '../../expense/data/expense_repository.dart';
import '../../expense/presentation/add_expense_dialog.dart';
import '../../../core/database/database.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final expensesAsync = ref.watch(expensesForMonthProvider(selectedMonth));
    final categoriesAsync = ref.watch(categoriesProvider);

    final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);
    final monthHeaderFormatter = DateFormat('MMMM yyyy');

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // HEADER MONTH SELECTOR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    onPressed: () {
                      ref.read(selectedMonthProvider.notifier).state = 
                          DateTime(selectedMonth.year, selectedMonth.month - 1);
                    },
                  ),
                  Text(
                    monthHeaderFormatter.format(selectedMonth),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 20),
                    onPressed: () {
                      ref.read(selectedMonthProvider.notifier).state = 
                          DateTime(selectedMonth.year, selectedMonth.month + 1);
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // TRANSACTION LIST (REDESIGNED CARD HIERARCHY)
            Expanded(
              child: expensesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const Center(
                      child: Text(
                        'Belum ada riwayat pengeluaran bulan ini.',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    );
                  }

                  return categoriesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                    data: (categories) {
                      return ListView.builder(
                        padding: const EdgeInsets.only(top: 10, bottom: 80),
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final exp = expenses[index];
                          final formattedDate = DateFormat('dd MMMM yyyy').format(exp.date);

                          // Find category name by ID
                          final category = categories.firstWhere(
                            (c) => c.id == exp.categoryId,
                            orElse: () => Category(id: 0, groupId: 0, name: 'Umum', targetBudget: 0),
                          );

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              // Baris 1: Nama Kategori (Title Utama)
                              title: Text(
                                category.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              // Baris 2 & 3: Catatan dan Tanggal (Subtitle)
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Catatan/Deskripsi
                                    Text(
                                      exp.notes ?? 'Pengeluaran Tanpa Catatan',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Tanggal Transaksi
                                    Text(
                                      '$formattedDate • ${exp.location ?? "Tanpa Lokasi"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Sisi Kanan: Nominal & PopupMenu
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    currencyFormatter.format(exp.amount),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 20),
                                    onSelected: (action) async {
                                      if (action == 'edit') {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AddExpenseDialog(expenseToEdit: exp),
                                        );
                                      } else if (action == 'delete') {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Hapus Pengeluaran?'),
                                            content: const Text('Apakah Anda yakin ingin menghapus catatan pengeluaran ini?'),
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
                                          await ref.read(expenseRepositoryProvider).deleteExpense(exp.id);
                                        }
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit, size: 18),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete, size: 18, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Hapus', style: TextStyle(color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
