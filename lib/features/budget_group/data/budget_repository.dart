import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
});

class BudgetRepository {
  final AppDatabase _db;

  BudgetRepository(this._db);

  Stream<List<CategoryGroup>> watchCategoryGroups() {
    return _db.select(_db.categoryGroups).watch();
  }

  Stream<List<Category>> watchCategories() {
    return _db.select(_db.categories).watch();
  }

  Stream<List<BudgetTransfer>> watchBudgetTransfersForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final startOfNextMonth = DateTime(month.year, month.month + 1, 1);

    return (_db.select(_db.budgetTransfers)
          ..where((t) => t.date.isBiggerOrEqualValue(startOfMonth) & t.date.isSmallerThanValue(startOfNextMonth)))
        .watch();
  }

  Future<int> addBudgetTransfer({
    required int sourceCategoryId,
    required int targetCategoryId,
    required double amount,
    required DateTime date,
    String? reason,
  }) {
    return _db.into(_db.budgetTransfers).insert(
          BudgetTransfersCompanion.insert(
            sourceCategoryId: sourceCategoryId,
            targetCategoryId: targetCategoryId,
            amount: amount,
            date: date,
            reason: Value(reason),
          ),
        );
  }

  Future<void> updateCategoryBudget(int categoryId, double newBudget) {
    return (_db.update(_db.categories)
          ..where((t) => t.id.equals(categoryId)))
        .write(CategoriesCompanion(targetBudget: Value(newBudget)));
  }
}
