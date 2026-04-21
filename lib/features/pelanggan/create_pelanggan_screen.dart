import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/providers/pelanggan_provider.dart';
import '../../core/utils/phone_formatter.dart';
import '../../core/widgets/atelier_header.dart';
import '../../domain/entities/pelanggan.dart';

class CreatePelangganScreen extends ConsumerStatefulWidget {
  final Pelanggan? initialPelanggan;
  const CreatePelangganScreen({super.key, this.initialPelanggan});

  @override
  ConsumerState<CreatePelangganScreen> createState() =>
      _CreatePelangganScreenState();
}

class _CreatePelangganScreenState extends ConsumerState<CreatePelangganScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _teleponController;
  late final TextEditingController _alamatController;

  bool get isEdit => widget.initialPelanggan != null;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(
      text: widget.initialPelanggan?.nama ?? '',
    );
    _teleponController = TextEditingController(
      text: widget.initialPelanggan?.telepon ?? '',
    );
    _alamatController = TextEditingController(
      text: widget.initialPelanggan?.alamat ?? '',
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      if (isEdit) {
        final updated = widget.initialPelanggan!;
        updated.nama = _namaController.text;
        updated.telepon = _teleponController.text;
        updated.alamat = _alamatController.text;
        updated.updatedAt = DateTime.now();
        ref.read(pelangganListProvider.notifier).updateItem(updated);
      } else {
        final pelanggan = Pelanggan(
          nama: _namaController.text,
          telepon: _teleponController.text,
          alamat: _alamatController.text,
        );
        ref.read(pelangganListProvider.notifier).add(pelanggan);
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
            title: isEdit ? AppStrings.customer.editData.toUpperCase() : AppStrings.customer.newCustomer.toUpperCase(),
            subtitle: isEdit
                ? AppStrings.customer.editSubtitle
                : AppStrings.customer.newSubtitle,
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
                    _buildFormCard(
                      children: [
                        TextFormField(
                          controller: _namaController,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                          ),
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: AppStrings.customer.fullName,
                            prefixIcon: const Icon(SolarIconsOutline.user),
                          ),
                          validator: (v) =>
                              v?.isEmpty ?? true ? AppStrings.common.requiredField : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _teleponController,
                          style: GoogleFonts.plusJakartaSans(),
                          decoration: InputDecoration(
                            labelText: AppStrings.customer.phoneLabel,
                            prefixIcon: const Icon(SolarIconsOutline.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [IndonesianPhoneFormatter()],
                          validator: (v) =>
                              v?.isEmpty ?? true ? AppStrings.common.requiredField : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _alamatController,
                          style: GoogleFonts.plusJakartaSans(),
                          decoration: InputDecoration(
                            labelText: AppStrings.customer.addressOptional,
                            prefixIcon: const Icon(SolarIconsOutline.mapPoint),
                          ),
                          maxLines: 2,
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
                        isEdit ? AppStrings.common.saveChanges.toUpperCase() : AppStrings.customer.saveCustomer.toUpperCase(),
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
}
