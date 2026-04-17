import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/atelier_header.dart';
import '../../domain/entities/sale.dart';
import '../../core/providers/stok_provider.dart';
import '../../core/providers/pelanggan_provider.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/pelanggan.dart';
import '../../core/providers/pengaturan_provider.dart';
import '../../core/widgets/barcode_scanner_dialog.dart';
import '../../core/widgets/the_ceremony_dialog.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class CreateSaleScreen extends ConsumerStatefulWidget {
  const CreateSaleScreen({super.key});

  @override
  ConsumerState<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _SelectedSaleItem {
  final Stok stok;
  int quantity;

  _SelectedSaleItem({required this.stok, int? qty}) : quantity = qty ?? 1;

  int get total => quantity * stok.hargaJual;
}

class _CreateSaleScreenState extends ConsumerState<CreateSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_SelectedSaleItem> _selectedItems = [];
  final _quickSearchController = TextEditingController();
  final _pelangganSearchController = TextEditingController();
  Pelanggan? _selectedPelanggan;

  bool _isLoading = false;

  @override
  void dispose() {
    _quickSearchController.dispose();
    _pelangganSearchController.dispose();
    super.dispose();
  }

  int get _totalAmount =>
      _selectedItems.fold(0, (sum, item) => sum + item.total);

  void _addItem(Stok stok) {
    if (stok.jumlah <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok "${stok.nama}" habis!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      final existingIndex = _selectedItems.indexWhere(
        (item) => item.stok.uuid == stok.uuid,
      );
      if (existingIndex != -1) {
        if (_selectedItems[existingIndex].quantity < stok.jumlah) {
          _selectedItems[existingIndex].quantity++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Batas stok "${stok.nama}" tercapai (${stok.jumlah})'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _selectedItems.add(_SelectedSaleItem(stok: stok));
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _selectedItems.removeAt(index));
  }

  void _incrementQty(int index) {
    final item = _selectedItems[index];
    if (item.quantity < item.stok.jumlah) {
      setState(() => item.quantity++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batas stok "${item.stok.nama}" tercapai (${item.stok.jumlah})'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _decrementQty(int index) {
    if (_selectedItems[index].quantity > 1) {
      setState(() => _selectedItems[index].quantity--);
    } else {
      _removeItem(index);
    }
  }

  Future<void> _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerDialog()),
    );
    if (result != null) {
      final stokList = ref.read(stokListProvider);
      try {
        final item = stokList.firstWhere((s) => s.sku == result);
        _addItem(item);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Barang dengan SKU "$result" tidak ditemukan!'),
            ),
          );
        }
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedItems.isNotEmpty && !_isLoading) {
      setState(() => _isLoading = true);

      try {
        final transactionId = const Uuid().v4();
        final List<Sale> salesToSave = [];

        // Verifikasi stok dan bangun daftar Sale
        for (var item in _selectedItems) {
          final latestStok = ref
              .read(stokListProvider)
              .firstWhere((s) => s.uuid == item.stok.uuid);

          if (item.quantity > latestStok.jumlah) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Stok "${latestStok.nama}" tidak mencukupi!'),
              ),
            );
            setState(() => _isLoading = false);
            return;
          }

          salesToSave.add(
            Sale(
              itemName: latestStok.nama,
              quantity: item.quantity,
              totalPrice: item.total,
              costPrice: latestStok.hargaBeli,
              customerName: _selectedPelanggan?.nama,
              transactionId: transactionId,
              // ✅ FIX #1: stokUuid di-set agar TheCeremonyDialog dapat
              // melakukan pengurangan stok secara atomic via ObjectBox transaction.
              stokUuid: latestStok.uuid,
            ),
          );
        }

        if (mounted) {
          setState(() => _isLoading = false);
          // TheCeremonyDialog menangani konfirmasi pembayaran +
          // addSalesWithFinalization() secara atomic (termasuk kurangi stok).
          final result = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => TheCeremonyDialog(sales: salesToSave),
          );

          if (result == true && mounted) {
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memproses penjualan: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stokList = ref.watch(stokListProvider);
    final pelangganList = ref.watch(pelangganListProvider);
    final barcodeEnabled = ref.watch(settingsProvider).barcodeEnabled;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAtelierHeaderSub(
            title: 'Jual Barang',
            subtitle: 'Penjualan cepat langsung dari stok.',
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    _buildSectionHeader('DAFTAR BARANG'),
                    const SizedBox(height: 8),
                    _buildQuickSearch(stokList),
                    const SizedBox(height: 12),
                    if (_selectedItems.isEmpty)
                      _buildEmptyListWidget(context, stokList, barcodeEnabled)
                    else ...[
                      ...List.generate(_selectedItems.length, (index) {
                        final item = _selectedItems[index];
                        return _buildItemTile(item, index);
                      }),
                      const SizedBox(height: 12),
                      _buildAddItemButton(context, stokList),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionHeader('PELANGGAN (OPSIONAL)'),
                    const SizedBox(height: 8),
                    _buildPelangganSearch(pelangganList),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: (_selectedItems.isEmpty || _isLoading)
                          ? null
                          : _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 64),
                        backgroundColor: AppColors.amethyst,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'PROSES JUAL (${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_totalAmount)})',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildQuickSearch(List<Stok> stokList) {
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<Stok>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Stok>.empty();
          }
          final query = textEditingValue.text.toLowerCase();
          return stokList.where(
            (s) =>
                s.nama.toLowerCase().contains(query) ||
                (s.sku?.toLowerCase().contains(query) ?? false),
          );
        },
        displayStringForOption: (Stok s) => s.nama,
        onSelected: (Stok s) {
          _addItem(s);
          _quickSearchController.clear();
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari & tambah barang cepat...',
              prefixIcon: const Icon(SolarIconsOutline.magnifier, size: 20),
              filled: true,
              fillColor: AppColors.amethyst.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.amethyst.withValues(alpha: 0.1),
                  ),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = options.elementAt(index);
                    return ListTile(
                      title: Text(
                        s.nama,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Stok: ${s.jumlah} • Rp ${NumberFormat.compact().format(s.hargaJual)}',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      ),
                      onTap: () => onSelected(s),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPelangganSearch(List<Pelanggan> list) {
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<Pelanggan>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Pelanggan>.empty();
          }
          final query = textEditingValue.text.toLowerCase();
          return list.where((p) => p.nama.toLowerCase().contains(query));
        },
        displayStringForOption: (Pelanggan p) => p.nama,
        onSelected: (Pelanggan p) {
          setState(() {
            _selectedPelanggan = p;
            _pelangganSearchController.text = p.nama;
          });
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          if (_selectedPelanggan != null && controller.text.isEmpty) {
            controller.text = _selectedPelanggan!.nama;
          }
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Cari pelanggan...',
              prefixIcon: const Icon(SolarIconsBold.userId, size: 20),
              suffixIcon: _selectedPelanggan != null
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      tooltip: 'Hapus',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedPelanggan = null;
                          controller.clear();
                        });
                      },
                    )
                  : IconButton(
                      icon: const Icon(
                        SolarIconsOutline.altArrowRight,
                        size: 18,
                      ),
                      tooltip: 'Pilih Pelanggan',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => _showPelangganPicker(context, list),
                    ),
              filled: true,
              fillColor: AppColors.amethyst.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: constraints.maxWidth,
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.amethyst.withValues(alpha: 0.1),
                  ),
                ),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final p = options.elementAt(index);
                    return ListTile(
                      title: Text(
                        p.nama,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        p.telepon,
                        style: GoogleFonts.plusJakartaSans(fontSize: 12),
                      ),
                      onTap: () => onSelected(p),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.amethyst.withValues(alpha: 0.05)),
      ),
      child: Column(children: children),
    );
  }

  void _showStokPicker(BuildContext context, List<Stok> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet(
        title: 'Pilih Barang',
        itemCount: list.length,
        itemBuilder: (context, index) {
          final s = list[index];
          return ListTile(
            title: Text(
              s.nama,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Stok: ${s.jumlah} | Rp ${s.hargaJual}',
              style: GoogleFonts.plusJakartaSans(),
            ),
            onTap: () {
              _addItem(s);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyListWidget(
    BuildContext context,
    List<Stok> list,
    bool barcodeEnabled,
  ) {
    return _buildFormCard(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.amethyst.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(SolarIconsBold.box, color: AppColors.amethyst),
          ),
          title: Text(
            'Pilih Barang dari Stok',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            'Cari di katalog',
            style: GoogleFonts.plusJakartaSans(),
          ),
          trailing: barcodeEnabled
              ? IconButton(
                  icon: const Icon(
                    SolarIconsOutline.scanner,
                    color: AppColors.amethyst,
                  ),
                  onPressed: _isLoading ? null : _openScanner,
                )
              : null,
          onTap: _isLoading ? null : () => _showStokPicker(context, list),
        ),
      ],
    );
  }

  Widget _buildItemTile(_SelectedSaleItem item, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _buildFormCard(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.stok.nama,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Harga: Rp ${item.stok.hargaJual}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => _decrementQty(index),
                  ),
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: Text(
                        '${item.quantity}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => _incrementQty(index),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: GoogleFonts.plusJakartaSans(color: Colors.grey),
              ),
              Text(
                'Rp ${item.total}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: AppColors.amethyst,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddItemButton(BuildContext context, List<Stok> list) {
    return InkWell(
      onTap: () => _showStokPicker(context, list),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.amethyst.withValues(alpha: 0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              SolarIconsOutline.addCircle,
              color: AppColors.amethyst,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'TAMBAH BARANG',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: AppColors.amethyst,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPelangganPicker(BuildContext context, List<Pelanggan> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PickerSheet(
        title: 'Pilih Pelanggan',
        itemCount: list.length,
        itemBuilder: (context, index) {
          final p = list[index];
          return ListTile(
            title: Text(
              p.nama,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(p.telepon, style: GoogleFonts.plusJakartaSans()),
            onTap: () {
              setState(() => _selectedPelanggan = p);
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const _PickerSheet({
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: itemCount == 0
                ? Center(
                    child: Text(
                      'Tidak ada data',
                      style: GoogleFonts.plusJakartaSans(),
                    ),
                  )
                : ListView.builder(
                    itemCount: itemCount,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemBuilder: itemBuilder,
                  ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.amethyst.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.amethyst, size: 20),
      ),
    );
  }
}
