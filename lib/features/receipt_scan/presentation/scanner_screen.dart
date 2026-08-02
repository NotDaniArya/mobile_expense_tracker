import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../expense/presentation/add_expense_dialog.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  File? _imageFile;
  bool _isLoading = false;
  String _statusText = '';

  final _imagePicker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _imageFile = File(pickedFile.path);
        _isLoading = true;
        _statusText = 'Membaca teks dari struk...';
      });

      // 1. Local OCR (Google ML Kit)
      final inputImage = InputImage.fromFile(_imageFile!);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      final rawOcrText = recognizedText.text;

      setState(() {
        _statusText = 'Menganalisis struk dengan AI...';
      });

      // 2. Structural Parsing with Gemini API
      Map<String, dynamic>? resultJson;
      try {
        final imageBytes = await _imageFile!.readAsBytes();
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: ApiConstants.geminiApiKey,
        );

        final prompt = 'Kamu adalah asisten keuangan pintar. Tolong baca struk belanja atau e-receipt ini, lalu ekstrak data nominal (jumlah uang), kategori yang paling cocok, tanggal transaksi, dan nama transaksi/note.'
            '\nPILIH KATEGORI HANYA DARI DAFTAR BERIKUT: '
            '\n- Cicilan Hutang'
            '\n- Wifi'
            '\n- Kost'
            '\n- Nisa'
            '\n- Mama'
            '\n- Makan Harian'
            '\n- Transport (TJ)'
            '\n- Skincare'
            '\n- Data 1 bulan'
            '\n- Dana Darurat'
            '\n- Tabungan'
            '\n- Belanja kebutuhan & pakaian'
            '\n- Nongkrong & Jajan'
            '\n\nFormat output harus berupa JSON murni dengan key: "amount" (double), "category" (string), "date" (string format YYYY-MM-DD), "notes" (string).'
            '\nBerikut adalah teks hasil OCR lokal sebagai referensi tambahan:\n$rawOcrText';

        final content = [
          Content.multi([
            TextPart(prompt),
            DataPart('image/jpeg', imageBytes),
          ])
        ];

        final response = await model.generateContent(content);
        final responseText = response.text ?? '';
        
        // Extract JSON codeblock if present
        final jsonStart = responseText.indexOf('{');
        final jsonEnd = responseText.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final cleanJson = responseText.substring(jsonStart, jsonEnd + 1);
          resultJson = jsonDecode(cleanJson);
        }
      } catch (e) {
        debugPrint('Gemini API Error: $e');
        // Fallback to local regex parse if Gemini fails or is offline
        resultJson = _parseOcrLocally(rawOcrText);
      }

      setState(() {
        _isLoading = false;
        _statusText = '';
      });

      if (resultJson != null && mounted) {
        _showConfirmationDialog(resultJson);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengekstrak data dari struk.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusText = '';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  // Basic regex fallback parser
  Map<String, dynamic> _parseOcrLocally(String text) {
    double extractedAmount = 0.0;
    String matchedCategory = 'Nongkrong & Jajan';
    String notes = 'Ekstraksi Struk Lokal';

    // Search for currency numbers
    final regExp = RegExp(r'(?:Rp|TOTAL|IDR)?\s*([0-9]{1,3}(?:\.[0-9]{3})*(?:,[0-9]+)?)', caseSensitive: false);
    final matches = regExp.allMatches(text);
    double maxVal = 0.0;
    for (var match in matches) {
      final cleanStr = match.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      final val = double.tryParse(cleanStr) ?? 0.0;
      if (val > maxVal && val < 5000000) { // Limit sanity check
        maxVal = val;
      }
    }
    extractedAmount = maxVal > 0 ? maxVal : 15000.0;

    // Simple keyword categorization
    final lowerText = text.toLowerCase();
    if (lowerText.contains('kopi') || lowerText.contains('coffee') || lowerText.contains('cafe') || lowerText.contains('jajan') || lowerText.contains('starbucks')) {
      matchedCategory = 'Nongkrong & Jajan';
      notes = 'Jajan / Nongkrong';
    } else if (lowerText.contains('makan') || lowerText.contains('nasi') || lowerText.contains('bakso') || lowerText.contains('warung') || lowerText.contains('resto')) {
      matchedCategory = 'Makan Harian';
      notes = 'Makan';
    } else if (lowerText.contains('gopay') || lowerText.contains('shopee') || lowerText.contains('ovo') || lowerText.contains('belanja') || lowerText.contains('indomaret') || lowerText.contains('alfamart')) {
      matchedCategory = 'Belanja kebutuhan & pakaian';
      notes = 'Belanja Kebutuhan';
    } else if (lowerText.contains('gojek') || lowerText.contains('grab') || lowerText.contains('tj') || lowerText.contains('busway') || lowerText.contains('mrt')) {
      matchedCategory = 'Transport (TJ)';
      notes = 'Transport';
    }

    return {
      'amount': extractedAmount,
      'category': matchedCategory,
      'date': DateTime.now().toIso8601String().substring(0, 10),
      'notes': notes,
    };
  }

  void _showConfirmationDialog(Map<String, dynamic> data) {
    final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final categoryName = data['category'] as String? ?? 'Makan Harian';
    final notes = data['notes'] as String? ?? 'Scan E-Receipt';
    final dateStr = data['date'] as String? ?? '';
    final date = DateTime.tryParse(dateStr) ?? DateTime.now();

    // Map Category name to category ID matching default seeder IDs
    int categoryId = 6; // Default to Makan Harian
    final catLower = categoryName.toLowerCase();
    if (catLower.contains('cicilan')) {
      categoryId = 1;
    } else if (catLower.contains('wifi')) {
      categoryId = 2;
    } else if (catLower.contains('kost')) {
      categoryId = 3;
    } else if (catLower.contains('nisa')) {
      categoryId = 4;
    } else if (catLower.contains('mama')) {
      categoryId = 5;
    } else if (catLower.contains('makan')) {
      categoryId = 6;
    } else if (catLower.contains('transport') || catLower.contains('tj')) {
      categoryId = 7;
    } else if (catLower.contains('skincare')) {
      categoryId = 8;
    } else if (catLower.contains('data')) {
      categoryId = 9;
    } else if (catLower.contains('darurat')) {
      categoryId = 10;
    } else if (catLower.contains('tabung')) {
      categoryId = 11;
    } else if (catLower.contains('belanja')) {
      categoryId = 12;
    } else if (catLower.contains('nongkrong') || catLower.contains('jajan')) {
      categoryId = 13;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.green),
              SizedBox(width: 8),
              Text('Hasil Ekstraksi AI'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nominal: Rp ${amount.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Kategori: $categoryName'),
              const SizedBox(height: 8),
              Text('Catatan: $notes'),
              const SizedBox(height: 8),
              Text('Tanggal: ${dateStr.isEmpty ? "Hari Ini" : dateStr}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close confirm dialog
                Navigator.of(context).pop(); // Close scanner screen
                // Open AddExpenseDialog with prepopulated values
                showDialog(
                  context: ref.context, // Use shell context
                  builder: (context) => AddExpenseDialog(
                    initialAmount: amount,
                    initialCategoryId: categoryId,
                    initialNotes: notes,
                    initialDate: date,
                  ),
                );
              },
              child: const Text('Simpan & Sesuaikan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Receipt Scanner'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                ),
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 20),
                            Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.file(_imageFile!, fit: fitCoverOrContain()),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 80, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Ambil foto struk belanja atau e-receipt\nuntuk pencatatan otomatis berbasis AI',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                    ),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Kamera'),
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  BoxFit fitCoverOrContain() => BoxFit.cover;
}
