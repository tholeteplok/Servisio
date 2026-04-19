import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/atelier_header.dart';
import '../../domain/entities/stok.dart';
import '../../core/providers/stok_provider.dart';
import '../../core/providers/media_provider.dart';
import '../../core/providers/pengaturan_provider.dart';
import '../../core/widgets/barcode_scanner_dialog.dart';

class CreateBarangScreen extends ConsumerStatefulWidget {
  final Stok? itemToEdit;
  final String? initialName;
  const CreateBarangScreen({super.key, this.itemToEdit, this.initialName});

  @override
  ConsumerState<CreateBarangScreen> createState() => _CreateBarangScreenState();
}

class _CreateBarangScreenState extends ConsumerState<CreateBarangScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _skuController;
  late TextEditingController _jumlahController;
  late TextEditingController _hargaBeliController;
  late TextEditingController _hargaJualController;
  late TextEditingController _minStokController;
  bool _isSaving = false;

  String? _imagePath;
  late String _selectedKategori;
  final List<String> _categories = [
    'Sparepart',
    'Oli',
    'Ban',
    'Aksesoris',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(
      text: widget.itemToEdit?.nama ?? widget.initialName,
    );
    _skuController = TextEditingController(text: widget.itemToEdit?.sku);
    _jumlahController = TextEditingController(
      text: widget.itemToEdit?.jumlah.toString() ?? '1',
    );
    _hargaBeliController = TextEditingController(
      text: widget.itemToEdit?.hargaBeli.toString() ?? '0',
    );
    _hargaJualController = TextEditingController(
      text: widget.itemToEdit?.hargaJual.toString() ?? '0',
    );
    _minStokController = TextEditingController(
      text: widget.itemToEdit?.minStok.toString() ?? '5',
    );
    _imagePath = widget.itemToEdit?.photoLocalPath;
    _selectedKategori = widget.itemToEdit?.kategori ?? 'Sparepart';
  }

  @override
  void dispose() {
    _namaController.dispose();
    _skuController.dispose();
    _jumlahController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _minStokController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool fromCamera) async {
    final mediaService = ref.read(mediaServiceProvider);
    final image = fromCamera
        ? await mediaService.pickImage(ImageSource.camera)
        : await mediaService.pickImage(ImageSource.gallery);

    if (image != null) {
      final localPath = await mediaService.saveImageLocally(image);
      if (localPath != null) {
        setState(() => _imagePath = localPath);
      }
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerDialog()),
    );
    if (result != null) {
      _skuController.text = result;
    }
  }

  void _autoGenerateSku() {
    final prefix = _selectedKategori
        .substring(0, min(3, _selectedKategori.length))
        .toUpperCase();
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    setState(() {
      _skuController.text = '$prefix-$random';
    });
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      final inputNama = _namaController.text.trim();
      final inputSku = _skuController.text.trim();
      final currentStokList = ref.read(stokListProvider);

      Stok? nameDuplicate;
      Stok? skuDuplicate;

      for (final item in currentStokList) {
        if (widget.itemToEdit != null && item.uuid == widget.itemToEdit!.uuid) {
          continue;
        }
        if (item.nama.toLowerCase() == inputNama.toLowerCase()) {
          nameDuplicate = item;
          break;
        }
        if (inputSku.isNotEmpty && item.sku == inputSku) {
          skuDuplicate = item;
        }
      }

      if (nameDuplicate != null) {
        _showDuplicateNameError();
        return;
      }
      if (skuDuplicate != null) {
        _showDuplicateSkuDialog(skuDuplicate);
        return;
      }
      _proceedSave();
    }
  }

  void _proceedSave({Stok? existingToRestock, int? restockAmount}) async {
    if (existingToRestock != null && restockAmount != null) {
      ref
          .read(stokListProvider.notifier)
          .restock(
            existingToRestock.uuid,
            restockAmount,
            'Ditambahkan melalui input barang ganda dengan barcode sama',
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok ${existingToRestock.nama} berhasil ditambah!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.amethyst,
        ),
      );
      if (mounted) Navigator.pop(context);
    } else {
      final stok = Stok(
        nama: _namaController.text.trim(),
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        jumlah: int.tryParse(_jumlahController.text) ?? 0,
        hargaBeli: int.tryParse(_hargaBeliController.text) ?? 0,
        hargaJual: int.tryParse(_hargaJualController.text) ?? 0,
        minStok: int.tryParse(_minStokController.text) ?? 5,
        kategori: _selectedKategori,
      );
      stok.photoLocalPath = _imagePath;

      if (widget.itemToEdit != null) {
        stok.id = widget.itemToEdit!.id;
        stok.uuid = widget.itemToEdit!.uuid;
        ref.read(stokListProvider.notifier).updateItem(stok);
      } else {
        ref.read(stokListProvider.notifier).addItem(stok);
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.pop(context);
      }
    }
  }

  void _showDuplicateNameError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(SolarIconsBold.danger, color: Colors.red),
            const SizedBox(width: 12),
            Text(
              'Nama Sudah Ada',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          'Nama barang ini sudah ada di Katalog. Gunakan fitur \'Tambah Stok\' pada barang tersebut untuk menghindari data ganda.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'MENGERTI',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: AppColors.amethyst,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDuplicateSkuDialog(Stok existing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          'Barang Terdaftar',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
        ),
        content: Text(
          'Barang dengan barcode/SKU ini sudah terdaftar sebagai "${existing.nama}".\n\nApakah Anda ingin menambah stok atau mengubah data barang tersebut?',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'BATAL',
              style: GoogleFonts.plusJakartaSans(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final amount = int.tryParse(_jumlahController.text) ?? 0;
              _proceedSave(existingToRestock: existing, restockAmount: amount);
            },
            child: Text(
              'TAMBAH STOK',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateBarangScreen(itemToEdit: existing),
                ),
              );
            },
            child: Text(
              'UBAH DATA',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: AppColors.amethyst,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final barcodeEnabled = ref.watch(settingsProvider).barcodeEnabled;
    final theme = Theme.of(context);
    final isEdit = widget.itemToEdit != null;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAtelierHeaderSub(
            title: isEdit ? 'Edit Inventaris' : 'Tambah Inventaris',
            subtitle: isEdit ? 'PERBAIKI DATA' : 'TAMBAH DATA BARU',
            showBackButton: true,
            actions: [
              if (isEdit)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'EDIT MODE',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _showImageSourceActionSheet(context),
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: theme.cardColor,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: AppColors.amethyst.withValues(
                                    alpha: 0.1,
                                  ),
                                  width: 2,
                                ),
                                image: _imagePath != null
                                    ? DecorationImage(
                                        image: FileImage(File(_imagePath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _imagePath == null
                                  ? Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          SolarIconsOutline.camera,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Unggah Foto',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => _showImageSourceActionSheet(context),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: AppColors.amethyst,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  SolarIconsBold.penNewSquare,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    _buildFormCard(
                      children: [
                        TextFormField(
                          controller: _namaController,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Barang',
                            prefixIcon: Icon(SolarIconsOutline.box),
                          ),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Wajib diisi' : null,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Kategori Barang',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              final isSelected = _selectedKategori == cat;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedKategori = cat),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.amethyst
                                        : theme.cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.amethyst
                                          : theme.dividerColor,
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : theme.textTheme.bodyMedium?.color,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildFormCard(
                      children: [
                        TextFormField(
                          controller: _skuController,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                          ),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9-]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Kode SKU / Barcode',
                            prefixIcon: const Icon(SolarIconsOutline.scanner),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    SolarIconsOutline.magicStick,
                                    color: AppColors.amethyst,
                                  ),
                                  onPressed: _autoGenerateSku,
                                  tooltip: 'Auto Generate',
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                ),
                                if (barcodeEnabled)
                                  IconButton(
                                    icon: const Icon(
                                      SolarIconsOutline.scanner,
                                      color: AppColors.amethyst,
                                    ),
                                    onPressed: _openScanner,
                                    tooltip: 'Scan Barcode',
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildFormCard(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _jumlahController,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Stok Awal',
                                  suffixText: 'pcs',
                                ),
                                validator: (v) {
                                  if (v?.isEmpty ?? true) return null;
                                  final n = int.tryParse(v!) ?? 0;
                                  if (isEdit) {
                                    if (n < 0) return AppStrings.error.minStockZero;
                                  } else {
                                    if (n < 1) return AppStrings.error.minStockOne;
                                  }
                                  return null;
                                },
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _minStokController,
                                style: GoogleFonts.plusJakartaSans(),
                                decoration: const InputDecoration(
                                  labelText: 'Min. Stok',
                                  suffixText: 'pcs',
                                ),
                                validator: (v) {
                                  if (v?.isEmpty ?? true) return null;
                                  final n = int.tryParse(v!) ?? 0;
                                  if (n < 0) return 'Min. stok tidak boleh negatif';
                                  return null;
                                },
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),
                        TextFormField(
                          controller: _hargaBeliController,
                          style: GoogleFonts.plusJakartaSans(),
                          decoration: const InputDecoration(
                            labelText: 'Harga Modal (Beli)',
                            prefixIcon: Icon(SolarIconsOutline.wallet),
                            suffixText: 'IDR',
                          ),
                          validator: (v) {
                            if (v?.isEmpty ?? true) return null;
                            final n = int.tryParse(v!) ?? 0;
                            if (n < 0) return 'Harga tidak boleh negatif';
                            return null;
                          },
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _hargaJualController,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: AppColors.amethyst,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Harga Jual',
                            prefixIcon: Icon(SolarIconsOutline.wadOfMoney),
                            suffixText: 'IDR',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.isEmpty ?? true) return 'Wajib diisi';
                            final jual = int.tryParse(v!) ?? 0;
                            if (jual < 0) return 'Harga tidak boleh negatif';
                            final beli =
                                int.tryParse(_hargaBeliController.text) ?? 0;
                            if (jual < beli) {
                              return 'Harga jual tidak boleh di bawah harga modal';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 68),
                        backgroundColor: AppColors.amethyst,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 8,
                        shadowColor: AppColors.amethyst.withValues(alpha: 0.4),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN INVENTARIS',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AMBIL FOTO BARANG',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildSourceOption(
                  icon: SolarIconsOutline.camera,
                  label: 'Kamera',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(true);
                  },
                ),
                const SizedBox(width: 16),
                _buildSourceOption(
                  icon: SolarIconsOutline.gallery,
                  label: 'Galeri',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(false);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.amethyst.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.amethyst, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.amethyst.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
