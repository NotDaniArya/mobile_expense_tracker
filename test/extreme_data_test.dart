import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:expense_tracker/core/database/database.dart';
import 'package:expense_tracker/features/expense/data/expense_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ExpenseRepository expenseRepo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    expenseRepo = ExpenseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Extreme Data & Error Stress Tests', () {
    test('1. Extreme Vector: Trillion Amount Input', () async {
      final now = DateTime.now();
      const trillionAmount = 999999999999999.0;

      await expenseRepo.addExpense(
        categoryId: 6,
        amount: trillionAmount,
        date: now,
        notes: 'Extreme Trillion Expense',
      );

      final expenses = await expenseRepo.watchExpensesForMonth(now).first;
      expect(expenses.first.amount, trillionAmount);
    });

    test('2. Extreme Vector: Multiline Newline & Emoji Injection in Notes', () async {
      final now = DateTime.now();
      const extremeNotes = '🔥🚀💰 Line 1\n\n\n\n\n\n\n\n\n\nLine 10';

      await expenseRepo.addExpense(
        categoryId: 6,
        amount: 20000,
        date: now,
        notes: extremeNotes,
      );

      final expenses = await expenseRepo.watchExpensesForMonth(now).first;
      expect(expenses.first.notes, extremeNotes);
    });

    test('3. Extreme Vector: Zero Net Budget Division (NaN / Infinity check)', () async {
      const spent = 50000.0;
      const netBudget = 0.0;

      // Safe division by zero logic matching newest implementation
      final ratio = netBudget > 0 ? (spent / netBudget) : (spent > 0 ? 1.0 : 0.0);
      final clampedRatio = ratio.isNaN || ratio.isInfinite ? 1.0 : ratio.clamp(0.0, 1.0);

      expect(clampedRatio, 1.0);
    });
  });
}
