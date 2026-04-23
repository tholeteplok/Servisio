import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:image_picker/image_picker.dart';
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
  late TextEditingController _supplierController;
  bool _isSaving = false;

  String? _imagePath;
  late String _selectedKategori;
  final List<String> _categories = [
    AppStrings.catalog.catSparepart,
    AppStrings.catalog.catOli,
    AppStrings.catalog.catBan,
    AppStrings.catalog.catAksesoris,
    AppStrings.catalog.catLainnya,
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
    _supplierController = TextEditingController(text: widget.itemToEdit?.supplierName);
    _imagePath = widget.itemToEdit?.photoLocalPath;
    _selectedKategori = widget.itemToEdit?.kategori ?? AppStrings.catalog.catSparepart;
  }

  @override
  void dispose() {
    _namaController.dispose();
    _skuController.dispose();
    _jumlahController.dispose();
    _hargaBeliController.dispose();
    _hargaJualController.dispose();
    _minStokController.dispose();
    _supplierController.dispose();
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
      final theme = Theme.of(context);
      ref
          .read(stokListProvider.notifier)
          .restock(
            existingToRestock.uuid,
            restockAmount,
            AppStrings.catalog.noteDuplicateBarcode,
          );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${existingToRestock.nama} ${AppStrings.catalog.snackbarStockAdded}',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.primary,
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
        supplierName: _supplierController.text.trim().isEmpty ? null : _supplierController.text.trim(),
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(SolarIconsBold.danger, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Text(
              AppStrings.catalog.dialogDuplicateNameTitle,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: Text(
          AppStrings.catalog.dialogDuplicateNameContent,
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.common.understand.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDuplicateSkuDialog(Stok existing) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          AppStrings.catalog.dialogDuplicateSkuTitle,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
        ),
        content: Text(
          AppStrings.catalog.dialogDuplicateSkuContent(existing.nama),
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.common.cancel.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              final amount = int.tryParse(_jumlahController.text) ?? 0;
              _proceedSave(existingToRestock: existing, restockAmount: amount);
            },
            child: Text(
              AppStrings.catalog.actionAddStock.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
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
              AppStrings.catalog.actionEdit.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
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
            title: isEdit ? AppStrings.catalog.headerEditBarang : AppStrings.catalog.headerAddBarang,
            subtitle: isEdit ? AppStrings.catalog.subheaderEdit : AppStrings.catalog.subheaderAdd,
            showBackButton: true,
            actions: [
              if (isEdit)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppStrings.catalog.labelEditMode,
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.colorScheme.onPrimary,
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
                                  color: theme.colorScheme.primary.withValues(
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
                                        Icon(
                                          SolarIconsOutline.camera,
                                          size: 40,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          AppStrings.catalog.labelUploadPhoto,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurfaceVariant,
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
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  SolarIconsBold.penNewSquare,
                                  color: theme.colorScheme.onPrimary,
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
                          decoration: InputDecoration(
                            labelText: AppStrings.catalog.labelItemName,
                            prefixIcon: const Icon(SolarIconsOutline.box),
                          ),
                          validator: (v) =>
                              v?.isEmpty ?? true ? AppStrings.common.requiredField : null,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          AppStrings.catalog.labelCategory,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurfaceVariant,
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
                                        ? theme.colorScheme.primary
                                        : theme.cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
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
                                          ? theme.colorScheme.onPrimary
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
                            labelText: AppStrings.catalog.labelSku,
                            prefixIcon: const Icon(SolarIconsOutline.scanner),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    SolarIconsOutline.magicStick,
                                    color: theme.colorScheme.primary,
                                  ),
                                  onPressed: _autoGenerateSku,
                                  tooltip: AppStrings.catalog.tooltipAutoGenerate,
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size(48, 48),
                                  ),
                                ),
                                if (barcodeEnabled)
                                  IconButton(
                                    icon: Icon(
                                      SolarIconsOutline.scanner,
                                      color: theme.colorScheme.primary,
                                    ),
                                    onPressed: _openScanner,
                                    tooltip: AppStrings.catalog.tooltipScanBarcode,
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
                    _buildFormCard(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) => Autocomplete<String>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final suggestions = ref
                                  .read(stokRepositoryProvider)
                                  .getUniqueSuppliers();
                              if (textEditingValue.text.isEmpty) {
                                return suggestions;
                              }
                              return suggestions.where((String option) {
                                return option.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase(),
                                    );
                              });
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, onFieldSubmitted) {
                              // Sync with our main controller
                              if (controller.text != _supplierController.text) {
                                controller.text = _supplierController.text;
                              }
                              controller.addListener(() {
                                _supplierController.text = controller.text;
                              });

                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  labelText: AppStrings.catalog.labelSupplier,
                                  hintText: AppStrings.catalog.hintSupplier,
                                  prefixIcon:
                                      const Icon(SolarIconsOutline.delivery),
                                ),
                                onFieldSubmitted: (v) => onFieldSubmitted(),
                              );
                            },
                            onSelected: (String selection) {
                              _supplierController.text = selection;
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4.0,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: constraints.maxWidth,
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (BuildContext context, int index) {
                                        final String option = options.elementAt(index);
                                        return ListTile(
                                          title: Text(
                                            option,
                                            style: GoogleFonts.plusJakartaSans(),
                                          ),
                                          onTap: () => onSelected(option),
                                        );
                                      },
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
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _jumlahController,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                ),
                                decoration: InputDecoration(
                                  labelText: AppStrings.catalog.labelInitialStock,
                                  suffixText: AppStrings.catalog.unitPcs,
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
                                decoration: InputDecoration(
                                  labelText: AppStrings.catalog.labelMinStock,
                                  suffixText: AppStrings.catalog.unitPcs,
                                ),
                                validator: (v) {
                                  if (v?.isEmpty ?? true) return null;
                                  final n = int.tryParse(v!) ?? 0;
                                  if (n < 0) return AppStrings.error.minStockZero;
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
                          decoration: InputDecoration(
                            labelText: AppStrings.catalog.labelPurchasePrice,
                            prefixIcon: const Icon(SolarIconsOutline.wallet),
                            suffixText: AppStrings.catalog.currencyIdr,
                          ),
                          validator: (v) {
                            if (v?.isEmpty ?? true) return null;
                            final n = int.tryParse(v!) ?? 0;
                            if (n < 0) return AppStrings.error.minStockZero;
                            return null;
                          },
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _hargaJualController,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          decoration: InputDecoration(
                            labelText: AppStrings.catalog.labelSellingPrice,
                            prefixIcon: const Icon(SolarIconsOutline.wadOfMoney),
                            suffixText: AppStrings.catalog.currencyIdr,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v?.isEmpty ?? true) return AppStrings.common.requiredField;
                            final jual = int.tryParse(v!) ?? 0;
                            if (jual < 0) return AppStrings.error.minStockZero;
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
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 8,
                        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                                strokeWidth: 2,
                              ),
                            )
                            : Text(
                                isEdit
                                    ? AppStrings.catalog.buttonSaveChangeInventory
                                    : AppStrings.catalog.buttonSaveInventory,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  color: theme.colorScheme.onPrimary,
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
    final theme = Theme.of(context);
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
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.catalog.dialogPickPhotoTitle,
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
                  label: AppStrings.common.camera,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(true);
                  },
                ),
                const SizedBox(width: 16),
                _buildSourceOption(
                  icon: SolarIconsOutline.gallery,
                  label: AppStrings.common.gallery,
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
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 32),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
