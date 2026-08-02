import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../budget_group/data/budget_repository.dart';
import '../../budget_group/domain/budget_models.dart';
import '../../expense/data/expense_repository.dart';

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final categoryGroupsProvider = StreamProvider<List<CategoryGroup>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchCategoryGroups();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(budgetRepositoryProvider).watchCategories();
});

final expensesForMonthProvider = StreamProvider.family<List<Expense>, DateTime>((ref, month) {
  return ref.watch(expenseRepositoryProvider).watchExpensesForMonth(month);
});

final transfersForMonthProvider = StreamProvider.family<List<BudgetTransfer>, DateTime>((ref, month) {
  return ref.watch(budgetRepositoryProvider).watchBudgetTransfersForMonth(month);
});

final budgetGroupsWithStatsProvider = Provider.family<AsyncValue<List<CategoryGroupWithStats>>, DateTime>((ref, month) {
  final groupsAsync = ref.watch(categoryGroupsProvider);
  final categoriesAsync = ref.watch(categoriesProvider);
  final expensesAsync = ref.watch(expensesForMonthProvider(month));
  final transfersAsync = ref.watch(transfersForMonthProvider(month));

  if (groupsAsync.isLoading || categoriesAsync.isLoading || expensesAsync.isLoading || transfersAsync.isLoading) {
    return const AsyncValue.loading();
  }
  if (groupsAsync.hasError) return AsyncValue.error(groupsAsync.error!, groupsAsync.stackTrace!);
  if (categoriesAsync.hasError) return AsyncValue.error(categoriesAsync.error!, categoriesAsync.stackTrace!);
  if (expensesAsync.hasError) return AsyncValue.error(expensesAsync.error!, expensesAsync.stackTrace!);
  if (transfersAsync.hasError) return AsyncValue.error(transfersAsync.error!, transfersAsync.stackTrace!);

  final groups = groupsAsync.value ?? [];
  final categories = categoriesAsync.value ?? [];
  final expenses = expensesAsync.value ?? [];
  final transfers = transfersAsync.value ?? [];

  // Group spent by categoryId
  final Map<int, double> spentByCategory = {};
  for (var exp in expenses) {
    spentByCategory[exp.categoryId] = (spentByCategory[exp.categoryId] ?? 0) + exp.amount;
  }

  // Calculate net budget adjustments from transfers
  final Map<int, double> adjustmentByCategory = {};
  for (var transfer in transfers) {
    adjustmentByCategory[transfer.sourceCategoryId] = 
        (adjustmentByCategory[transfer.sourceCategoryId] ?? 0) - transfer.amount;
    adjustmentByCategory[transfer.targetCategoryId] = 
        (adjustmentByCategory[transfer.targetCategoryId] ?? 0) + transfer.amount;
  }

  final List<CategoryGroupWithStats> result = [];

  for (var group in groups) {
    final List<CategoryWithStats> catsInGroup = [];
    double groupOriginalBudget = 0;
    double groupNetBudget = 0;
    double groupSpent = 0;

    final filteredCats = categories.where((c) => c.groupId == group.id).toList();

    for (var cat in filteredCats) {
      final original = cat.targetBudget;
      final adj = adjustmentByCategory[cat.id] ?? 0;
      final net = original + adj;
      final spent = spentByCategory[cat.id] ?? 0;
      final remaining = net - spent;

      final ratio = net > 0 ? (spent / net) : 0.0;
      // Status logic matching spreadsheet
      String status = 'AMAN';
      if (net <= 0) {
        status = 'HABIS';
      } else {
        if (ratio >= 1.0) {
          status = 'HABIS';
        } else if (ratio >= 0.85) {
          status = 'GUNAKAN DENGAN BIJAK';
        } else {
          status = 'AMAN';
        }
      }

      // Hardcoded spreadsheet conditions matching the user's specific items
      if (cat.id == 1 || cat.id == 2 || cat.id == 3) {
        // Bills: Cicilan, Wifi, Kost
        if (spent >= original) {
          status = 'SELESAI';
        } else {
          status = 'BAYAR SEKARANG';
        }
      } else if (cat.id == 4 || cat.id == 5) {
        // Family transfers
        if (spent >= original) {
          status = 'SELESAI';
        } else {
          status = 'BAYAR SEKARANG';
        }
      } else if (cat.id == 7) {
        // Transport (TJ)
        if (spent > 0) {
          status = 'UDAH TOP UP';
        }
      } else if (cat.id == 10 || cat.id == 11) {
        // Dana Darurat & Tabungan
        if (spent >= original) {
          status = 'SELESAI';
        } else {
          status = 'PINDAHKAN SEKARANG';
        }
      } else if (cat.id == 13) {
        // Nongkrong & Jajan
        if (ratio < 1.0 && ratio > 0.0) {
          status = 'GAS NONGKI & BELI PAKAIAN';
        }
      }

      catsInGroup.add(CategoryWithStats(
        category: cat,
        originalBudget: original,
        netBudget: net,
        spent: spent,
        remaining: remaining,
        status: status,
      ));

      groupOriginalBudget += original;
      groupNetBudget += net;
      groupSpent += spent;
    }

    result.add(CategoryGroupWithStats(
      group: group,
      categories: catsInGroup,
      totalOriginalBudget: groupOriginalBudget,
      totalNetBudget: groupNetBudget,
      totalSpent: groupSpent,
      totalRemaining: groupNetBudget - groupSpent,
    ));
  }

  return AsyncValue.data(result);
});

final dailyAllowanceProvider = Provider.family<double, DateTime>((ref, date) {
  final statsAsync = ref.watch(budgetGroupsWithStatsProvider(date));
  return statsAsync.maybeWhen(
    data: (groups) {
      CategoryWithStats? makanHarian;
      for (var group in groups) {
        for (var cat in group.categories) {
          if (cat.category.id == 6) {
            makanHarian = cat;
            break;
          }
        }
      }
      
      if (makanHarian == null) return 0.0;
      
      final lastDayOfMonth = DateTime(date.year, date.month + 1, 0).day;
      final currentDay = date.day;
      final remainingDays = lastDayOfMonth - currentDay + 1;
      
      if (remainingDays <= 0) return 0.0;
      final allowance = makanHarian.remaining / remainingDays;
      return allowance < 0 ? 0.0 : allowance;
    },
    orElse: () => 0.0,
  );
});

final quickPresetsProvider = StreamProvider<List<QuickPreset>>((ref) {
  return ref.watch(expenseRepositoryProvider).watchQuickPresets();
});
