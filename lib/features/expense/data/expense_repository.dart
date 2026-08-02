import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(databaseProvider));
});

class ExpenseRepository {
  final AppDatabase _db;

  ExpenseRepository(this._db);

  Stream<List<Expense>> watchExpensesForMonth(DateTime month) {
    final startOfMonth = DateTime(month.year, month.month, 1);
    final startOfNextMonth = DateTime(month.year, month.month + 1, 1);

    return (_db.select(_db.expenses)
          ..where((t) => t.date.isBiggerOrEqualValue(startOfMonth) & t.date.isSmallerThanValue(startOfNextMonth))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  Future<int> addExpense({
    required int categoryId,
    required double amount,
    required DateTime date,
    String? notes,
    String? location,
  }) {
    return _db.into(_db.expenses).insert(
          ExpensesCompanion.insert(
            categoryId: categoryId,
            amount: amount,
            date: date,
            notes: Value(notes),
            location: Value(location),
          ),
        );
  }

  Future<void> deleteExpense(int id) {
    return (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<QuickPreset>> watchQuickPresets() {
    return _db.select(_db.quickPresets).watch();
  }

  Future<int> addQuickPreset({
    required int categoryId,
    required String name,
    required double amount,
  }) {
    return _db.into(_db.quickPresets).insert(
          QuickPresetsCompanion.insert(
            categoryId: categoryId,
            name: name,
            amount: amount,
          ),
        );
  }

  Future<void> deleteQuickPreset(int id) {
    return (_db.delete(_db.quickPresets)..where((t) => t.id.equals(id))).go();
  }
}
