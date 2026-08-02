# [PLAN] High-Level Specification, QA Audit & Remediation Plan: Personal Expense Tracker App

## 📌 Context & Problem Statement
Aplikasi Personal Expense Tracker berbasis **Flutter** (Clean Architecture, Drift DB, Riverpod, Google ML Kit & Gemini AI) telah berhasil dijalankan dan diuji secara menyeluruh di emulator **Pixel 9 Pro (Android 16 API 36 / `emulator-5554`)**.

Pengujian dilakukan menggunakan dua skenario:
1. **Happy Path (Data Benar)**: CRUD pengeluaran, One-Tap Quick Log, perhitungan Jatah Harian, visualisasi grafik `fl_chart`, scan struk OCR/AI, serta saran AI Advisor.
2. **Negative Testing (Data Salah & Edge Cases)**: Menguji ketahanan aplikasi terhadap input tidak valid, alokasi budget berlebih, kegagalan scan struk, dan perhitungan batas tanggal.

---

## 🔍 Audit Kelemahan Aplikasi & Analisis Penyebab (Root Cause Analysis)

Berdasarkan hasil pengujian empiris, ditemukan **5 Kelemahan / Defect** pada aplikasi saat ini:

### ❌ Kelemahan 1: Input Nominal Negatif / Nol Lolos Validasi Form
- **Gejala (Symptom)**: Pengguna dapat menginput nominal negatif (misal `-50.000`) atau `0` pada dialog pencatatan pengeluaran. Nominal negatif justru **menambah** sisa budget alih-alih menguranginya.
- **Penyebab (Root Cause)**: Fungsi `validator` pada `_amountController` di `add_expense_dialog.dart` hanya mengecek `val.isEmpty` dan `double.tryParse(val) == null`, tetapi **belum mengecek kondisi `amount <= 0`**.

### ❌ Kelemahan 2: Kategori Sumber Cover Budget Bisa Menjadi Minus (Budget Exhaustion)
- **Gejala (Symptom)**: Ketika terjadi overbudget (misal kekurangan Rp 40.000), pengguna dapat memilih kategori sumber (misal *Dana Darurat*) yang sisa budget-nya hanya Rp 10.000. Akibatnya, budget *Dana Darurat* menjadi minus (-Rp 30.000).
- **Penyebab (Root Cause)**: Dropdown kategori sumber di `add_expense_dialog.dart` menampilkan semua kategori yang memiliki `remaining > 0`, tanpa memfilter kategori yang memiliki sisa budget cukup (`remaining >= _reallocationAmount`).

### ❌ Kelemahan 3: Hardcoded Value Rp 15.000 Saat Scan Struk Buram / Gagal OCR
- **Gejala (Symptom)**: Jika pengguna mengambil foto struk yang sangat buram atau tanpa angka, sistem fallback OCR lokal otomatis menetapkan nominal **Rp 15.000** tanpa memberi tahu pengguna bahwa ekstraksi angka gagal.
- **Penyebab (Root Cause)**: Fungsi `_parseOcrLocally` pada `scanner_screen.dart` secara otomatis menetapkan `extractedAmount = maxVal > 0 ? maxVal : 15000.0`.

### ❌ Kelemahan 4: Potensi Transaksi Terlewat Pada Batas Milidetik Akhir Bulan
- **Gejala (Symptom)**: Transaksi yang dicatat pada detik terakhir bulan (misal tanggal 31 jam 23:59:59.900) berpotensi tidak terbaca pada query filter bulanan.
- **Penyebab (Root Cause)**: Penentuan `endOfMonth` pada `expense_repository.dart` dan `budget_repository.dart` menggunakan `DateTime(year, month + 1, 0, 23, 59, 59)` yang memiliki presisi detik murni, sehingga mengabaikan fraksi milidetik (`.900ms`).

### ❌ Kelemahan 5: Kalkulator Jatah Harian Mis-Kalkulasi Pada Bulan Lalu / Masa Depan
- **Gejala (Symptom)**: Saat pengguna melihat dashboard bulan lalu (misal bulan Mei saat posisi hari ini di bulan Agustus), *Jatah Makan Hari Ini* dihitung menggunakan tanggal hari ini (tanggal 2), sehingga membagi sisa budget Mei dengan sisa hari bulan Agustus.
- **Penyebab (Root Cause)**: Provider `dailyAllowanceProvider` pada `dashboard_providers.dart` mengasumsikan `date` selalu bulan berjalan tanpa memeriksa apakah `selectedMonth` sama dengan bulan aktif saat ini.

---

## 🛠️ Rencana Perbaikan (Remediation Plan for Junior Dev / AI)

> [!IMPORTANT]
> **Petunjuk**: Jangan langsung mengubah kode aplikasi saat ini. Ikuti langkah-langkah perbaikan secara bertahap berikut:

### Phase 1: Perbaikan Validasi Form & Budget Cover (Priority: High)
1. **Fix Validator Nominal**:
   - Edit `add_expense_dialog.dart`. Tambahkan validasi `if (amount <= 0) return 'Nominal harus lebih besar dari 0';`.
2. **Fix Filter Kategori Sumber Cover Budget**:
   - Filter daftar `sourceCategories` agar hanya menampilkan kategori yang memiliki `remaining >= _reallocationAmount`.
   - Tambahkan pesan peringatan jika tidak ada kategori yang memiliki sisa budget cukup untuk menutupi overbudget.

### Phase 2: Perbaikan OCR Scanner Fallback (Priority: Medium)
1. **Fix Fallback Scanner**:
   - Edit `scanner_screen.dart`. Jika OCR tidak menemukan angka nominal yang valid (`maxVal == 0`), tampilkan dialog peringatan *"Nominal tidak terdeteksi pada struk, silakan isi manual"* alih-alih menetapkan nilai default Rp 15.000.

### Phase 3: Perbaikan Query Rentang Tanggal & Daily Allowance (Priority: Medium)
1. **Fix Date Range Query**:
   - Ubah logika query rentang tanggal di `expense_repository.dart` dan `budget_repository.dart` dari `isBetweenValues(start, end)` menjadi query eksklusif batas atas: `< DateTime(month.year, month.month + 1, 1)`.
2. **Fix Daily Allowance Logic**:
   - Edit `dailyAllowanceProvider` di `dashboard_providers.dart`. Tambahkan pengecekan: Jika `selectedMonth.month != DateTime.now().month`, kembalikan `0.0` atau tampilkan status *"Bulan Lalu / Masa Depan"*.

---

## 📋 Checklist Verifikasi Perbaikan Selanjutnya
- [ ] Test input nominal `-100` ➔ Harus ditolak oleh form validator.
- [ ] Test overbudget Rp 50k dengan kategori sumber sisa Rp 20k ➔ Harus ditolak/diperingatkan.
- [ ] Test scan foto polos/tanpa teks ➔ Harus memunculkan prompt input manual.
- [ ] Test transaksi jam 23:59:59.999 ➔ Harus tetap masuk ke statistik bulan tersebut.
- [ ] Navigasi ke bulan lalu ➔ Jatah harian tidak lagi menghitung tanggal bulan berjalan.
