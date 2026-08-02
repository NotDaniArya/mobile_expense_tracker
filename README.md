# 📱 Mobile Expense Tracker & Financial AI Assistant

Aplikasi pencatat keuangan pribadi modern dan pintar berbasis **Flutter** yang dirancang dengan **Clean Architecture**, **3-Tier Grouped Budgeting**, **Smart Cover Overbudget Reallocation**, **ML Kit + Gemini AI Receipt Scanner**, dan **AI Financial Advisor**.

---

## ✨ Fitur-Fitur Utama

1. **3-Tier Grouped Budgeting (Drift SQLite DB)**:
   - Terdiri dari 3 kelompok kategori utama: **Kewajiban Tetap**, **Biaya Hidup**, dan **Terserah (Savings & Wants)**.
   - Database ter-seeding otomatis dengan target persentase dan alokasi budget bulanan.
2. **Dynamic Cover Overbudget & Reallocation**:
   - Memungkinkan penutupan sisa kekurangan anggaran secara langsung saat mencatat transaksi berlebih dari kategori sumber lain (*cross-category budget cover*).
   - Dilengkapi validasi penyaringan agar kategori sumber yang tidak cukup tidak menjadi minus.
3. **One-Tap Quick Log Presets**:
   - Shortcut pencatatan transaksi cepat 1-tap untuk pengeluaran harian berulang (misal: *Sarapan 10k*, *Makan Siang 15k*, *Makan Malam 20k*, *Topup TJ 50k*).
4. **Real-time Daily Allowance ("Jatah Harian")**:
   - Menghitung sisa jatah budget makan harian secara dinamis berdasarkan sisa hari aktif pada bulan berjalan.
5. **AI Receipt & E-Receipt Scanner**:
   - Pemindaian struk berbasis **Google ML Kit OCR** lokal yang terintegrasi dengan **Gemini 1.5 Flash** untuk ekstraksi nominal, tanggal, dan pengelompokan kategori otomatis.
6. **AI Financial Advisor**:
   - Asisten keuangan pribadi AI yang menganalisis pola pengeluaran bulanan dan histori *budget transfer* untuk memberikan saran penyesuaian alokasi anggaran bulan berikutnya.
7. **UI/UX Premium & Reaktif**:
   - Visualisasi grafik tren pengeluaran harian (`fl_chart`), progress bar kategori reaktif, serta dukungan otomatis **Dark / Light Mode**.

---

## 🛠️ Teknologi & Stack (Tech Stack)

| Komponen | Teknologi |
|---|---|
| **Framework** | Flutter (Dart SDK) |
| **Arsitektur** | Clean Architecture (Presentation, Domain, Data) |
| **State Management** | Flutter Riverpod |
| **Database Lokal** | Drift (SQLite) dengan In-Memory Testing Support |
| **Vision & AI Engine** | Google ML Kit Text Recognition & Google Generative AI (Gemini 1.5 Flash) |
| **Grafik & Visualisasi** | `fl_chart` |
| **Environment Config** | `flutter_dotenv` |

---

## 📁 Struktur Direktori (Folder Structure)

```text
lib/
├── core/
│   ├── constants/        # API Constants & Environment Loader
│   ├── database/         # Schema Drift SQLite DB, Tables & Auto-Seeder Data
│   └── theme/            # Sistem Tema Premium (Light & Dark Theme)
└── features/
    ├── ai_advisor/       # Presentasi & UI AI Financial Advisor (Gemini 1.5 Flash)
    ├── budget_group/     # Data & Repository Manajemen Kategori & Budget Transfer
    ├── dashboard/        # Dashboard Utama, Visualisasi Grafik, Presets & Riverpod Providers
    ├── expense/          # Repository Transaksi & Dialog Catat Pengeluaran (AddExpenseDialog)
    └── receipt_scan/     # Layar Scanner Struk & Integrasi ML Kit + Gemini OCR
```

---

## 🗄️ Skema Database (Database Schema)

Aplikasi menggunakan **Drift SQLite** dengan 5 tabel utama:

1. **`category_groups`**: Menyimpan kelompok utama budgeting (`id`, `name`, `targetPercentage`).
2. **`categories`**: Menyimpan detail kategori pengeluaran (`id`, `groupId`, `name`, `originalBudget`).
3. **`expenses`**: Menyimpan transaksi pengeluaran (`id`, `categoryId`, `amount`, `date`, `notes`, `location`).
4. **`budget_transfers`**: Menyimpan histori penyesuaian/pindahan budget silang (`id`, `sourceCategoryId`, `targetCategoryId`, `amount`, `date`, `reason`).
5. **`quick_presets`**: Menyimpan shortcut pencatatan 1-tap (`id`, `name`, `categoryId`, `defaultAmount`, `icon`).

---

## 🚀 Cara Menjalankan Aplikasi (How to Run)

### Prasyarat:
- Flutter SDK (v3.19 atau lebih baru)
- Android Studio / Xcode & Emulator terpasang (misal Pixel 9 Pro)

### Langkah-langkah:

1. **Clone Repositori**:
   ```bash
   git clone https://github.com/NotDaniArya/mobile_expense_tracker.git
   cd mobile_expense_tracker
   ```

2. **Buat File Konfigurasi `.env`**:
   Buat file bernama `.env` di root direktori proyek (sejajar dengan `pubspec.yaml`), lalu isi dengan API Key Gemini Anda:
   ```env
   GEMINI_API_KEY=KUNCI_API_GEMINI_ANDA
   ```
   *(File `.env` sudah terdaftar di `.gitignore` sehingga aman dari komit/push).*

3. **Unduh Dependensi**:
   ```bash
   flutter pub get
   ```

4. **Jalankan di Emulator / Perangkat**:
   ```bash
   flutter run
   ```

---

## 🔬 Cara Menjalankan Pengujian Mendalam (Testing Suite)

Proyek ini dilengkapi dengan suite pengujian otomatis menyeluruh untuk menguji fungsi dasar, batas milidetik tanggal, dan ketahanan terhadap beban data ekstrem:

### 1. Menjalankan Seluruh Suite Pengujian (Unit & Stress Tests):
```bash
flutter test
```

### 2. Menjalankan Pengujian Spesifik Data Ekstrem:
```bash
flutter test test/extreme_data_test.dart
```

### 3. Menjalankan Pengujian Skenario Alokasi Budget & Rentang Tanggal:
```bash
flutter test test/unit_test.dart
```

### 4. Menjalankan Analisis Statis Kode (Lint & Static Analysis):
```bash
dart analyze
```
