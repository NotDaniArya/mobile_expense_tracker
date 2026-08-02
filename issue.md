# [PLAN] High-Level Specification, QA Extreme Stress Audit & Remediation Plan

## 📌 Context & Problem Statement
Pengujian beban ekstrem (**Extreme Data & Error Stress Testing**) telah dilakukan pada aplikasi Personal Expense Tracker di emulator **Pixel 9 Pro**. Pengujian ini memfokuskan pada respon sistem terhadap input batas atas/ekstrem, karakter khusus/newline injection, pembagian nol (*division by zero*), penanganan error jaringan/API Key, dan skenario *outlier* grafik.

---

## 🔍 Hasil Stress Audit Data Ekstrem & Analisis Penyebab (Root Cause Analysis)

Ditemukan **5 Cacat Celah Beban Ekstrem (Extreme Data Defects)** pada aplikasi:

### ❌ Extreme Defect 1: UI Overflow / Distortion pada Input Nominal Triliunan (Large Nominal)
- **Gejala (Symptom)**: Saat pengguna memasukkan angka bernilai triliunan (misal Rp 999.999.999.999), tampilan text pada kartu kategori dashboard dan dialog overbudget mengalami **RenderFlex overflowed by XXX pixels** (garis kuning-hitam pada layar).
- **Penyebab (Root Cause)**: Widget `Text` yang menampilkan teks mata uang `currencyFormatter.format(amount)` tidak dibungkus dengan `FittedBox`, `maxLines: 1`, atau `TextOverflow.ellipsis`, dan belum mendukung format ringkas (misal `999.9 M` atau `1.0 T`).

### ❌ Extreme Defect 2: Injeksi Newline Beruntun & Teks Panjang pada Kolom Catatan (Notes Injection)
- **Gejala (Symptom)**: Memasukkan 20+ karakter *newline* (`\n\n\n...`) atau teks deskripsi yang sangat panjang pada kolom `notes` menyebabkan kartu item transaksi membentang secara vertikal menutupi seluruh layar.
- **Penyebab (Root Cause)**: `TextFormField` catatan pada `add_expense_dialog.dart` belum membatasi `maxLength` (misal 100 karakter) dan `maxLines`, serta tampilan item daftar transaksi belum menggunakan `maxLines: 1, overflow: TextOverflow.ellipsis`.

### ❌ Extreme Defect 3: Mis-Kalkulasi Progress Bar pada Net Budget 0 (Division by Zero / NaN)
- **Gejala (Symptom)**: Jika suatu kategori memiliki budget nol (`netBudget == 0.0`) dan dilakukan pengeluaran, kalkulasi rasio progress `spent / netBudget` menghasilkan nilai `NaN` atau `0.0`. Tampilan progress bar menunjukkan 0% padahal pengeluaran sudah terlampaui (overbudget 100%).
- **Penyebab (Root Cause)**: Perhitungan persentase progress di `dashboard_screen.dart` belum memeriksa kondisi `netBudget == 0` dan belum melakukan `.clamp(0.0, 1.0)`.

### ❌ Extreme Defect 4: Tampilan Raw Technical Stack Trace saat Koneksi Terputus / API Key Tidak Valid
- **Gejala (Symptom)**: Ketika koneksi internet terputus atau API Key Gemini tidak valid, layar `AiAdvisorScreen` menampilkan teks error teknis internal Dart (seperti `[google_generative_ai/api-key-invalid] ...`) tanpa pesan yang ramah pengguna (*user-friendly error UI*) dan tanpa tombol coba lagi (*retry button*).
- **Penyebab (Root Cause)**: Fungsi `_fetchAiAdvice()` di `ai_advisor_screen.dart` langsung menetapkan `e.toString()` ke state error UI tanpa mem-parsing tipe eksepsi.

### ❌ Extreme Defect 5: Distorsi & Tumpang Tindih Sumbu Y Grafik pada Data Outlier Ekstrem
- **Gejala (Symptom)**: Jika terdapat 1 transaksi bernilai Rp 50.000.000 sedangkan transaksi lainnya Rp 10.000, grafik `fl_chart` memanjangkan Y-axis secara ekstrem sehingga batang transaksi kecil tampak 0px dan label sumbu Y tumpang tindih.
- **Penyebab (Root Cause)**: `BarChartData` di `dashboard_screen.dart` belum menentukan batasan interval Y-axis (`reservedSize` & `interval`) secara terstruktur untuk mengantisipasi selisih nilai ekstrem.

---

## 🛠️ Rencana Perbaikan (Remediation Plan for Extreme Data Issues)

> [!IMPORTANT]
> **Petunjuk**: Jangan langsung mengubah kode aplikasi saat ini. Ikuti langkah-langkah perbaikan bertahap berikut:

### Phase 1: Penanganan UI Robustness & Input Boundaries (Priority: High)
1. **Fix Large Nominal UI Formatting**:
   - Pembungkus teks nominal di `dashboard_screen.dart` dengan `FittedBox` atau `TextOverflow.ellipsis`.
   - Buat fungsi pembantu format mata uang ringkas (`compactCurrencyFormatter`) untuk angka di atas 100 Juta (misal `150 Jt`, `1.2 M`).
2. **Fix Notes Length & Newline Sanitization**:
   - Tambahkan `maxLength: 100` dan `maxLines: 2` pada `TextFormField` catatan di `add_expense_dialog.dart`.
   - Bersihkan karakter `\n` menjadi spasi tunggal saat menampilkan catatan di tile daftar transaksi.

### Phase 2: Perbaikan Formula Progress & Error UI (Priority: Medium)
1. **Fix Zero Budget Progress Ratio**:
   - Di `dashboard_screen.dart`, jika `netBudget <= 0`, set progress ratio ke `1.0` jika `spent > 0`, atau `0.0` jika `spent == 0`. Selalu gunakan `.clamp(0.0, 1.0)`.
2. **Fix User-Friendly AI Error State**:
   - Edit `ai_advisor_screen.dart`. Tangkap eksepsi spesifik dan tampilkan kartu error ramah pengguna dengan tombol *"Coba Lagi"* (*Retry Button*).

### Phase 3: Perbaikan Skala Grafik Outlier (Priority: Low)
1. **Fix Chart Y-Axis Interval**:
   - Hitung `maxY` dan `interval` secara teratur pada `BarChartData` untuk memastikan label sumbu Y tidak bertumpuk ketika ada nilai outlier.

---

## 📋 Checklist Verifikasi Beban Ekstrem Selanjutnya
- [ ] Input nominal Rp 999.999.999.999 ➔ Tidak ada overflow layout pada dashboard.
- [ ] Input catatan 20 newline ➔ Teks dibersihkan & dipotong rapi dengan ellipsis.
- [ ] Pengeluaran pada kategori budget Rp 0 ➔ Progress bar menunjukkan status penuh/overbudget 100%.
- [ ] Simulasi luring pada AI Advisor ➔ Tampil error UI ramah pengguna + tombol retry.
