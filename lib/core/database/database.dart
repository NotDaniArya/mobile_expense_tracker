import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class CategoryGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().references(CategoryGroups, #id)();
  TextColumn get name => text()();
  RealColumn get targetBudget => real()();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get notes => text().nullable()();
  TextColumn get location => text().nullable()();
}

class BudgetTransfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sourceCategoryId => integer().references(Categories, #id)();
  IntColumn get targetCategoryId => integer().references(Categories, #id)();
  RealColumn get amount => real()();
  DateTimeColumn get date => dateTime()();
  TextColumn get reason => text().nullable()();
}

class QuickPresets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(Categories, #id)();
  TextColumn get name => text()();
  RealColumn get amount => real()();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'expense_tracker.db'));
    return NativeDatabase.createInBackground(file);
  });
}

@DriftDatabase(tables: [CategoryGroups, Categories, Expenses, BudgetTransfers, QuickPresets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          
          await batch((b) {
            b.insertAll(categoryGroups, [
              CategoryGroupsCompanion.insert(id: const Value(1), name: 'KEWAJIBAN TETAP'),
              CategoryGroupsCompanion.insert(id: const Value(2), name: 'BIAYA HIDUP'),
              CategoryGroupsCompanion.insert(id: const Value(3), name: 'TERSERAH (SAVINGS & WANTS)'),
            ]);

            b.insertAll(categories, [
              // Kewajiban Tetap
              CategoriesCompanion.insert(id: const Value(1), groupId: 1, name: 'Cicilan Hutang', targetBudget: 1070000),
              CategoriesCompanion.insert(id: const Value(2), groupId: 1, name: 'Wifi', targetBudget: 261000),
              CategoriesCompanion.insert(id: const Value(3), groupId: 1, name: 'Kost', targetBudget: 900000),
              CategoriesCompanion.insert(id: const Value(4), groupId: 1, name: 'Nisa', targetBudget: 200000),
              CategoriesCompanion.insert(id: const Value(5), groupId: 1, name: 'Mama', targetBudget: 350000),
              // Biaya Hidup
              CategoriesCompanion.insert(id: const Value(6), groupId: 2, name: 'Makan Harian', targetBudget: 1320000),
              CategoriesCompanion.insert(id: const Value(7), groupId: 2, name: 'Transport (TJ)', targetBudget: 160000),
              CategoriesCompanion.insert(id: const Value(8), groupId: 2, name: 'Skincare', targetBudget: 300000),
              CategoriesCompanion.insert(id: const Value(9), groupId: 2, name: 'Data 1 bulan', targetBudget: 50000),
              // Terserah
              CategoriesCompanion.insert(id: const Value(10), groupId: 3, name: 'Dana Darurat', targetBudget: 220000),
              CategoriesCompanion.insert(id: const Value(11), groupId: 3, name: 'Tabungan', targetBudget: 1350000),
              CategoriesCompanion.insert(id: const Value(12), groupId: 3, name: 'Belanja kebutuhan & pakaian', targetBudget: 550000),
              CategoriesCompanion.insert(id: const Value(13), groupId: 3, name: 'Nongkrong & Jajan', targetBudget: 250000),
            ]);

            b.insertAll(quickPresets, [
              QuickPresetsCompanion.insert(categoryId: 6, name: 'Sarapan 10k', amount: 10000),
              QuickPresetsCompanion.insert(categoryId: 6, name: 'Makan Siang 15k', amount: 15000),
              QuickPresetsCompanion.insert(categoryId: 6, name: 'Makan Malam 20k', amount: 20000),
              QuickPresetsCompanion.insert(categoryId: 7, name: 'Topup TJ 50k', amount: 50000),
            ]);
          });
        },
      );
}
