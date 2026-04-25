import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/expense_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/media_provider.dart';
import '../../../domain/entities/expense.dart';
import '../../../core/utils/app_haptic.dart';

class PayDebtDialog extends ConsumerStatefulWidget {
  final Expense debt;

  const PayDebtDialog({
    super.key,
    required this.debt,
  });

  @override
  ConsumerState<PayDebtDialog> createState() => _PayDebtDialogState();
}

class _PayDebtDialogState extends ConsumerState<PayDebtDialog> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _proofImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default to full payment
    _amountController.text = (widget.debt.debtBalance ?? 0).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final mediaService = ref.read(mediaServiceProvider);
    final image = await mediaService.pickImage(source);

    if (image != null) {
      final localPath = await mediaService.saveImageLocally(image);
      if (localPath != null) {
        setState(() => _proofImagePath = localPath);
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final bengkelId = ref.read(bengkelIdProvider);
      if (bengkelId == null) return;

      final amount = double.parse(_amountController.text);
      final remaining = widget.debt.debtBalance ?? 0;

      if (amount > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nominal melebihi sisa hutang!')),
        );
        return;
      }

      setState(() => _isSaving = true);

      try {
        await ref.read(expenseListProvider(bengkelId).notifier).payDebt(
              debt: widget.debt,
              amountPaid: amount,
              proofImagePath: _proofImagePath,
            );

        if (mounted) {
          AppHaptic.success();
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran berhasil dicatat'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mencatat pembayaran: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = widget.debt.debtBalance ?? 0;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      title: Text(
        'Bayar Hutang',
        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supplier: ${widget.debt.supplierName}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sisa Hutang: ${currencyFormat.format(remaining)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Nominal Pembayaran',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Masukkan nominal';
                  final val = double.tryParse(v);
                  if (val == null || val <= 0) return 'Nominal tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Bukti Foto (Opsional)',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showImagePicker(context),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _proofImagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(_proofImagePath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              SolarIconsOutline.camera,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap untuk ambil foto',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(
            'BATAL',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'KONFIRMASI',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
                ),
        ),
      ],
    );
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(SolarIconsOutline.camera),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(SolarIconsOutline.gallery),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

