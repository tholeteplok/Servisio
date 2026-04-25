// Sentralisasi semua string UI untuk memudahkan pemeliharaan dan lokalisasi.
// ADR-002: Seluruh string UI statis harus dipindahkan ke file ini.
// 
// Usage:
// ```dart
// Text(AppStrings.common.save)
// Text(AppStrings.transaction.stepUnit)
// ```
import 'package:intl/intl.dart';

class AppStrings {
  const AppStrings._();
  
  static const CommonStrings common = CommonStrings();
  static const AuthStrings auth = AuthStrings();
  static const HomeStrings home = HomeStrings();
  static const TrxStrings transaction = TrxStrings();
  static const CatalogStrings catalog = CatalogStrings();
  static const CustomerStrings customer = CustomerStrings();
  static const HistoryStrings history = HistoryStrings();
  static const SettingStrings settings = SettingStrings();
  static const ErrorStrings error = ErrorStrings();
  static const SuccessStrings success = SuccessStrings();
  static const AccessStrings access = AccessStrings();
  static const ReminderStrings reminder = ReminderStrings();
  static const SyncStrings sync = SyncStrings();
  static const NavStrings nav = NavStrings();
  static const StatsStrings stats = StatsStrings();
  static const ProfileStrings profile = ProfileStrings();
  static const SecurityStrings security = SecurityStrings();
  static const DataCenterStrings dataCenter = DataCenterStrings();
  static const DatePatterns date = DatePatterns();
  static const WhatsAppTemplates whatsapp = WhatsAppTemplates();
}

class CommonStrings {
  const CommonStrings();
  final cancel = 'Batal';
  final save = 'Simpan';
  final delete = 'Hapus';
  final edit = 'Edit';
  final search = 'Cari...';
  final loading = 'Memuat...';
  final noData = 'Tidak ada data';
  final confirm = 'Konfirmasi';
  final yes = 'Ya';
  final no = 'Tidak';
  final back = 'Kembali';
  final next = 'Selanjutnya';
  final aturSekarang = 'Atur Sekarang';
  final useBiometric = 'Gunakan Biometrik';
  final logoutAccount = 'Keluar Akun';
  final logout = 'Keluar';
  final add = 'Tambahkan';
  final addShort = 'Tambah';
  final fullName = 'Nama Lengkap';
  final customerNameLabel = 'Nama Pelanggan';
  final phone = 'Nomor HP';
  final notFound = 'Tidak ditemukan';
  final item = 'Item';
  final emptyData = 'Data masih kosong';
  final noCategory = 'Tanpa Kategori';
  final close = 'Tutup';
  final refresh = 'Segarkan';
  final filter = 'Filter';
  final reset = 'Atur Ulang';
  final applyFilter = 'Terapkan Filter';
  final understand = 'Mengerti';
  
  final dateLabel = 'Tanggal';
  final typeLabel = 'Jenis';
  final thankYouShort = 'TERIMA KASIH';
  final camera = 'Kamera';
  final gallery = 'Galeri';
  final requiredField = 'Wajib diisi';
  final none = 'Belum diisi';
  final all = 'Semua';
  final service = 'Servis';
  final product = 'Produk';
  final cash = 'Tunai';
  final qris = 'QRIS';
  final transfer = 'Transfer';
  final phoneNumberWA = 'Nomor Telepon/WA';
  final saveChanges = 'Simpan Perubahan';
  
  String deleteSuccess(String item) => '$item berhasil dihapus';
  String saveSuccess(String item) => '$item berhasil disimpan';

  final thousand = 'rb';
  final million = 'jt';
  final currencySymbol = 'Rp';
}

class AuthStrings {
  const AuthStrings();
  final loginTitle = 'ServisI/O';
  final loginSubtitle = 'PLATFORM WORKSHOP PROFESIONAL';
  final loginDescription = 'Manajemen rincian Teknisi, Inventaris,\ndan Pendapatan secara real-time.';
  final signInWithGoogle = 'Masuk dengan Akun Google';
  final footerMetadata = 'Precision Atelier v1.2 • Protected Enclave';
  
  final reasonUnlock = 'Buka Workshop Encrypted Data';
  final pinRequired = 'Tentukan PIN Workshop';
  final enterPin = 'Masukkan PIN Workshop';
  final workshopLocked = 'Workshop Terkunci';
  final enterPinDesc = 'Masukkan 6 digit PIN Workshop Anda untuk mengakses data.';
  final setPinDesc = 'PIN ini digunakan untuk mengenkripsi data workshop Anda secara lokal.';
  final bengkelNoMasterKey = 'Bengkel tidak memiliki Master Key';
  final pinIncorrect = 'PIN Workshop salah';
  final restoreChoice = 'Restore Data Cloud?';
  final restoreChoiceDesc = 'Device baru terdeteksi. Ingin memulihkan data dari Cloud?';
  
  // Onboarding
  final welcomeTitle = 'Selamat Datang di ServisI/O';
  final welcomeSubtitle = 'Satu platform untuk semua kebutuhan manajemen bengkel Anda.';
  final ownerTitle = 'Saya Pemilik Bengkel';
  final ownerSubtitle = 'Kelola tim, pantau pendapatan, dan kembangkan bisnis Anda.';
  final staffTitle = 'Saya Staff / Mekanik';
  final staffSubtitle = 'Masuk ke ekosistem operasional yang ada sebagai tim profesional.';
  final badgeExecutive = 'EKSEKUTIF';
  final badgeOperational = 'OPERASIONAL';

  // Create Bengkel
  final createBengkelTitle = 'Daftarkan Bengkel';
  final createBengkelSubtitle = 'Mulai atur bengkel Anda dalam hitungan menit.';
  final workshopNameLabel = 'Nama Bengkel';
  final workshopNameHint = 'Contoh: Bengkel Jaya Motor';
  final workshopIdLabel = 'ID Bengkel';
  final workshopIdHint = 'Contoh: jaya-motor';
  final checkingId = 'Memeriksa ketersediaan...';
  final idAvailable = 'ID tersedia';
  final idUnavailable = 'ID sudah digunakan';
  final registerNow = 'Daftarkan Sekarang';
  
  final acceptTermsPrefix = 'Saya menyetujui ';
  final termsOfService = 'Syarat Penggunaan';
  final privacyPolicy = 'Kebijakan Privasi';
  final and = ' & ';
  final mustAcceptTerms = 'Harap setujui Syarat Penggunaan untuk melanjutkan';
}

class HomeStrings {
  const HomeStrings();
  final searchHint = 'Cari transaksi hari ini...';
  final todayRevenue = 'PENDAPATAN HARI INI';
  final reminder = 'REMINDER';
  final visitors = 'PENGUNJUNG';
  final inventory = 'INVENTARIS';
  final inventorySafe = 'Aman';
  final todayActivities = 'Aktivitas Hari Ini';
  final seeAll = 'Lihat Semua';
  final settings = 'Pengaturan';
  final qrisNotSet = 'QRIS Belum Diatur';
  final qrisNotSetDesc = 'Fitur QRIS aktif tetapi gambar belum diunggah. Atur sekarang?';
  final setPicture = 'Atur Gambar';
  
  // Bento Cards
  final bentoInventory = 'INVENTARIS';
  final bentoRevenue = 'PENDAPATAN';
  final bentoReminders = 'REMINDER';
  final bentoVisitors = 'PENGUNJUNG';

  final service = 'Servis';
  final sellItems = 'Jual Barang';
  final customers = 'Pelanggan';
  final reports = 'Laporan';
  
  // Bottom Nav
  final navHome = 'Beranda';
  final navCatalog = 'Inventaris';
  final navHistory = 'Riwayat';

  // Bento labels & stats
  final totalRevenueLabel = 'Total Pendapatan';
  final upcoming = 'Mendatang';
  final processed = 'Diproses';
  final inventoryStatus = 'Status Inventaris';
  final sectionCustomerPlate = 'PELANGGAN & PLAT';
  final sectionInventory = 'INVENTARIS';
  final sectionHistory = 'RIWAYAT TRANSAKSI';
  final monthlyTarget = 'Target Bulanan';
  final progress = 'progress';
  final performanceGood = 'Kinerja Baik!';
  final badgeCustomer = 'Pelanggan';
  final badgeVehicle = 'Kendaraan';
  final noVisitorsToday = 'Belum ada pengunjung hari ini.';
  final noSearchResults = 'Tidak ada hasil untuk';
  final remainingTarget = 'Sisa target: ';
}


class TrxStrings {
  const TrxStrings();
  
  // Wizard Steps
  final stepUnit = 'Unit';
  final stepDiagnosa = 'Diagnosa';
  final stepPekerjaan = 'Pekerjaan';
  final stepRingkasan = 'Ringkasan';
  
  // Status
  final statusAntri = 'Antri';
  final statusServis = 'Servis';
  final statusSelesai = 'Selesai';
  final statusLunas = 'Lunas';
  final statusPaid = 'LUNAS';
  final statusUnpaid = 'BELUM LUNAS';
  
  // Labels
  final newTransaction = 'Transaksi Baru';
  final editTransaction = 'Edit Transaksi';
  final saveTransaction = 'Simpan Transaksi';
  final next = 'Selanjutnya';
  final back = 'Kembali';
  final deleteTrxTooltip = 'Hapus Transaksi';
  
  // Unit Info
  final unitInfo = 'Informasi Unit';
  final unitInfoDesc = 'Pilih jenis kendaraan dan masukkan nomor plat.';
  final plateNumber = 'Nomor Plat';
  final vehicleModel = 'Model Kendaraan';
  final vehicleModelHint = 'Misal: Honda Vario 125';
  final year = 'Tahun';
  final color = 'Warna';
  final motor = 'Motor';
  final mobil = 'Mobil';
  
  // Customer Info
  final customerInfo = 'Informasi Pelanggan';
  final customerInfoDesc = 'Cari pelanggan lama atau ketik untuk pelanggan baru.';
  final customerName = 'Nama Pelanggan';
  final phoneNumber = 'Nomor Telepon';
  final address = 'Alamat Pelanggan';
  final addressHint = 'Jl. Contoh No. 123...';
  
  // Diagnosa
  final complaint = 'Keluhan Pelanggan';
  final addPhoto = 'Tambah Foto Unit';
  final sparepartOptional = 'Suku Cadang (Opsional)';
  final sparepartDesc = 'Pilih kategori item untuk ditambahkan dengan cepat.';
  final technician = 'Teknisi Penanggung Jawab';
  final selectTechnician = 'Pilih Teknisi';
  
  // Items
  final serviceAndParts = 'Item Servis & Part';
  final serviceAndPartsDesc = 'Tambahkan jasa servis dan sparepart yang digunakan.';
  final addServicePart = 'Tambah Jasa / Part';
  final quickSearch = 'Cari & tambah item cepat...';
  
  // Summary
  final summary = 'Ringkasan Transaksi';
  final summaryDesc = 'Review semua data sebelum disimpan.';
  final totalEstimate = 'TOTAL ESTIMASI';
  final totalCost = 'Total Biaya';
  final transactionDate = 'Tanggal Transaksi';
  final recommendation = 'REKOMENDASI KEMBALI (OPSIONAL)';
  final recommendationDesc = 'Estimasi waktu dan jarak servis berikutnya.';
  final byTime = 'Berdasarkan Waktu';
  final byDistance = 'Berdasarkan Jarak';
  final currentOdometer = 'Tulis Jarak (Km) saat ini';
  final targetService = 'Target Servis (Km)';
  final month = 'Bulan';
  
  // Sections Detail
  final sectionCustomerDetail = 'DETAIL PELANGGAN';
  final sectionVehicleDetail = 'DETAIL KENDARAAN';
  final sectionCostTime = 'BIAYA & WAKTU';
  final sectionServiceNotes = 'CATATAN SERVIS';
  final sectionReturnRecommendation = 'REKOMENDASI KEMBALI';
  final sectionServiceItems = 'ITEM SERVIS & SPAREPART';
  final sectionPhotos = 'FOTO BUKTI / KENDARAAN';
  final noItemsRecorded = 'Tidak ada item tercatat';
  
  // Overdue / Due banners
  final overdueBanner = '⚠️ MASA SERVIS BERIKUTNYA SUDAH TERLEWAT';
  final dueSoonBanner = '🔔 SUDAH MASUK WAKTU SERVIS BERKALA';
  
  // Dialogs
  final deleteTrxTitle = 'Hapus Transaksi?';
  final deleteTrxDesc = 'Yakin ingin menghapus transaksi ini? Tindakan ini tidak bisa dibatalkan.';
  
  // Mechanics
  final mechanicNotes = 'Catatan Mekanik';
  
  String totalEstimateValue(int itemCount, String amount) => 
      '$itemCount ITEM • $amount';

  String formatCurrency(num amount) => 
      'Rp ${NumberFormat('#,###', 'id_ID').format(amount)}';
      
  String recommendationTarget(String km) => 
      'Target servis berikutnya: $km km';
      
  String bonusValue(String amount) => 
      'Bonus: $amount';
  
  String deleteConfirmation(String trxNumber) => 
      'Transaksi $trxNumber dihapus';
  
  String returnMonthsValue(int months) => 'Kembali dalam $months Bulan';
  String returnDistanceValue(String km) => 'Kembali pada $km Km';
  String followUpMessage(String dateStr) => 'Estimasi servis berikutnya seharusnya pada $dateStr. Segera lakukan follow-up pelanggan.';
  
  // Activity Card & Actions
  final statusAntriCaps = 'ANTRI';
  final statusServisCaps = 'DI SERVIS';
  final statusSelesaiCaps = 'SELESAI';
  final statusLunasCaps = 'LUNAS';
  final actionProses = 'PROSES SERVIS';
  final actionSelesaikan = 'SELESAIKAN';
  final actionLunas = 'SIAP / LUNAS';
  final deleteActivityTitle = 'Hapus Aktivitas?';
  final deleteActivityDesc = 'Ingin menghapus catatan ini secara permanen?';
  final swipeToDeleteHint = 'Geser sekali lagi untuk menghapus';
  final confirmDelete = 'KONFIRMASI HAPUS';
  final deleteCaps = 'HAPUS?';
  
  // Tech Note Sheet
  final techNotesTitle = 'Catatan Teknisi';
  final techNotesSubtitle = 'Tambahkan detail teknis & rekomendasi servis.';
  final techNotesLabel = 'Kondisi & Tindakan';
  final techNotesHint = 'Contoh: Kampas rem tipis, sudah diganti...';
  final returnRecommendation = 'Rekomendasi Servis Kembali';
  final odometerLabel = 'Kilometer (+KM)';
  final timeLabel = 'Waktu (+Bulan)';
  final techNotesSuccess = 'Catatan teknisi berhasil disimpan';
  final defaultServiceNote = 'Servis selesai.';
  
  // Extra Wizard & Picker
  final addTechnician = 'Tambah Teknisi Baru';
  final catalogTitle = 'Katalog Item';
  final catalogSearchHint = 'Cari jasa atau barang...';
  final sectionService = 'Jasa & Servis';
  final sectionPart = 'Suku Cadang & Barang';
  final emptyItems = 'Belum ada item ditambahkan';
  final labelPlate = 'Plat Nomor';
  final labelCustomer = 'Pelanggan';
  final labelTechnician = 'Teknisi';
  final editBonusDesc = 'Tentukan jumlah bonus teknisi untuk item ini.';
  final bonusLabel = 'Jumlah Bonus (Rp)';
  final selectVehicle = 'Pilih Kendaraan';
  final selectCustomer = 'Pilih Pelanggan';
  final customerSearchHint = 'Cari nama, telp, atau plat nomor...';
  final noVehicle = 'Tidak ada kendaraan';
  final addItem = 'Tambah Item';
  final typeService = 'JASA';
  final typePart = 'PART';
  final addNewService = 'Tambah Jasa Baru';
  final addNewPart = 'Tambah Stok Baru';
  final searchServiceHint = 'Cari jasa servis...';
  final searchPartHint = 'Cari sparepart...';
  final pricePerUnit = 'Harga Satuan';
  final tooltipVehicleDb = 'Database Kendaraan';
  final tooltipScanPlate = 'Scan Plat';
  final tooltipSearchDb = 'Cari Database';
  final noOwner = 'Tanpa Owner';
  final subTotalItem = 'Sub Total Item';
  final paymentMethod = 'Metode Pembayaran';
  final requiredService = 'Wajib menambahkan minimal 1 layanan (jasa) dari inventaris.';
  
  // Categories Quick Add
  final catAki = 'Aki';
  final catOli = 'Oli';
  final catBan = 'Ban';
  final catKampas = 'Kampas';
  final catFilter = 'Filter';
  final catSuspensi = 'Suspensi';
  
  String editBonusTitle(String name) => 'edit Bonus: $name';
  
  // WhatsApp Receipt
  final whatsappReceiptHeader = 'NOTA PEMBAYARAN';
  final trxNumberLabel = 'No. Transaksi';
  final vehicleLabel = 'Kendaraan';
  final unitLabel = 'Unit'; // For PDF
  final detailLabel = 'Detail';
  final totalLabel = 'TOTAL';
  final techNotesLabelReceipt = 'Catatan Teknisi';
  final serviceDoneLabel = 'Servis selesai.';
  final recServiceLabel = 'Rekomendasi Servis Kembali';
  final recKmLabel = 'Setelah +';
  final recTimeLabel = 'Setelah +';
  final recDefaultLabel = 'Cek kembali 1 bulan/1000 KM.';
  final thankYouLabel = 'Terima kasih telah mempercayakan kendaraan Anda kepada kami!';
  final kmOrReminder = ' atau saat KM mencapai ';
}

class CustomerStrings {
  const CustomerStrings();
  final title = 'Daftar Pelanggan';
  final subtitle = 'Kelola data pelanggan dan mitra workshop Anda.';
  final searchHint = 'Cari nama atau telepon...';
  final emptyTitle = 'Belum Ada Pelanggan';
  final emptyMessage = 'Belum ada data pelanggan.';
  final noData = 'Belum ada pelanggan terdaftar';
  final addCustomer = 'Tambah Pelanggan';
  final newCustomer = 'Pelanggan Baru';
  final newSubtitle = 'Tambahkan mitra setia bisnismu di sini.';
  final editData = 'Ubah Data';
  final editSubtitle = 'Perbarui informasi mitra bisnismu.';
  final fullName = 'Nama Lengkap';
  final phoneLabel = 'Nomor Telepon/WA';
  final addressLabel = 'Alamat';
  final addressOptional = 'Alamat (Opsional)';
  final noteLabel = 'Catatan';
  final saveCustomer = 'Simpan Pelanggan';
  final vehicles = 'Kendaraan';
  final addVehicle = 'Tambah Kendaraan';
  final updateData = 'Perbarui Data';
  final vehicleModel = 'Model Kendaraan';
  final vehicleModelHint = 'Misal: Honda Vario 125';
  final plateNumber = 'Nomor Plat';
  final plateHint = 'B 1234 ABC';
  final invalidPlateFormat = 'Format tidak valid (cth: B 1234 ABC)';
  final year = 'Tahun';
  final color = 'Warna';
  final saveVehicle = 'Simpan Kendaraan';
  final motor = 'Motor';
  final mobil = 'Mobil';
  final visits = 'Kunjungan';
  final totalSpending = 'Total';
  final historyActivity = 'RIWAYAT AKTIVITAS';
  final noVehiclesReg = 'Belum ada kendaraan terdaftar';
  final noTransactionHistory = 'Belum ada riwayat transaksi';
  final deleteTitle = 'Hapus Pelanggan?';
  final confirmDeleteTitle = 'Hapus Pelanggan?';
  final confirmDeleteMessage =
      'Semua data kendaraan terkait akan tetap ada, namun relasi pelanggan akan terputus. Lanjutkan?';
  final changeProfilePhoto = 'Ubah Foto Profil';

  String ownedBy(String name) => 'Milik $name';

  String deleteConfirmation(String name) =>
      'Yakin ingin menghapus data $name? Tindakan ini tidak bisa dibatalkan.';
}

class HistoryStrings {
  const HistoryStrings();
  final title = 'Riwayat';
  final subtitle = 'Pantau riwayat aktivitas workshop Anda.';
  final searchHint = 'Cari riwayat transaksi...';
  final filterTitle = 'Filter Riwayat';
  final selectDate = 'Pilih Tanggal';
  final transactionType = 'Tipe Transaksi';
  final paymentMethod = 'Metode Pembayaran';
  final emptyMessage = 'Belum ada transaksi.';
  final notFoundMessage = 'Tidak ditemukan';
  final noTransactions = 'Belum ada transaksi.';
  final noResultsFound = 'Tidak ditemukan';
  final detailNotFound = 'Detail transaksi tidak ditemukan';
  final applyFilter = 'Terapkan Filter';
  final typeService = 'Servis';
  final typeProduct = 'Produk';
  final all = 'Semua';
  final cash = 'Tunai';
  final qris = 'QRIS';
  final transfer = 'Transfer';

  String noResultsFor(String query) => 'Tidak ditemukan "$query"';
}

class CatalogStrings {
  const CatalogStrings();
  final inventoryTitle = 'Inventaris';
  final inventorySubtitle = 'Kelola stok dan layanan jasa workshop Anda.';
  final headerEditBarang = 'Edit Inventaris';
  final headerAddBarang = 'Tambah Inventaris';
  final headerEditJasa = 'Edit Layanan';
  final headerAddJasa = 'Tambah Layanan';
  final headerHistory = 'Riwayat Inventaris';
  final subheaderEdit = 'PERBAIKI DATA';
  final subheaderAdd = 'TAMBAH DATA BARU';
  String subheaderHistory(String name) => 'Detail perubahan stok: $name';
  
  final searchBarang = 'Cari item inventaris...';
  final searchJasa = 'Cari layanan jasa...';
  final tooltipScanner = 'Pindai Barcode';
  final tooltipAutoGenerate = 'Auto Generate';
  final tooltipScanBarcode = 'Scan Barcode';
  
  final tabBarang = 'Barang';
  final tabJasa = 'Layanan Jasa';
  
  final emptyBarang = 'Belum ada item inventaris.';
  final emptyJasa = 'Belum ada data layanan jasa.';
  final emptyHistory = 'Belum ada riwayat stok';
  
  final sortAll = 'Semua';
  final sortLow = 'Stok Menipis';
  final sortHigh = 'Stok Melimpah';
  
  final statusOutOfStock = 'Stok Habis';
  final statusLowStock = 'Stok Rendah';
  final statusInStock = 'Stok Tersedia';
  final unitPcs = 'pcs';
  
  final labelItemName = 'Nama Barang';
  final labelCategory = 'Kategori Barang';
  final labelCategoryCaps = 'KATEGORI';
  
  final catSparepart = 'Sparepart';
  final catOli = 'Oli';
  final catBan = 'Ban';
  final catAksesoris = 'Aksesoris';
  final catLainnya = 'Lainnya';
  final catUmum = 'Umum';
  final labelSku = 'Kode SKU / Barcode';
  final labelSkuShort = 'SKU';
  final labelInitialStock = 'Stok Awal';
  final labelMinStock = 'Min. Stok';
  final labelStockCurrent = 'STOK SAAT INI';
  final skuPrefix = 'SKU-';
  final labelPurchasePrice = 'Harga Modal (Beli)';
  final labelSellingPrice = 'Harga Jual';
  final labelJasaName = 'Nama Jasa';
  final labelServicePrice = 'Harga Jasa';
  final labelServiceCategory = 'Kategori Layanan';
  final currencyIdr = 'IDR';
  final labelEditMode = 'EDIT MODE';
  final labelUploadPhoto = 'Unggah Foto';
  final labelSupplier = 'Nama Supplier / Pemasok';
  final hintSupplier = 'Misal: PT Astra, Gudang Ban...';
  
  final actionEdit = 'Ubah Data';
  final actionAddStock = 'Tambah Stok';
  final actionStockHistory = 'Riwayat Stok';
  final buttonSaveInventory = 'SIMPAN INVENTARIS';
  final buttonSaveChangeInventory = 'SIMPAN PERUBAHAN';
  final buttonSaveService = 'SIMPAN LAYANAN';
  final buttonSaveChangeService = 'SIMPAN PERUBAHAN';
  
  final historyInitial = 'Stok Awal';
  final historyRestock = 'Restock';
  final historySale = 'Penjualan';
  final historyAdjustment = 'Penyesuaian';
  
  final sortSupplier = 'Per Supplier';
  
  final bestSelling = 'Paling Laku';
  
  final dialogAddStockTitle = 'Tambah Stok';
  String dialogAddStockContent(String name) => 'Masukkan jumlah stok tambahan untuk $name:';
  final labelQuantity = 'Jumlah';
  
  final dialogDeleteTitleBarang = 'Hapus Barang?';
  final dialogDeleteTitleJasa = 'Hapus Jasa?';
  String dialogDeleteContentBarang(String name) => 'Apakah Anda yakin ingin menghapus $name dari inventaris?';
  String dialogDeleteContentJasa(String name) => 'Apakah Anda yakin ingin menghapus $name dari katalog?';
  
  final dialogDuplicateNameTitle = 'Nama Sudah Ada';
  final dialogDuplicateNameContent = 'Nama barang ini sudah ada di Katalog. Gunakan fitur \'Tambah Stok\' pada barang tersebut untuk menghindari data ganda.';
  final dialogDuplicateSkuTitle = 'Barang Terdaftar';
  String dialogDuplicateSkuContent(String name) => 'Barang dengan barcode/SKU ini sudah terdaftar sebagai "$name".\n\nApakah Anda ingin menambah stok atau mengubah data barang tersebut?';
  
  final dialogPickPhotoTitle = 'AMBIL FOTO BARANG';
  final snackbarStockAdded = 'Stok berhasil ditambah!';
  final noteDuplicateBarcode = 'Ditambahkan melalui input barang ganda dengan barcode sama';

  // Legacy/Retained items if any
  final lowStock = 'Stok Menipis';
  final stockValue = 'Nilai Stok';
  final addInventory = 'Tambah Barang';
  final salesLabel = 'Penjualan Barang';
  final overscrollNavHint = 'Geser pinggir layar atau tap tab untuk navigasi cepat antar menu.';
  final sectionItems = 'DAFTAR BARANG';
  final sectionCustomer = 'PELANGGAN (OPSIONAL)';
}

class SettingStrings {
  const SettingStrings();
  final title = 'Pengaturan';
  final workshopProfile = 'Profil Workshop';
  final syncData = 'Sinkronisasi Data';
  final backupRestore = 'Backup & Restore';
  final biometricSecurity = 'Keamanan Biometrik';
  final featureSettings = 'Pengaturan Fitur';
}

class ErrorStrings {
  const ErrorStrings();
  
  // Auth
  final biometricFailed = 'Autentikasi biometrik gagal';
  final pinIncorrect = 'PIN yang dimasukkan salah';
  final pinTooShort = 'PIN minimal 6 digit';
  final sessionExpired = 'Sesi berakhir. Silakan login kembali';
  final keyRecoveryFailed = 'Gagal memulihkan kunci dekripsi (Kunci tidak ditemukan atau data biometrik kedaluwarsa).';
  final failedToCheckId = 'Gagal memeriksa ketersediaan ID';
  final biometricRequired = 'Sidik jari/biometrik diperlukan';
  final pinInvalid = 'PIN harus 6 digit angka';
  final requiredField = 'Bagian ini wajib diisi';
  
  // Network
  final noConnection = 'Tidak ada koneksi internet';
  final syncFailed = 'Gagal menyinkronkan data';
  
  // Validation
  final plateRequired = 'Nomor plat harus diisi';
  final customerRequired = 'Nama pelanggan harus diisi';
  final phoneInvalid = 'Nomor HP tidak valid (minimal 8 digit)';
  final itemEmpty = 'Item servis masih kosong';
  final serviceRequired = 'Wajib menambahkan minimal 1 layanan (jasa)';
  final saveFailed = 'Gagal menyimpan';
  
  // Generic
  final generic = 'Terjadi kesalahan. Silakan coba lagi';
  String specific(String error) => 'Terjadi kesalahan: $error';
  String minChars(int count) => 'Minimal $count karakter';
  
  String stockInsufficient(String itemName, int available) => 
      'Stok $itemName tidak mencukupi. Tersedia: $available';

  final minStockOne = 'Minimum stok awal adalah 1';
  final minStockZero = 'Stok tidak boleh negatif';
}

class SuccessStrings {
  const SuccessStrings();
  
  final transactionCreated = 'Transaksi berhasil dibuat';
  final transactionUpdated = 'Transaksi berhasil diperbarui';
  final transactionDeleted = 'Transaksi berhasil dihapus';
  final backupCreated = 'Cadangan berhasil dibuat';
  final backupRestored = 'Data berhasil dipulihkan';
  final syncCompleted = 'Sinkronisasi selesai';
  final bengkelCreated = 'Bengkel berhasil didaftarkan';
}

class AccessStrings {
  const AccessStrings();
  final readOnlyMode = 'Mode Baca Saja';
  final restrictedAccess = 'Akses Terbatas';
  final sessionExpired = 'Sesi Kedaluwarsa';
  final readOnlyLabel = 'Baca Saja';
  final restrictedLabel = 'Akses Terbatas';
  final sessionExpiredLabel = 'Sesi Habis';
  final readOnlyDesc = 'Perangkat offline > 8 jam.\nAnda masih bisa melihat data, tapi tidak bisa mengedit sampai sesi diperbarui.';
  final restrictedDesc = 'Perangkat offline > 12 jam.\nFitur laporan keuangan dan edit biaya dibatasi sementara.';
  final sessionExpiredDesc = 'Sesi keamanan telah berakhir (offline > 24 jam).\nHubungkan internet untuk verifikasi ulang.';
  final understand = 'Mengerti';
}

class ReminderStrings {
  const ReminderStrings();
  final title = 'Pengingat Servis';
  final subtitle = 'Daftar pelanggan yang perlu segera dihubungi.';
  final emptyTitle = 'Belum Ada Pengingat';
  final emptyMessage = 'Pelanggan yang masuk masa servis akan muncul di sini.';
  final overdue = 'Terlambat Servis';
  final upcoming = 'Sudah Waktunya Servis';
  final estimateLabel = 'Estimasi:';
  final kmTargetLabel = 'KM Target:';
  final kmSuffix = ' KM';
}

class DatePatterns {
  const DatePatterns();
  final displayDate = 'dd MMM yyyy';
  final fullDateTime = 'EEEE, dd MMMM yyyy - HH:mm';
  final shortDate = 'dd/MM/yy';
  final dateTimeReceipt = 'dd/MM/yyyy HH:mm';
  final localeID = 'id_ID';
}

class WhatsAppTemplates {
  const WhatsAppTemplates();
  
  String serviceReminder({
    required String customerName,
    required String vehiclePlate,
    required String vehicleModel,
    required String bengkelName,
    required String dateStr,
    String? kmStr,
  }) => 
    'Halo kak *$customerName*, kami dari *$bengkelName*. 🛠️\n\n'
    'Ingin mengingatkan bahwa kendaraan *$vehicleModel* ($vehiclePlate) sudah memasuki waktu servis berkala berikutnya (estimasi sekitar tanggal $dateStr${kmStr ?? ""}).\n\n'
    'Yuk kak, jadwalkan servisnya agar kendaraan tetap prima dan nyaman dikendarai! Kami tunggu kedatangannya ya. 😊';
  
  final thankYou = 'Terima kasih telah mempercayakan kendaraan Anda kepada kami!';
}

class SyncStrings {
  const SyncStrings();

  final title = 'Sinkronisasi Cloud';
  final pending = 'Menunggu';
  final syncing = 'Menyinkronkan...';
  final synced = 'Sinkron';
  final failed = 'Gagal';

  final starting = 'Memulai sinkronisasi...';
  final idle = 'Siap';
  final anotherActive = 'Proses lain aktif, menunggu antrian...';
  final wifiOnlyNotice = 'Sinkronisasi tertunda (Hanya WiFi aktif)';
  final noConnection = 'Tidak ada koneksi internet';
  final success = 'Sinkronisasi berhasil';
  final error = 'Terjadi kesalahan sinkronisasi';

  // State labels for UI
  String statusLabel(String state) => switch (state.toLowerCase()) {
        'pending' => pending,
        'syncing' => syncing,
        'synced' => synced,
        'failed' => failed,
        _ => state,
      };
}

class NavStrings {
  const NavStrings();
  final home = 'Beranda';
  final inventory = 'Inventaris';
  final customers = 'Pelanggan';
  final history = 'Riwayat';
  final settings = 'Pengaturan';
  
  final createService = 'Buat Servis';
  final sellProduct = 'Jual Barang';
  final newCustomer = 'Pelanggan Baru';
  final addProduct = 'Tambah Barang';
}

class ProfileStrings {
  const ProfileStrings();
  final title = 'Profil & Bengkel';
  final subtitle = 'Ubah identitas bengkel dan kontak owner.';
  final workshopInfo = 'Informasi Bengkel';
  final workshopName = 'Nama Bengkel';
  final workshopAddress = 'Alamat Bengkel';
  final workshopWA = 'WhatsApp Bengkel';
  final ownerInfo = 'Informasi Owner';
  final ownerName = 'Nama Owner';
  final ownerPhone = 'Nomor HP Owner';
  final saveSuccess = 'Profil berhasil disimpan';
}

class SecurityStrings {
  const SecurityStrings();
  final title = 'Keamanan & Data';
  final subtitle = 'Pusat kendali keamanan, sinkronisasi cloud, dan otorisasi perangkat.';
  final shieldProtection = 'SHIELD PROTECTION';
  final autoLock30m = 'Auto-Lock 30 Menit';
  final autoLockDesc = 'Kunci aplikasi otomatis jika tidak digunakan.';
  final syncCloud = 'SINKRONISASI CLOUD';
  final lastSyncNever = 'Belum pernah sinkronisasi';
  final lastSyncJustNow = 'Baru saja diperbarui';
  String lastSyncMinutesAgo(int mins) => 'Update: $mins menit yang lalu';
  String lastSyncAt(String time) => 'Update: $time';
  
  final logoutConfirmTitle = 'Konfirmasi Keluar';
  final logoutConfirmMessage = 'Tindakan ini akan mengakhiri sesi aktif Anda di perangkat ini.';
}
class DataCenterStrings {
  const DataCenterStrings();
  final title = 'Pusat Data Bengkel';
  final subtitle = 'Simpan otomatis ke internet agar data tidak hilang.';
  final storageStatus = 'Status Penyimpanan';
  final workshopInfo = 'Informasi Bengkel';
  final maintenanceActions = 'Aksi Pemeliharaan';
  final workshopName = 'Nama Bengkel';
  final yourStatus = 'Status Anda';
  final bengkelId = 'Bengkel ID';
  final idCopied = 'Bengkel ID disalin ke clipboard';
  final connected = 'Sudah Terhubung';
  final notConnected = 'Belum Terhubung';
  final connectedDesc = 'Semua data bengkel Anda sudah aman di internet.';
  final notConnectedDesc = 'Hubungkan ke bengkel untuk mulai menyimpan data.';
  final sessionLocked = 'Sesi Terkunci';
  final sessionLockedDesc = 'Akses ditutup karena terlalu lama offline. Hubungkan internet segera.';
  final sessionRestricted = 'Sesi Terbatas';
  final sessionRestrictedDesc = 'Segera hubungkan internet untuk memulihkan akses penuh.';
  final perkuatKeamanan = 'Perkuat Keamanan Data';
  final perkuatKeamananDesc = 'Gunakan sistem pengunci terbaru agar data pelanggan lebih aman.';
  final pelindungData = 'Pelindung Data: Nama dan nomor HP pelanggan disandikan secara rahasia. Hanya Anda yang bisa membukanya.';
  final migrationTitle = 'Migrasi Data ke Cloud';
  final migrationDesc = 'Tindakan ini akan mengenkripsi dan mengunggah data lama Anda ke Firestore untuk pertama kali.\nPastikan Anda memiliki koneksi internet yang stabil.';
  final migrationAction = 'Migrasi Sekarang';
  final migrationSuccess = 'Migrasi Berhasil! Data Anda kini terenkripsi di Cloud.';
}

class StatsStrings {
  const StatsStrings();
  final title = 'Analisis Bisnis';
  final subtitle = 'Laporan performa bengkel secara real-time';
  final tabSummary = 'Ringkasan';
  final tabService = 'Layanan';
  final tabProduct = 'Produk';
  final tabExpense = 'Pengeluaran';
  final tabStaff = 'Teknisi';
  
  final totalRevenue = 'Total Pendapatan';
  final netProfit = 'Laba Bersih';
  final totalExpense = 'Total Pengeluaran';
  final dailyAvgExpense = 'Rata-rata Harian';
  final yesterdayExpense = 'Pengeluaran Kemarin';
  
  final revenueTrend = 'Tren Pendapatan';
  final expenseTrend = 'Tren Pengeluaran 7 Hari';
  final expenseAllocation = 'Alokasi Pengeluaran';
  final expenseDetailPerCategory = 'Detail per Kategori';
  
  final setMonthlyTarget = 'Atur Target Bulanan';
  final revenueTarget = 'Target Pendapatan (Rp)';
  final monthlyTarget = 'Target Pendapatan Bulanan';
  final sisaTarget = 'Sisa';
  final targetReached = 'Selamat! Target bulan ini sudah tercapai. 🎉';
  
  final cashFlowTracker = 'Pelacak Arus Kas';
  final cashFlowDescToday = 'Gunakan untuk mencocokkan uang fisik di laci.';
  final cashFlowDescAll = 'Ringkasan pemasukan berdasarkan metode bayar.';
  
  final trendInfo = 'Data grafik mencakup total transaksi servis dan penjualan yang telah berstatus lunas.';
  final noExpenseData = 'Belum ada data pengeluaran';
  
  final today = 'Hari Ini';
  final week = '7 Hari';
  final month = 'Bulan Ini';
}

