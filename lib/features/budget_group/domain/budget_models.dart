import '../../../core/database/database.dart';

class CategoryWithStats {
  final Category category;
  final double originalBudget;
  final double netBudget;
  final double spent;
  final double remaining;
  final String status; // AMAN, WARNING, HABIS, SELESAI, GUNAKAN DENGAN BIJAK

  CategoryWithStats({
    required this.category,
    required this.originalBudget,
    required this.netBudget,
    required this.spent,
    required this.remaining,
    required this.status,
  });
}

class CategoryGroupWithStats {
  final CategoryGroup group;
  final List<CategoryWithStats> categories;
  final double totalOriginalBudget;
  final double totalNetBudget;
  final double totalSpent;
  final double totalRemaining;

  CategoryGroupWithStats({
    required this.group,
    required this.categories,
    required this.totalOriginalBudget,
    required this.totalNetBudget,
    required this.totalSpent,
    required this.totalRemaining,
  });
}
