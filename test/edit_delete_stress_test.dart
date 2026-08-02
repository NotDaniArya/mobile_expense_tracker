import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/database.dart';
import 'package:expense_tracker/features/expense/data/expense_repository.dart';
import 'package:expense_tracker/features/budget_group/data/budget_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ExpenseRepository expenseRepo;
  late BudgetRepository budgetRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    expenseRepo = ExpenseRepository(db);
    budgetRepo = BudgetRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Edit & Delete Extreme Data Stress Tests', () {
    test('1. Extreme Vector: Edit Amount Discrepancy in Remaining Calculation', () async {
      final now = DateTime.now();
      // Add initial expense 10.000 on category 6 (Makan Harian)
      final id = await expenseRepo.addExpense(
        categoryId: 6,
        amount: 10000,
        date: now,
        notes: 'Initial Makan',
      );

      // Edit amount to 50.000
      await expenseRepo.updateExpense(
        id: id,
        categoryId: 6,
        amount: 50000,
        date: now,
        notes: 'Updated Makan',
      );

      final expenses = await expenseRepo.watchExpensesForMonth(now).first;
      expect(expenses.first.amount, 50000);
      
      // Demonstrates: if remaining budget calculation doesn't offset the original 10.000,
      // reallocation math will be off by 10.000!
    });

    test('2. Extreme Vector: Delete Expense Clean Up Associated Transfer Log', () async {
      final now = DateTime.now();
      final expId = await expenseRepo.addExpense(
        categoryId: 13, // Nongkrong
        amount: 60000,
        date: now,
        notes: 'Nongkrong Overbudget',
      );

      // Log associated reallocation transfer with ExpID
      await budgetRepo.addBudgetTransfer(
        sourceCategoryId: 10,
        targetCategoryId: 13,
        amount: 50000,
        date: now,
        reason: 'Cover Overbudget [ExpID: $expId]: Nongkrong Overbudget',
      );

      // Delete the expense
      await expenseRepo.deleteExpense(expId);

      final transfers = await budgetRepo.watchBudgetTransfersForMonth(now).first;
      
      // Confirms fix: Associated transfer log is now cleaned up automatically!
      expect(transfers.isEmpty, true);
    });
  });
}
