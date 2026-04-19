import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/master_providers.dart';
import '../../core/providers/stok_provider.dart';
import '../../core/providers/pelanggan_provider.dart';
import '../../core/services/vehicle_data_service.dart';
import '../../domain/entities/transaction.dart' as entity;
import '../../domain/entities/pelanggan.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/staff.dart';
import '../../domain/entities/service_master.dart';
import '../../domain/entities/stok.dart';
import '../../domain/entities/transaction_item.dart';
import '../../core/widgets/barcode_scanner_dialog.dart';
import '../../core/widgets/step_indicator.dart';
import '../../core/utils/phone_formatter.dart';
import '../../core/utils/license_plate_formatter.dart';
import '../katalog/create_service_master_screen.dart';
import '../katalog/create_barang_screen.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  final entity.Transaction? initialTransaction;
  final Pelanggan? initialPelanggan;
  final Vehicle? initialVehicle;

  const CreateTransactionScreen({
    super.key,
    this.initialTransaction,
    this.initialPelanggan,
    this.initialVehicle,
  });

  @override
  ConsumerState<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState
    extends ConsumerState<CreateTransactionScreen> {

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _complaintController = TextEditingController();
  final _mechanicNotesController = TextEditingController();
  final _recommendationKmController = TextEditingController();
  final _currentOdometerController = TextEditingController();
  final _quickSearchController = TextEditingController();

  String? _localPhotoPath;
  int? _selectedRecommendationTime;
  bool _isProcessing = false;

  // WIZARD STATE
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final List<String> _stepLabels = [
    AppStrings.transaction.stepUnit,
    AppStrings.transaction.stepDiagnosa,
    AppStrings.transaction.stepPekerjaan,
    AppStrings.transaction.stepRingkasan,
  ];


  VehicleCategory _selectedVehicleCategory = VehicleCategory.motor;

  Pelanggan? _selectedPelanggan;
  Vehicle? _selectedVehicle;
  Staff? _selectedMechanic;
  final List<TransactionItem> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialTransaction != null) {
      final trx = widget.initialTransaction!;
      _customerNameController.text = trx.customerName;
      _customerPhoneController.text = trx.customerPhone;
      _customerAddressController.text = trx.pelanggan.target?.alamat ?? '';
      _vehicleModelController.text = trx.vehicleModel;
      _vehiclePlateController.text = trx.vehiclePlate;
      _vehicleYearController.text = trx.vehicle.target?.year?.toString() ?? '';
      _vehicleColorController.text = trx.vehicle.target?.color ?? '';
      _complaintController.text = trx.complaint ?? '';
      _mechanicNotesController.text = trx.mechanicNotes ?? ''; // UX-10 FIX
      _recommendationKmController.text = trx.recommendationKm?.toString() ?? '';
      _currentOdometerController.text = trx.odometer?.toString() ?? '';
      _selectedRecommendationTime = trx.recommendationTimeMonth;
      _localPhotoPath = trx.photoLocalPath;

      final typeStr = trx.vehicle.target?.type ?? VehicleCategory.motor.name;
      _selectedVehicleCategory = VehicleCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
        orElse: () => VehicleCategory.motor,
      );
      _selectedPelanggan = trx.pelanggan.target;
      _selectedVehicle = trx.vehicle.target;
      _selectedMechanic = trx.mechanic.target;
      _selectedItems.addAll(trx.items);
    } else {
      // Pre-fill from optional params
      if (widget.initialPelanggan != null) {
        _selectedPelanggan = widget.initialPelanggan;
        _customerNameController.text = _selectedPelanggan!.nama;
        _customerPhoneController.text = _selectedPelanggan!.telepon;
        _customerAddressController.text = _selectedPelanggan!.alamat;
      }
      if (widget.initialVehicle != null) {
        _selectedVehicle = widget.initialVehicle;
        _vehiclePlateController.text = _selectedVehicle!.plate;
        _vehicleModelController.text = _selectedVehicle!.model;
        _vehicleYearController.text = _selectedVehicle!.year?.toString() ?? '';
        _vehicleColorController.text = _selectedVehicle!.color ?? '';

        final typeStr = _selectedVehicle!.type;
        _selectedVehicleCategory = VehicleCategory.values.firstWhere(
          (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
          orElse: () => VehicleCategory.motor,
        );
      }
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _complaintController.dispose();
    _mechanicNotesController.dispose();
    _recommendationKmController.dispose();
    _currentOdometerController.dispose();
    _customerAddressController.dispose();
    _quickSearchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  int get _totalAmount =>
      _selectedItems.fold(0, (sum, item) => sum + item.subtotal);

  bool get isHeaderInfoLocked => widget.initialTransaction != null;

  // --- NAVIGATION ---
  void _nextStep() {
    if (_currentStep < _stepLabels.length - 1) {
      if (_currentStep == 0) {
        // UX-01 FIX: Jika pelanggan dipilih dari picker, pastikan data
        // phone & address sudah ter-copy ke controller sebelum validasi.
        if (_selectedPelanggan != null) {
          if (_customerPhoneController.text.isEmpty) {
            _customerPhoneController.text = _selectedPelanggan!.telepon;
          }
          if (_customerAddressController.text.isEmpty) {
            _customerAddressController.text = _selectedPelanggan!.alamat;
          }
        }

        if (_vehiclePlateController.text.isEmpty ||
            _customerNameController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.error.itemEmpty)),
          );
          return;
        }
 
        // UX-01 FIX: Validasi nomor HP minimal 8 digit
        final phone = _customerPhoneController.text.trim();
        if (phone.isNotEmpty && phone.replaceAll(RegExp(r'\D'), '').length < 8) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.error.phoneInvalid)),
          );
          return;
        }
      }

      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // UX-06 FIX: Pantau state TransactionList dan tampilkan error ke user
    // jika finalize/add gagal (misal stok tidak cukup). Tanpa ini, AsyncError
    // diam-diam diabaikan dan user tidak tahu operasinya gagal.
    ref.listen<AsyncValue<List<dynamic>>>(
      transactionListProvider,
      (_, next) {
        next.whenOrNull(
          error: (e, _) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e.toString().replaceAll('Exception: ', ''),
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red.shade700,
                duration: const Duration(seconds: 4),
              ),
            );
          },
        );
      },
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0E) : const Color(0xFFF8F9FE),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStepUnit(),
                _buildStepDiagnosa(),
                _buildStepPekerjaan(),
                _buildStepRingkasan(),
              ],
            ),
          ),
          Visibility(
            visible: MediaQuery.of(context).viewInsets.bottom == 0,
            child: _buildBottomNav(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 24,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(SolarIconsOutline.altArrowLeft),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.amethyst.withValues(alpha: 0.08),
                  foregroundColor: AppColors.amethyst,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.initialTransaction == null
                        ? AppStrings.transaction.newTransaction
                        : AppStrings.transaction.editTransaction,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    _stepLabels[_currentStep],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.amethyst,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          StepIndicator(
            currentStep: _currentStep,
            totalSteps: _stepLabels.length,
            stepLabels: _stepLabels,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 20,
            offset: const Offset(0, -8),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.amethyst.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 60),
                  side: BorderSide(
                    color: isDark ? Colors.white12 : AppColors.amethyst.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(AppStrings.common.back),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _currentStep == _stepLabels.length - 1
                  ? (_isProcessing ? null : _submit)
                  : _nextStep,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 60),
                backgroundColor: AppColors.amethyst,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _currentStep == _stepLabels.length - 1
                          ? AppStrings.transaction.saveTransaction
                          : AppStrings.transaction.next,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ),
        ],
      ),
    );
  }



  // --- STEP 1: UNIT & CUSTOMER ---
  Widget _buildStepUnit() {
    final customers = ref.watch(pelangganListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            AppStrings.transaction.unitInfo,
            AppStrings.transaction.unitInfoDesc,
          ),
          _buildFieldCard(
            child: Column(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => Autocomplete<Vehicle>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Vehicle>.empty();
                      }
                      final allVehicles = ref.read(vehicleListProvider).valueOrNull ?? [];
                      return allVehicles.where((v) =>
                          v.plate.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (Vehicle selection) {
                      setState(() {
                        _selectedVehicle = selection;
                        _vehiclePlateController.text = selection.plate;
                        _onPlateChanged(selection.plate); // Trigger autofill logic
                      });
                    },
                    fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                      if (ctrl.text.isEmpty && _vehiclePlateController.text.isNotEmpty) {
                        ctrl.text = _vehiclePlateController.text;
                      }
                      ctrl.addListener(() {
                        if (_vehiclePlateController.text != ctrl.text) {
                          _vehiclePlateController.text = ctrl.text;
                          _onPlateChanged(ctrl.text);
                        }
                      });

                      return TextFormField(
                        controller: ctrl,
                        focusNode: focus,
                        enabled: !isHeaderInfoLocked,
                        textCapitalization: TextCapitalization.characters,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                        inputFormatters: [
                          IndonesianLicensePlateFormatter(),
                        ],
                        decoration: InputDecoration(
                          labelText: AppStrings.transaction.plateNumber,
                          prefixIcon: const Icon(SolarIconsOutline.mapArrowSquare),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  final vehicles = ref.read(vehicleListProvider).valueOrNull ?? [];
                                  _showVehiclePicker(context, vehicles);
                                },
                                icon: const Icon(SolarIconsOutline.magnifier),
                                tooltip: AppStrings.transaction.tooltipVehicleDb,
                              ),
                              IconButton(
                                onPressed: _openPlateScanner,
                                icon: const Icon(SolarIconsOutline.scanner),
                                tooltip: AppStrings.transaction.tooltipScanPlate,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) =>
                        _buildAutocompleteOptions<Vehicle>(
                      context: context,
                      onSelected: onSelected,
                      options: options,
                      constraints: constraints,
                      titleBuilder: (v) => v.plate,
                      subtitleBuilder: (v) => '${v.model} - ${v.owner.target?.nama ?? AppStrings.transaction.noOwner}',
                      typedValue: _vehiclePlateController.text,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTypeSelector(),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) => Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return VehicleDataService.getSuggestions(
                        textEditingValue.text,
                        _selectedVehicleCategory,
                      );
                    },
                    onSelected: (String selection) {
                      _vehicleModelController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (controller.text.isEmpty && _vehicleModelController.text.isNotEmpty) {
                        controller.text = _vehicleModelController.text;
                      }
                      controller.addListener(() {
                        _vehicleModelController.text = controller.text;
                      });

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        enabled: !isHeaderInfoLocked,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: AppStrings.transaction.vehicleModel,
                          hintText: AppStrings.transaction.vehicleModelHint,
                          prefixIcon: Icon(
                            _selectedVehicleCategory == VehicleCategory.mobil ? AppIcons.car : AppIcons.motorcycle,
                          ),
                        ),
                        onFieldSubmitted: (v) => onFieldSubmitted(),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) => _buildAutocompleteOptions<String>(
                      context: context,
                      onSelected: onSelected,
                      options: options,
                      constraints: constraints,
                      titleBuilder: (s) => s,
                      typedValue: _vehicleModelController.text,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _vehicleYearController,
                        enabled: !isHeaderInfoLocked,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tahun',
                          prefixIcon: Icon(SolarIconsOutline.calendarMinimalistic),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _vehicleColorController,
                        enabled: !isHeaderInfoLocked,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: AppStrings.transaction.color,
                          prefixIcon: const Icon(LucideIcons.palette),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildStepHeader(
            AppStrings.transaction.customerInfo,
            AppStrings.transaction.customerInfoDesc,
          ),
          const SizedBox(height: 16),
          _buildFieldCard(
            child: Column(
              children: [
                Autocomplete<Pelanggan>(
                  initialValue: TextEditingValue(text: _customerNameController.text),
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Pelanggan>.empty();
                    }
                    return customers.where((p) => p.nama
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (p) => setState(() {
                    _selectedPelanggan = p;
                    _customerNameController.text = p.nama;
                    _customerPhoneController.text = p.telepon;
                    _customerAddressController.text = p.alamat;
                    _autoFillVehicle(p);
                  }),
                  fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                    ctrl.text = _customerNameController.text;
                    return TextFormField(
                      controller: ctrl,
                      focusNode: focus,
                      enabled: !isHeaderInfoLocked,
                      onChanged: (v) => _customerNameController.text = v,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: AppStrings.transaction.customerName,
                        prefixIcon: const Icon(SolarIconsOutline.user),
                        suffixIcon: IconButton(
                          onPressed: () {
                             final list = ref.read(pelangganListProvider);
                             _showPelangganPicker(list);
                          },
                          icon: const Icon(SolarIconsOutline.magnifier),
                          tooltip: AppStrings.transaction.tooltipSearchDb,
                        ),
                      ),
                    );
                  },
                  optionsViewBuilder: (ctx, onSelected, options) =>
                      _buildAutocompleteOptions<Pelanggan>(
                    context: context,
                    onSelected: onSelected,
                    options: options,
                    constraints: const BoxConstraints(maxWidth: 300),
                    titleBuilder: (p) => p.nama,
                    subtitleBuilder: (p) => p.telepon,
                    typedValue: _customerNameController.text,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _customerPhoneController,
                  enabled: !isHeaderInfoLocked,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [IndonesianPhoneFormatter()],
                  decoration: InputDecoration(
                    labelText: AppStrings.transaction.phoneNumber,
                    prefixIcon: const Icon(SolarIconsOutline.phoneCalling),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _customerAddressController,
                  enabled: !isHeaderInfoLocked,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: AppStrings.transaction.address,
                    hintText: AppStrings.transaction.addressHint,
                    prefixIcon: const Icon(SolarIconsOutline.mapPoint),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- STEP 2: DIAGNOSA & FOTO ---
  Widget _buildStepDiagnosa() {
    final staffAsync = ref.watch(staffListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStepHeader(
            AppStrings.transaction.complaint,
            '',
          ),
          const SizedBox(height: 24),
          _buildFieldCard(
            child: TextFormField(
              controller: _complaintController,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: AppStrings.transaction.complaint,
                hintText: 'Misal: Ganti Oli, CVT kasar',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildFieldCard(
            child: Row(
              children: [
                const Icon(SolarIconsOutline.camera, color: AppColors.amethyst),
                const SizedBox(width: 12),
                Text(
                  AppStrings.transaction.addPhoto,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(SolarIconsOutline.addCircle, color: AppColors.amethyst),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStepHeader(
            AppStrings.transaction.sparepartOptional,
            AppStrings.transaction.sparepartDesc,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryItem('Aki', SolarIconsOutline.batteryCharge),
                _buildCategoryItem('Oli', SolarIconsOutline.bottle),
                _buildCategoryItem('Ban', SolarIconsOutline.wheel),
                _buildCategoryItem('Kampas', SolarIconsOutline.stopCircle),
                _buildCategoryItem('Filter', SolarIconsOutline.filter),
                _buildCategoryItem('Suspensi', SolarIconsOutline.widget),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStepHeader(
            'Teknisi Penanggung Jawab',
            'Pilih teknisi yang akan mengerjakan unit ini.',
          ),
          const SizedBox(height: 16),
          _buildFieldCard(
            child: Row(
              children: [
                Expanded(
                  child: ActionChip(
                    avatar: _selectedMechanic == null
                        ? null
                        : CircleAvatar(
                            backgroundColor: AppColors.amethyst,
                            child: Text(
                              _selectedMechanic!.name[0],
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                    label: Text(_selectedMechanic?.name ?? 'Pilih Teknisi'),
                    onPressed: () => _showStaffPicker(context, staffAsync.value ?? []),
                    backgroundColor: AppColors.amethyst.withValues(alpha: 0.1),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: () => _showQuickAddStaff(context),
                  icon: const Icon(LucideIcons.plus, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.amethyst.withValues(alpha: 0.05),
                    foregroundColor: AppColors.amethyst,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickAddStaff(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TAMBAH TEKNISI BARU',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(LucideIcons.user),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP',
                  prefixIcon: Icon(LucideIcons.phone),
                  hintText: '628...',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [IndonesianPhoneFormatter()],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    if (nameCtrl.text.isEmpty) return;
                    final newStaff = Staff(
                      name: nameCtrl.text.trim(),
                      phoneNumber: phoneCtrl.text.trim(),
                      role: 'Mechanic',
                    );
                    ref.read(staffListProvider.notifier).add(newStaff);
                    setState(() => _selectedMechanic = newStaff);
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amethyst,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('TAMBAHKAN', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- STEP 3: PEKERJAAN & SPAREPART ---
  Widget _buildStepPekerjaan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(
            AppStrings.transaction.serviceAndParts,
            AppStrings.transaction.serviceAndPartsDesc,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _showCatalogPicker(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(20),
              side: BorderSide(color: AppColors.amethyst.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(SolarIconsOutline.addCircle),
                const SizedBox(width: 12),
                Text(
                  AppStrings.transaction.addItem,
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildItemsList(),
          const SizedBox(height: 32),
          _buildStepHeader(
            AppStrings.transaction.recommendation,
            AppStrings.transaction.recommendationDesc,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildModernFilterChip(
                label: AppStrings.transaction.byTime,
                isSelected: _selectedRecommendationTime != null,
                onSelected: (v) {
                  setState(() => _selectedRecommendationTime = v ? 3 : null);
                },
              ),
              const SizedBox(width: 12),
              _buildModernFilterChip(
                label: AppStrings.transaction.byDistance,
                isSelected: _recommendationKmController.text.isNotEmpty,
                onSelected: (v) {
                  if (v) {
                    _recommendationKmController.text = '2000';
                  } else {
                    _recommendationKmController.clear();
                  }
                  setState(() {});
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedRecommendationTime != null || _recommendationKmController.text.isNotEmpty)
            _buildFieldCard(
              child: Column(
                children: [
                  TextFormField(
                    controller: _currentOdometerController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                       labelText: AppStrings.transaction.currentOdometer,
                       prefixIcon: const Icon(LucideIcons.gauge),
                       suffixText: 'Km',
                    ),
                  ),
                  if (_recommendationKmController.text.isNotEmpty) ...[
                    const Divider(height: 32),
                    TextFormField(
                      controller: _recommendationKmController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                         labelText: AppStrings.transaction.targetService,
                         prefixIcon: const Icon(LucideIcons.flag),
                         suffixText: 'Km',
                      ),
                    ),
                  ],
                  if (_selectedRecommendationTime != null) ...[
                    const Divider(height: 32),
                    Row(
                      children: [
                        const Icon(SolarIconsOutline.calendarMinimalistic, color: AppColors.amethyst),
                        const SizedBox(width: 12),
                        Text(
                          AppStrings.transaction.month,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        _buildCounter(
                          value: _selectedRecommendationTime!,
                          onChanged: (v) => setState(() => _selectedRecommendationTime = v),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- STEP 4: RINGKASAN & ESTIMASI ---
  Widget _buildStepRingkasan() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStepHeader(
            AppStrings.transaction.summary,
            AppStrings.transaction.summaryDesc,
          ),
          const SizedBox(height: 24),
          _buildFieldCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.amethyst.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(SolarIconsOutline.walletMoney, color: AppColors.amethyst),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.transaction.totalEstimateValue(_selectedItems.length, AppStrings.transaction.formatCurrency(_totalAmount)),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            AppStrings.transaction.formatCurrency(_totalAmount),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppColors.amethyst,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildCategoryItem(String label, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showCatalogPicker(initialQuery: label),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.amethyst.withValues(alpha: 0.08) : AppColors.amethyst.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.amethyst.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.amethyst, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.amethyst,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.amethyst.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.amethyst.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildTypeItem(VehicleCategory.motor, AppIcons.motorcycle, 'Motor'),
          _buildTypeItem(VehicleCategory.mobil, AppIcons.car, 'Mobil'),
        ],
      ),
    );
  }

  Widget _buildTypeItem(VehicleCategory category, IconData icon, String label) {
    final isSelected = _selectedVehicleCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: isHeaderInfoLocked ? null : () => setState(() => _selectedVehicleCategory = category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.amethyst : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.5),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addItemFromMaster(ServiceMaster master) {
    setState(() {
      final existingIndex = _selectedItems.indexWhere(
        (item) => item.serviceMaster.targetId == master.id,
      );

      if (existingIndex != -1) {
        _selectedItems[existingIndex].quantity++;
        _selectedItems[existingIndex].recalculateSubtotal();
      } else {
        int bonus = 0;
        if (_selectedMechanic != null) {
          bonus = (master.basePrice * _selectedMechanic!.commissionRate).round();
        }

        final newItem = TransactionItem(
          name: master.name,
          price: master.basePrice,
          costPrice: 0,
          quantity: 1,
          isService: true,
          mechanicBonus: bonus,
        );
        newItem.serviceMaster.target = master;
        _selectedItems.add(newItem);
      }
    });
  }

  void _addItemFromStok(Stok stok) {
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
        (item) => item.stok.targetId == stok.id,
      );

      if (existingIndex != -1) {
        if (_selectedItems[existingIndex].quantity < stok.jumlah) {
          _selectedItems[existingIndex].quantity++;
          _selectedItems[existingIndex].recalculateSubtotal();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Batas stok "${stok.nama}" tercapai (${stok.jumlah})'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        int bonus = 0;
        if (_selectedMechanic != null) {
          bonus = (stok.hargaJual * _selectedMechanic!.commissionRate).round();
        }

        final newItem = TransactionItem(
          name: stok.nama,
          price: stok.hargaJual,
          costPrice: stok.hargaBeli,
          quantity: 1,
          isService: false,
          mechanicBonus: bonus,
        );
        newItem.stok.target = stok;
        _selectedItems.add(newItem);
      }
    });
  }

  void _showCatalogPicker({String? initialQuery}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final jasaList = ref.watch(serviceMasterListProvider).valueOrNull ?? [];
              final stokList = ref.watch(stokListProvider);
              
              final query = (initialQuery ?? _quickSearchController.text).toLowerCase();
              final filteredJasa = jasaList.where((j) => 
                j.name.toLowerCase().contains(query) || 
                (j.category?.toLowerCase().contains(query) ?? false)).toList();
              final filteredStok = stokList.where((s) => 
                s.nama.toLowerCase().contains(query) || 
                s.kategori.toLowerCase().contains(query)).toList();

              return Container(
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
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Katalog Item',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(LucideIcons.x),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.grey.withValues(alpha: 0.1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            autofocus: initialQuery == null,
                            onChanged: (v) => setModalState(() {
                               _quickSearchController.text = v;
                               initialQuery = null;
                            }),
                            controller: initialQuery != null ? TextEditingController(text: initialQuery) : _quickSearchController,
                            decoration: InputDecoration(
                              hintText: 'Cari jasa atau barang...',
                              prefixIcon: const Icon(SolarIconsOutline.magnifier),
                              filled: true,
                              fillColor: AppColors.amethyst.withValues(alpha: 0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          if (filteredJasa.isNotEmpty) ...[
                            _buildPickerSectionHeader('Jasa & Servis'),
                            ...filteredJasa.map((j) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.wrench, size: 18, color: Colors.blue),
                                  ),
                                  title: Text(j.name, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                  subtitle: Text(j.category ?? 'Umum', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                                  trailing: Text(
                                    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(j.basePrice),
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: AppColors.amethyst),
                                  ),
                                  onTap: () {
                                    _addItemFromMaster(j);
                                    Navigator.pop(context);
                                  },
                                )),
                          ],
                          if (filteredStok.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildPickerSectionHeader('Suku Cadang & Barang'),
                            ...filteredStok.map((s) => ListTile(
                                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(SolarIconsOutline.box, size: 18, color: Colors.orange),
                                  ),
                                  title: Text(s.nama, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
                                  subtitle: Text('${s.kategori} • Stok: ${s.jumlah}', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                                  trailing: Text(
                                    NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(s.hargaJual),
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, color: AppColors.amethyst),
                                  ),
                                  onTap: () {
                                    _addItemFromStok(s);
                                    Navigator.pop(context);
                                  },
                                )),
                          ],
                          if (filteredJasa.isEmpty && filteredStok.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Column(
                                  children: [
                                    const Icon(SolarIconsOutline.ghost, size: 48, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    Text('Tidak ditemukan', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPickerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey,
          letterSpacing: 1.5,
        ),
      ),
    );
  }


  Widget _buildItemsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_selectedItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(SolarIconsOutline.box, size: 48, color: isDark ? Colors.white12 : Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              AppStrings.transaction.emptyItems,
              style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _selectedItems.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.amethyst.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.amethyst.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.isService ? AppIcons.service : SolarIconsOutline.box,
                  size: 18,
                  color: AppColors.amethyst,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      NumberFormat.currency(locale: "id_ID", symbol: "Rp", decimalDigits: 0).format(item.price),
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    if (item.mechanicBonus > 0)
                      GestureDetector(
                        onTap: () => _showEditBonusDialog(idx),
                        child: Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.medal, size: 10, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                'Bonus: ${NumberFormat.currency(locale: "id_ID", symbol: "Rp", decimalDigits: 0).format(item.mechanicBonus)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.edit3, size: 8, color: Colors.green),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.amethyst.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.minus, size: 14),
                      onPressed: () {
                        if (item.quantity > 1) {
                          setState(() {
                            item.quantity--;
                            item.recalculateSubtotal();
                          });
                        }
                      },
                      color: AppColors.amethyst,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    Text(
                      '${item.quantity}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: AppColors.amethyst,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.plus, size: 14),
                      onPressed: () {
                        if (!item.isService && item.stok.target != null) {
                          if (item.quantity >= item.stok.target!.jumlah) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Batas stok "${item.name}" tercapai (${item.stok.target!.jumlah})'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
                        }
                        setState(() {
                          item.quantity++;
                          item.recalculateSubtotal();
                        });
                      },
                      color: AppColors.amethyst,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _selectedItems.removeAt(idx)),
                icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showEditBonusDialog(int index) {
    final item = _selectedItems[index];
    final controller = TextEditingController(text: item.mechanicBonus.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.transaction.editBonusTitle(item.name), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.transaction.editBonusDesc, style: GoogleFonts.plusJakartaSans(fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppStrings.transaction.bonusLabel,
                prefixIcon: const Icon(LucideIcons.medal),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.common.cancel),
          ),
          FilledButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text) ?? 0;
              setState(() {
                _selectedItems[index].mechanicBonus = newValue;
              });
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.amethyst),
            child: Text(AppStrings.common.save),
          ),
        ],
      ),
    );
  }

  // --- ACTIONS ---
  void _onPlateChanged(String plate) {
    if (plate.length < 3) return;
    final vehicles = ref.read(vehicleListProvider).valueOrNull ?? [];
    try {
      final v = vehicles.firstWhere(
        (v) => v.plate.replaceAll(' ', '').toUpperCase() == plate.replaceAll(' ', '').toUpperCase(),
      );
      setState(() {
        _selectedVehicle = v;
        _vehicleModelController.text = v.model;
        _vehicleYearController.text = v.year?.toString() ?? '';
        _vehicleColorController.text = v.color ?? '';
        final typeStr = v.type;
        _selectedVehicleCategory = VehicleCategory.values.firstWhere(
          (e) => e.name.toLowerCase() == typeStr.toLowerCase(),
          orElse: () => VehicleCategory.motor,
        );
        _autoFillPelanggan(v);
      });
    } catch (_) {}
  }

  void _autoFillPelanggan(Vehicle v) {
    final owner = v.owner.target;
    if (owner != null) {
      _selectedPelanggan = owner;
      _customerNameController.text = owner.nama;
      _customerPhoneController.text = owner.telepon;
      _customerAddressController.text = owner.alamat;
    }
  }

  Future<void> _openPlateScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerDialog()),
    );
    if (result != null && mounted) {
      final plate = result.toUpperCase();
      _vehiclePlateController.text = plate;
      _onPlateChanged(plate);
    }
  }

  void _autoFillVehicle(Pelanggan p) {
    final vehicles = ref.read(customerVehiclesProvider(p.id));
    if (vehicles.isEmpty) return;
    if (vehicles.length == 1) {
      final v = vehicles.first;
      setState(() {
        _selectedVehicle = v;
        _vehicleModelController.text = v.model;
        _vehiclePlateController.text = v.plate;
        _selectedVehicleCategory = VehicleCategory.values.firstWhere(
          (e) => e.name.toLowerCase() == v.type.toLowerCase(),
          orElse: () => VehicleCategory.motor,
        );
      });
    } else {
      _showVehiclePicker(context, vehicles);
    }
  }

  void _showStaffPicker(BuildContext context, List<Staff> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BasePickerModal(
        title: AppStrings.transaction.selectTechnician,
        items: list.map((s) => _PickerItem(title: s.name, subtitle: s.role, original: s)).toList(),
        onSelected: (item) => setState(() => _selectedMechanic = item.original as Staff),
      ),
    );
  }

  void _showVehiclePicker(BuildContext context, List<Vehicle> list) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _BasePickerModal(
        title: AppStrings.transaction.selectVehicle,
        items: list.map((v) => _PickerItem(title: v.plate, subtitle: v.model, original: v)).toList(),
        onSelected: (item) {
          final v = item.original as Vehicle;
          setState(() {
            _selectedVehicle = v;
            _vehicleModelController.text = v.model;
            _vehiclePlateController.text = v.plate;
            _selectedVehicleCategory = VehicleCategory.values.firstWhere(
              (e) => e.name.toLowerCase() == v.type.toLowerCase(),
              orElse: () => VehicleCategory.motor,
            );
            _autoFillPelanggan(v);
          });
        },
      ),
    );
  }

  void _showPelangganPicker(List<Pelanggan> allCustomers) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final query = _quickSearchController.text.toLowerCase();
              final filtered = allCustomers.where((p) {
                final matchName = p.nama.toLowerCase().contains(query);
                final matchPhone = p.telepon.contains(query);
                // Also search in their vehicles' plates
                final vehicles = ref.read(customerVehiclesProvider(p.id));
                final matchPlate = vehicles.any((v) => v.plate.toLowerCase().contains(query));
                return matchName || matchPhone || matchPlate;
              }).toList();

              return Container(
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
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.transaction.selectCustomer,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _quickSearchController,
                            autofocus: true,
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              hintText: AppStrings.transaction.customerSearchHint,
                              prefixIcon: const Icon(SolarIconsOutline.magnifier),
                              suffixIcon: _quickSearchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _quickSearchController.clear();
                                        setModalState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          final vehicles = ref.read(customerVehiclesProvider(p.id));
                          final plateStr = vehicles.isNotEmpty 
                              ? vehicles.map((v) => v.plate).join(', ')
                              : AppStrings.transaction.noVehicle;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.amethyst.withValues(alpha: 0.1),
                                child: Text(p.nama[0].toUpperCase(), style: const TextStyle(color: AppColors.amethyst, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(p.nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(plateStr, style: const TextStyle(color: AppColors.amethyst, fontWeight: FontWeight.w600, fontSize: 12)),
                              trailing: Text(p.telepon, style: const TextStyle(fontSize: 12)),
                              onTap: () {
                                setState(() {
                                  _selectedPelanggan = p;
                                  _customerNameController.text = p.nama;
                                  _customerPhoneController.text = p.telepon;
                                  _customerAddressController.text = p.alamat;
                                  _autoFillVehicle(p);
                                });
                                Navigator.pop(context);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.error.itemEmpty)));
      return;
    }

    final hasService = _selectedItems.any((item) => item.isService);
    if (!hasService) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.transaction.requiredService),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final notifier = ref.read(transactionListProvider.notifier);
      final pelanggan = _selectedPelanggan ??
          Pelanggan(
            nama: _customerNameController.text.trim(),
            telepon: _customerPhoneController.text.trim(),
            alamat: _customerAddressController.text.trim(),
          );

      final vehicle = _selectedVehicle ??
          (Vehicle(
            plate: _vehiclePlateController.text.trim().toUpperCase(),
            model: _vehicleModelController.text.trim(),
            type: _selectedVehicleCategory.name,
            year: int.tryParse(_vehicleYearController.text),
            color: _vehicleColorController.text.trim(),
          )..owner.target = pelanggan);

      if (widget.initialTransaction == null) {
        final newTrx = entity.Transaction(
          customerName: pelanggan.nama,
          customerPhone: pelanggan.telepon,
          vehiclePlate: vehicle.plate,
          vehicleModel: vehicle.model,
          complaint: _complaintController.text,
          odometer: int.tryParse(_currentOdometerController.text),
          recommendationKm: int.tryParse(_recommendationKmController.text),
          recommendationTimeMonth: _selectedRecommendationTime,
        )
          ..photoLocalPath = _localPhotoPath
          ..serviceStatus = entity.ServiceStatus.antri;

        newTrx.pelanggan.target = pelanggan;
        newTrx.vehicle.target = vehicle;
        if (_selectedMechanic != null) newTrx.mechanic.target = _selectedMechanic;
        newTrx.items.addAll(_selectedItems);
        newTrx.calculateTotals();

        await notifier.addTransaction(newTrx);
      } else {
        final trx = widget.initialTransaction!;
        trx.complaint = _complaintController.text;
        trx.odometer = int.tryParse(_currentOdometerController.text);
        trx.recommendationKm = int.tryParse(_recommendationKmController.text);
        trx.photoLocalPath = _localPhotoPath;
        if (_selectedMechanic != null) trx.mechanic.target = _selectedMechanic;
        trx.items.clear();
        trx.items.addAll(_selectedItems);
        trx.calculateTotals();

        await notifier.updateTransaction(trx);
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${AppStrings.error.saveFailed}: $e'))); // Need saveFailed in error? Yes.
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildAutocompleteOptions<T extends Object>({
    required BuildContext context,
    required AutocompleteOnSelected<T> onSelected,
    required Iterable<T> options,
    required BoxConstraints constraints,
    required String Function(T) titleBuilder,
    String Function(T)? subtitleBuilder,
    String? typedValue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 20,
        color: Colors.transparent,
        child: Container(
          width: constraints.maxWidth,
          margin: const EdgeInsets.only(top: 8),
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.amethyst.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (context, index) => Divider(
                height: 1, 
                color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.amethyst.withValues(alpha: 0.05)
              ),
              itemBuilder: (ctx, idx) {
                final T option = options.elementAt(idx);
                final title = titleBuilder(option);
                final subtitle = subtitleBuilder?.call(option);
                
                return InkWell(
                  onTap: () => onSelected(option),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldCard({required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.amethyst.withValues(alpha: 0.1),
        ),
      ),
      child: child,
    );
  }

  Widget _buildModernFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FilterChip(
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
      selectedColor: AppColors.amethyst,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildCounter({required int value, required Function(int) onChanged}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.amethyst.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(LucideIcons.minus, size: 14),
            onPressed: () => onChanged(value > 1 ? value - 1 : value),
            color: AppColors.amethyst,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
          Text(
            '$value',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              color: AppColors.amethyst,
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.plus, size: 14),
            onPressed: () => onChanged(value + 1),
            color: AppColors.amethyst,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
          ),
        ],
      ),
    );
  }
}

class _PickerItem {
  final String title;
  final String subtitle;
  final dynamic original;
  _PickerItem({required this.title, required this.subtitle, required this.original});
}

class _BasePickerModal extends StatelessWidget {
  final String title;
  final List<_PickerItem> items;
  final Function(_PickerItem) onSelected;
  const _BasePickerModal({required this.title, required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900)),
          ),
          if (items.isEmpty)
            Padding(padding: const EdgeInsets.all(40), child: Text(AppStrings.common.emptyData))
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: items.length,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(item.subtitle),
                      onTap: () {
                        onSelected(item);
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AddItemModal extends ConsumerStatefulWidget {
  final Function(TransactionItem) onAdd;
  const _AddItemModal({required this.onAdd});

  @override
  ConsumerState<_AddItemModal> createState() => _AddItemModalState();
}

class _AddItemModalState extends ConsumerState<_AddItemModal> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  bool _isService = true;
  int _currentCostPrice = 0;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final jasaList = ref.watch(serviceMasterListProvider).valueOrNull ?? [];
    final produkList = ref.watch(stokListProvider);

    final qty = int.tryParse(_qtyController.text) ?? 1;
    final price = int.tryParse(_priceController.text) ?? 0;
    final subtotal = qty * price;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                AppStrings.transaction.addItem,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(AppStrings.transaction.typeService)),
                    selected: _isService,
                    onSelected: (v) => setState(() {
                      _isService = true;
                      _currentCostPrice = 0; // Services have no HPP
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(AppStrings.transaction.typePart)),
                    selected: !_isService,
                    onSelected: (v) => setState(() {
                      _isService = false;
                      _currentCostPrice = 0; // Reset cost price when switching
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  if (_isService) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateServiceMasterScreen(
                          initialName: _nameController.text.isNotEmpty ? _nameController.text : null,
                        ),
                      ),
                    );
                  } else {
                    // UX-02 FIX: Navigasi ke CreateBarangScreen dengan nama awal
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateBarangScreen(
                          initialName: _nameController.text.isNotEmpty ? _nameController.text : null,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(LucideIcons.plusCircle, size: 14),
                label: Text(
                  _isService ? AppStrings.transaction.addNewService : AppStrings.transaction.addNewPart,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: TextButton.styleFrom(foregroundColor: AppColors.amethyst),
              ),
            ),
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: _isService ? AppStrings.transaction.searchServiceHint : AppStrings.transaction.searchPartHint,
                prefixIcon: const Icon(SolarIconsOutline.magnifier),
                filled: true,
                fillColor: AppColors.amethyst.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: _buildFilteredItemList(jasaList, produkList),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.transaction.pricePerUnit,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp',
                                decimalDigits: 0)
                            .format(price),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.amethyst,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.amethyst.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (qty > 1) {
                            _qtyController.text = (qty - 1).toString();
                            setState(() {});
                          }
                        },
                        icon: const Icon(LucideIcons.minusCircle),
                        color: AppColors.amethyst,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          qty.toString(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.amethyst,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _qtyController.text = (qty + 1).toString();
                          setState(() {});
                        },
                        icon: const Icon(LucideIcons.plusCircle),
                        color: AppColors.amethyst,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.amethyst.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.transaction.subTotalItem,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                                locale: 'id_ID',
                                symbol: 'Rp',
                                decimalDigits: 0)
                            .format(subtotal),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.amethyst,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_nameController.text.isNotEmpty) {
                        widget.onAdd(TransactionItem(
                          name: _nameController.text,
                          price: price,
                          costPrice: _currentCostPrice,
                          quantity: qty,
                          isService: _isService,
                        ));
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amethyst,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      AppStrings.common.add.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilteredItemList(List<ServiceMaster> jasaList, List<Stok> produkList) {
    if (_isService) {
      final filtered = jasaList.where((j) {
        final searchLower = _searchQuery.toLowerCase();
        return j.name.toLowerCase().contains(searchLower) ||
            (j.category?.toLowerCase().contains(searchLower) ?? false);
      }).toList();

      if (filtered.isEmpty) return _buildEmptyState();

      return ListView.builder(
        shrinkWrap: true,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildItemRow(
            title: item.name,
            subtitle: item.category ?? AppStrings.common.noCategory,
            price: item.basePrice,
            onTap: () {
              setState(() {
                _nameController.text = item.name;
                _priceController.text = item.basePrice.toString();
                _currentCostPrice = 0;
              });
            },
          );
        },
      );
    } else {
      final filtered = produkList.where((p) {
        final searchLower = _searchQuery.toLowerCase();
        return p.nama.toLowerCase().contains(searchLower) ||
            p.kategori.toLowerCase().contains(searchLower);
      }).toList();

      if (filtered.isEmpty) return _buildEmptyState();

      return ListView.builder(
        shrinkWrap: true,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _buildItemRow(
            title: item.nama,
            subtitle: item.kategori,
            price: item.hargaJual,
            stock: item.jumlah,
            onTap: () {
              setState(() {
                _nameController.text = item.nama;
                _priceController.text = item.hargaJual.toString();
                _currentCostPrice = item.hargaBeli;
              });
            },
          );
        },
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(SolarIconsOutline.boxMinimalistic, size: 32, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(
            'Item tidak ditemukan',
            style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow({
    required String title,
    required String subtitle,
    required int price,
    int? stock,
    required VoidCallback onTap}
  ) {
    bool isSelected = _nameController.text == title;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.amethyst.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.amethyst : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.amethyst.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          subtitle.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.amethyst,
                          ),
                        ),
                      ),
                      if (stock != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Stok: $stock',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            color: stock <= 5 ? Colors.red : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(
              NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(price),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.amethyst,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


