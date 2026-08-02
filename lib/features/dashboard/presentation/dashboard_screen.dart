import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dashboard_providers.dart';
import '../../expense/presentation/add_expense_dialog.dart';
import '../../expense/data/expense_repository.dart';
import '../../receipt_scan/presentation/scanner_screen.dart';
import '../../ai_advisor/presentation/ai_advisor_screen.dart';
import '../../../core/database/database.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(selectedMonthProvider);
    final statsAsync = ref.watch(budgetGroupsWithStatsProvider(selectedMonth));
    final dailyAllowance = ref.watch(dailyAllowanceProvider(DateTime.now()));
    final presetsAsync = ref.watch(quickPresetsProvider);
    final expensesAsync = ref.watch(expensesForMonthProvider(selectedMonth));

    final currencyFormatter = NumberFormat.currency(locale: 'id', symbol: 'Rp', decimalDigits: 0);
    final monthHeaderFormatter = DateFormat('MMMM yyyy');

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER MONTH SELECTOR
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

              // MAIN BALANCE STATS CARD
              statsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (err, stack) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Error: $err'),
                ),
                data: (groups) {
                  final totalBudget = groups.fold<double>(0, (sum, g) => sum + g.totalNetBudget);
                  final totalSpent = groups.fold<double>(0, (sum, g) => sum + g.totalSpent);
                  final totalRemaining = totalBudget - totalSpent;
                  final ratio = totalBudget > 0 ? (totalSpent / totalBudget) : (totalSpent > 0 ? 1.0 : 0.0);
                  final spentPercent = ratio.isNaN || ratio.isInfinite ? 1.0 : ratio.clamp(0.0, 1.0);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'TOTAL ANGGARAN',
                          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            currencyFormatter.format(totalBudget),
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Terpakai', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      currencyFormatter.format(totalSpent),
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Sisa Budget', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      currencyFormatter.format(totalRemaining),
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: spentPercent.clamp(0.0, 1.0),
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // DAILY ALLOWANCE CARD
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(24),
                  border: Theme.of(context).cardTheme.shape is RoundedRectangleBorder
                      ? Border.fromBorderSide((Theme.of(context).cardTheme.shape as RoundedRectangleBorder).side)
                      : null,
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.flash_on, color: Theme.of(context).colorScheme.secondary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'JATAH MAKAN HARI INI',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currencyFormatter.format(dailyAllowance),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Target: 40k/hari',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // ANALYTICS GRAPH
              expensesAsync.when(
                loading: () => const SizedBox(),
                error: (err, stack) => const SizedBox(),
                data: (expenses) {
                  if (expenses.isEmpty) return const SizedBox();
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    height: 200,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      border: Theme.of(context).cardTheme.shape is RoundedRectangleBorder
                          ? Border.fromBorderSide((Theme.of(context).cardTheme.shape as RoundedRectangleBorder).side)
                          : null,
                    ),
                    padding: const EdgeInsets.fromLTRB(10, 24, 24, 10),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 7,
                              reservedSize: 22,
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _getDailySpots(expenses, selectedMonth),
                            isCurved: true,
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // QUICK PRESET SHORTCUTS
              presetsAsync.when(
                loading: () => const SizedBox(),
                error: (err, stack) => const SizedBox(),
                data: (presets) {
                  if (presets.isEmpty) return const SizedBox();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        child: Text(
                          'PENCATATAN CEPAT (ONE-TAP LOG)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                      ),
                      SizedBox(
                        height: 50,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          itemCount: presets.length,
                          itemBuilder: (context, index) {
                            final preset = presets[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.surface,
                                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.flash_on, size: 16),
                                label: Text(preset.name),
                                onPressed: () async {
                                  await ref.read(expenseRepositoryProvider).addExpense(
                                        categoryId: preset.categoryId,
                                        amount: preset.amount,
                                        date: DateTime.now(),
                                        notes: 'Instant preset log: ${preset.name}',
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Instant log: ${preset.name} berhasil disimpan!'),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // CATEGORIES DETAILS BY GROUPS
              statsAsync.when(
                loading: () => const SizedBox(),
                error: (err, stack) => const SizedBox(),
                data: (groups) {
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  group.group.name,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                ),
                                Text(
                                  '${currencyFormatter.format(group.totalSpent)} / ${currencyFormatter.format(group.totalNetBudget)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          ...group.categories.map((cat) {
                            final ratio = cat.netBudget > 0 ? (cat.spent / cat.netBudget) : (cat.spent > 0 ? 1.0 : 0.0);
                            final progress = ratio.isNaN || ratio.isInfinite ? 1.0 : ratio.clamp(0.0, 1.0);
                            Color statusColor = Colors.green;
                            if (cat.status == 'HABIS' || cat.status == 'OVERBUDGET') {
                              statusColor = Colors.red;
                            } else if (cat.status == 'GUNAKAN DENGAN BIJAK' || cat.status == 'BAYAR SEKARANG' || cat.status == 'PINDAHKAN SEKARANG') {
                              statusColor = Colors.orange;
                            }

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardTheme.color,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
                              ),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        cat.category.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          cat.status,
                                          style: TextStyle(
                                            color: statusColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Terpakai: ${currencyFormatter.format(cat.spent)}',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      Text(
                                        'Sisa: ${currencyFormatter.format(cat.remaining)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: cat.remaining < 0 ? Colors.red : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress >= 1.0 ? Colors.red : Theme.of(context).colorScheme.primary,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      // PREMIUM FLOATING MULTI-ACTION ROW
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(
              context: context,
              icon: Icons.qr_code_scanner,
              label: 'Scan',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                );
              },
            ),
            const SizedBox(width: 8),
            Container(
              height: 40,
              width: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              context: context,
              icon: Icons.add,
              label: 'Tambah',
              isPrimary: true,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const AddExpenseDialog(),
                );
              },
            ),
            const SizedBox(width: 8),
            Container(
              height: 40,
              width: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              context: context,
              icon: Icons.psychology,
              label: 'Advisor',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AiAdvisorScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final activeColor = isPrimary 
        ? Theme.of(context).colorScheme.primary 
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isPrimary 
            ? BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              )
            : null,
        child: Row(
          children: [
            Icon(icon, color: activeColor, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: activeColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _getDailySpots(List<Expense> expenses, DateTime selectedMonth) {
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final Map<int, double> dailyTotals = {};
    for (var exp in expenses) {
      if (exp.date.month == selectedMonth.month && exp.date.year == selectedMonth.year) {
        dailyTotals[exp.date.day] = (dailyTotals[exp.date.day] ?? 0.0) + exp.amount;
      }
    }
    
    final List<FlSpot> spots = [];
    for (int day = 1; day <= lastDay; day++) {
      spots.add(FlSpot(day.toDouble(), dailyTotals[day] ?? 0.0));
    }
    return spots;
  }
}
