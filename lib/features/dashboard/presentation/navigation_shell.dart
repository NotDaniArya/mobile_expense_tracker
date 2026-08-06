import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import '../../expense/presentation/add_expense_dialog.dart';
import '../../receipt_scan/presentation/scanner_screen.dart';
import '../../ai_advisor/presentation/ai_advisor_screen.dart';

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const HistoryScreen(),
    const AiAdvisorScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;
    const inactiveColor = Colors.grey;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex == 3 ? 2 : _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomAppBar(
        padding: EdgeInsets.zero,
        height: 68,
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Tab 1: Beranda
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentIndex = 0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                      color: _currentIndex == 0 ? activeColor : inactiveColor,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Beranda',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
                        color: _currentIndex == 0 ? activeColor : inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tab 2: Riwayat
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentIndex = 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentIndex == 1 ? Icons.receipt_long : Icons.receipt_long_outlined,
                      color: _currentIndex == 1 ? activeColor : inactiveColor,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Riwayat',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                        color: _currentIndex == 1 ? activeColor : inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tab 3: Center Placeholder for Scan Struk FAB
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(height: 38), // Push the text down to clear the FAB
                  Text(
                    'Scan Struk',
                    style: TextStyle(
                      fontSize: 11,
                      color: inactiveColor,
                    ),
                  ),
                  SizedBox(height: 6),
                ],
              ),
            ),
            // Tab 4: Advisor
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _currentIndex = 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _currentIndex == 3 ? Icons.psychology : Icons.psychology_outlined,
                      color: _currentIndex == 3 ? activeColor : inactiveColor,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Advisor',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: _currentIndex == 3 ? FontWeight.bold : FontWeight.normal,
                        color: _currentIndex == 3 ? activeColor : inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tab 5: Tambah
            Expanded(
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddExpenseDialog(),
                  );
                },
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_box_outlined,
                      color: inactiveColor,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tambah',
                      style: TextStyle(
                        fontSize: 11,
                        color: inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Container(
        margin: const EdgeInsets.only(top: 12), // Adjust overlapping position
        height: 54,
        width: 54,
        child: FloatingActionButton(
          elevation: 4,
          shape: const CircleBorder(),
          backgroundColor: activeColor,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ScannerScreen()),
            );
          },
          child: const Icon(
            Icons.qr_code_scanner,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
