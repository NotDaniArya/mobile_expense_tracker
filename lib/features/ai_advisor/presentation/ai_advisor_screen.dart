import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/constants/api_constants.dart';
import '../../dashboard/presentation/dashboard_providers.dart';

class AiAdvisorScreen extends ConsumerStatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  ConsumerState<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends ConsumerState<AiAdvisorScreen> {
  bool _isLoading = false;
  String _adviceMarkdown = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchAiAdvice());
  }

  Future<void> _fetchAiAdvice() async {
    setState(() {
      _isLoading = true;
      _adviceMarkdown = '';
      _errorMessage = null;
    });

    try {
      final selectedMonth = ref.read(selectedMonthProvider);
      final statsAsync = ref.read(budgetGroupsWithStatsProvider(selectedMonth));
      final transfersAsync = ref.read(transfersForMonthProvider(selectedMonth));

      // Construct transaction summary for Gemini
      StringBuffer statsSummary = StringBuffer();
      
      statsAsync.whenData((groups) {
        for (var group in groups) {
          statsSummary.writeln('Group: ${group.group.name}');
          for (var cat in group.categories) {
            statsSummary.writeln(
                '  - ${cat.category.name}: Original Budget Rp ${cat.originalBudget.toInt()}, Net Budget Rp ${cat.netBudget.toInt()}, Terpakai Rp ${cat.spent.toInt()}, Sisa Rp ${cat.remaining.toInt()} (Status: ${cat.status})');
          }
        }
      });

      transfersAsync.whenData((transfers) {
        if (transfers.isNotEmpty) {
          statsSummary.writeln('\nRiwayat Pemindahan Budget (Cover Overbudget):');
          for (var transfer in transfers) {
            statsSummary.writeln(
                '  - Dari CatID ${transfer.sourceCategoryId} ke CatID ${transfer.targetCategoryId} sebesar Rp ${transfer.amount.toInt()} karena: ${transfer.reason}');
          }
        }
      });

      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: ApiConstants.geminiApiKey,
      );

      final prompt = 'Kamu adalah Penasihat Keuangan Pribadi (Financial Advisor) profesional yang cerdas dan kreatif. Berikut adalah ringkasan budgeting bulanan pengguna:\n'
          '${statsSummary.toString()}\n\n'
          'Tolong berikan analisis mendalam mengenai pengeluaran pengguna bulan ini dalam Bahasa Indonesia. Analisis harus mencakup:\n'
          '1. **Evaluasi Anggaran**: Apakah target budgeting realistis berdasarkan realisasi terpakai?\n'
          '2. **Analisis Pemindahan Budget (Overbudget)**: Ulas kategori mana saja yang sering overbudget sehingga harus ditambal dari kategori lain.\n'
          '3. **Rekomendasi Bulan Depan**: Berikan saran penyesuaian alokasi anggaran yang optimal agar pengeluaran lebih stabil dan tidak sering minus.\n\n'
          'Tulis saranmu dengan gaya bahasa yang profesional, premium, kreatif, mudah dimengerti, dan gunakan format Markdown agar tampil cantik di aplikasi Flutter.';

      final response = await model.generateContent([Content.text(prompt)]);
      
      setState(() {
        _adviceMarkdown = response.text ?? 'Gagal menghasilkan saran keuangan.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal memuat saran keuangan. Pastikan koneksi internet Anda aktif dan API Key valid.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Financial Advisor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchAiAdvice,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 20),
                      Text('AI sedang menyusun saran terbaik untukmu...',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 64, color: Theme.of(context).colorScheme.error),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _fetchAiAdvice,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Coba Lagi'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology, size: 36, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 12),
                              const Text(
                                'Saran Keuangan Cerdas',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const Divider(height: 32),
                          // Premium custom parsing for markdown to simple widgets
                          _buildMarkdownBody(_adviceMarkdown),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  // Simple and premium custom parser for markdown text to render beautifully in Flutter without extra large packages
  Widget _buildMarkdownBody(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('###')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          child: Text(
            trimmed.replaceFirst('###', '').trim(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
        ));
      } else if (trimmed.startsWith('##')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
          child: Text(
            trimmed.replaceFirst('##', '').trim(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
          ),
        ));
      } else if (trimmed.startsWith('#')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
          child: Text(
            trimmed.replaceFirst('#', '').trim(),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ));
      } else if (trimmed.startsWith('*') || trimmed.startsWith('-')) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  _cleanBold(trimmed.substring(1).trim()),
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
            ],
          ),
        ));
      } else if (trimmed.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Text(
            _cleanBold(trimmed),
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  String _cleanBold(String text) {
    return text.replaceAll('**', '').replaceAll('*', '');
  }
}
