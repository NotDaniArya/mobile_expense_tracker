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

  Future<void> deleteBudgetTransfersForExpense(int expenseId) {
    return (_db.delete(_db.budgetTransfers)..where((t) => t.reason.like('%[ExpID: $expenseId]%'))).go();
  }

  Future<int> addCategoryGroup(String name) {
    return _db.into(_db.categoryGroups).insert(
          CategoryGroupsCompanion.insert(name: name),
        );
  }

  Future<void> updateCategoryGroup(int id, String name) {
    return (_db.update(_db.categoryGroups)..where((t) => t.id.equals(id)))
        .write(CategoryGroupsCompanion(name: Value(name)));
  }

  Future<void> deleteCategoryGroup(int id) async {
    final cats = await (_db.select(_db.categories)..where((t) => t.groupId.equals(id))).get();
    for (var cat in cats) {
      await deleteCategory(cat.id);
    }
    await (_db.delete(_db.categoryGroups)..where((t) => t.id.equals(id))).go();
  }

  Future<int> addCategory({
    required int groupId,
    required String name,
    required double targetBudget,
  }) {
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            groupId: groupId,
            name: name,
            targetBudget: targetBudget,
          ),
        );
  }

  Future<void> updateCategory(int id, String name, double targetBudget) {
    return (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        targetBudget: Value(targetBudget),
      ),
    );
  }

  Future<void> deleteCategory(int id) async {
    await (_db.delete(_db.budgetTransfers)
          ..where((t) => t.sourceCategoryId.equals(id) | t.targetCategoryId.equals(id)))
        .go();
    await (_db.delete(_db.expenses)..where((t) => t.categoryId.equals(id))).go();
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }
}
