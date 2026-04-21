import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_icons.dart';
import '../../core/services/vehicle_data_service.dart';
import '../../core/providers/master_providers.dart';
import '../../core/widgets/atelier_header.dart';
import '../../domain/entities/pelanggan.dart';
import '../../domain/entities/vehicle.dart';
import '../../core/utils/license_plate_formatter.dart';

class CreateVehicleScreen extends ConsumerStatefulWidget {
  final Pelanggan pelanggan;
  final Vehicle? initialVehicle;
  const CreateVehicleScreen({
    super.key,
    required this.pelanggan,
    this.initialVehicle,
  });

  @override
  ConsumerState<CreateVehicleScreen> createState() =>
      _CreateVehicleScreenState();
}

class _CreateVehicleScreenState extends ConsumerState<CreateVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();

  VehicleCategory _selectedCategory = VehicleCategory.motor;

  @override
  void initState() {
    super.initState();
    if (widget.initialVehicle != null) {
      final v = widget.initialVehicle!;
      _modelController.text = v.model;
      _plateController.text = v.plate;
      _yearController.text = v.year?.toString() ?? '';
      _colorController.text = v.color ?? '';
      _selectedCategory = VehicleCategory.values.firstWhere(
        (e) => e.name.toLowerCase() == v.type.toLowerCase(),
        orElse: () => VehicleCategory.motor,
      );
    }
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (widget.initialVehicle != null) {
        widget.initialVehicle!.model = _modelController.text.trim();
        widget.initialVehicle!.type = _selectedCategory.name;
        widget.initialVehicle!.plate = _plateController.text
            .trim()
            .toUpperCase();
        widget.initialVehicle!.year = int.tryParse(_yearController.text);
        widget.initialVehicle!.color = _colorController.text.trim();

        ref
            .read(vehicleListProvider.notifier)
            .updateVehicle(widget.initialVehicle!);
      } else {
        final vehicle = Vehicle(
          model: _modelController.text.trim(),
          type: _selectedCategory.name,
          plate: _plateController.text.trim().toUpperCase(),
          year: int.tryParse(_yearController.text),
          color: _colorController.text.trim(),
        );
        vehicle.owner.target = widget.pelanggan;
        ref.read(vehicleListProvider.notifier).addVehicle(vehicle);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAtelierHeaderSub(
            title: widget.initialVehicle != null
                ? AppStrings.customer.updateData.toUpperCase()
                : AppStrings.customer.addVehicle.toUpperCase(),
            subtitle: AppStrings.customer.ownedBy(widget.pelanggan.nama),
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildTypeSelector(),
                    const SizedBox(height: 16),
                    _buildFormCard(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) =>
                              Autocomplete<String>(
                                optionsBuilder:
                                    (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return const Iterable<String>.empty();
                                      }
                                      return VehicleDataService.getSuggestions(
                                        textEditingValue.text,
                                        _selectedCategory,
                                      );
                                    },
                                onSelected: (String selection) {
                                  _modelController.text = selection;
                                },
                                fieldViewBuilder:
                                    (
                                      context,
                                      controller,
                                      focusNode,
                                      onFieldSubmitted,
                                    ) {
                                      // Sync controllers
                                      if (controller.text.isEmpty &&
                                          _modelController.text.isNotEmpty) {
                                        controller.text = _modelController.text;
                                      }
                                      controller.addListener(() {
                                        _modelController.text = controller.text;
                                      });

                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: AppStrings.customer.vehicleModel,
                                          hintText: AppStrings.customer.vehicleModelHint,
                                          prefixIcon: Icon(
                                            _selectedCategory ==
                                                    VehicleCategory.mobil
                                                ? AppIcons.car
                                                : AppIcons.motorcycle,
                                          ),
                                        ),
                                        validator: (v) => v?.isEmpty ?? true
                                            ? AppStrings.common.requiredField
                                            : null,
                                        onFieldSubmitted: (v) =>
                                            onFieldSubmitted(),
                                      );
                                    },
                                optionsViewBuilder:
                                    (context, onSelected, options) {
                                      return _buildAutocompleteOptions(
                                        context: context,
                                        onSelected: onSelected,
                                        options: options,
                                        constraints: constraints,
                                      );
                                    },
                              ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _plateController,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            labelText: AppStrings.customer.plateNumber,
                            hintText: AppStrings.customer.plateHint,
                            prefixIcon: const Icon(SolarIconsOutline.tag),
                          ),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9 ]'),
                            ),
                            IndonesianLicensePlateFormatter(),
                          ],
                          validator: (v) {
                            if (v?.isEmpty ?? true) return AppStrings.common.requiredField;
                            if (!RegExp(r'^[A-Z]').hasMatch(v!)) {
                              return AppStrings.customer.invalidPlateFormat;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _yearController,
                                style: GoogleFonts.plusJakartaSans(),
                                decoration: InputDecoration(
                                  labelText: AppStrings.customer.year,
                                  prefixIcon: const Icon(SolarIconsOutline.calendar),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _colorController,
                                style: GoogleFonts.plusJakartaSans(),
                                decoration: InputDecoration(
                                  labelText: AppStrings.customer.color,
                                  prefixIcon: const Icon(SolarIconsOutline.palette),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 64),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        widget.initialVehicle != null
                            ? AppStrings.customer.updateData.toUpperCase()
                            : AppStrings.customer.saveVehicle.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
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

  Widget _buildTypeSelector() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildTypeItem(VehicleCategory.motor, AppIcons.motorcycle, AppStrings.customer.motor),
          _buildTypeItem(VehicleCategory.mobil, AppIcons.car, AppStrings.customer.mobil),
        ],
      ),
    );
  }

  Widget _buildTypeItem(VehicleCategory category, IconData icon, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedCategory == category;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategory = category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
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
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildAutocompleteOptions({
    required BuildContext context,
    required AutocompleteOnSelected<String> onSelected,
    required Iterable<String> options,
    required BoxConstraints constraints,
  }) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Container(
          width: constraints.maxWidth,
          constraints: const BoxConstraints(maxHeight: 300),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
            ),
            itemBuilder: (BuildContext context, int index) {
              final String option = options.elementAt(index);
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                title: Text(
                  option,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                onTap: () => onSelected(option),
              );
            },
          ),
        ),
      ),
    );
  }
}
