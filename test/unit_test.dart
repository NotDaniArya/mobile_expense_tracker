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

  group('Unit & Edge Case Tests - Expense Tracker', () {
    test('1. Valid Expense Addition Test', () async {
      final now = DateTime.now();
      await expenseRepo.addExpense(
        categoryId: 6, // Makan Harian
        amount: 15000,
        date: now,
        notes: 'Makan siang warteg',
      );

      final expenses = await expenseRepo.watchExpensesForMonth(now).first;
      expect(expenses.length, 1);
      expect(expenses.first.amount, 15000);
      expect(expenses.first.notes, 'Makan siang warteg');
    });

    test('2. Edge Case: Negative Amount Input Behavior', () async {
      final now = DateTime.now();
      // Inputting negative amount
      await expenseRepo.addExpense(
        categoryId: 6,
        amount: -50000,
        date: now,
        notes: 'Negative test',
      );

      final expenses = await expenseRepo.watchExpensesForMonth(now).first;
      final negativeExp = expenses.firstWhere((e) => e.notes == 'Negative test');
      
      // Demonstrates weakness: Database accepts negative numbers without constraint
      expect(negativeExp.amount, -50000);
    });

    test('3. Edge Case: Overbudget Transfer Reallocation Test', () async {
      final now = DateTime.now();
      await budgetRepo.addBudgetTransfer(
        sourceCategoryId: 10,
        targetCategoryId: 13,
        amount: 50000,
        date: now,
        reason: 'Cover overbudget nongkrong',
      );

      final transfers = await budgetRepo.watchBudgetTransfersForMonth(now).first;
      expect(transfers.length, 1);
      expect(transfers.first.amount, 50000);
      expect(transfers.first.sourceCategoryId, 10);
      expect(transfers.first.targetCategoryId, 13);
    });

    test('4. Edge Case: Sub-second Millisecond Boundary Query', () async {
      final lastMs = DateTime(2026, 12, 31, 23, 59, 59, 900);
      await expenseRepo.addExpense(
        categoryId: 6,
        amount: 25000,
        date: lastMs,
        notes: 'End of year late transaction',
      );

      final decDate = DateTime(2026, 12, 1);
      final expenses = await expenseRepo.watchExpensesForMonth(decDate).first;
      
      // Confirms fix: query now includes boundary sub-second millisecond transactions!
      final found = expenses.where((e) => e.notes == 'End of year late transaction').isNotEmpty;
      expect(found, true);
    });
  });
}
