import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/app_colors.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/sale.dart';
import '../providers/transaction_providers.dart';
import '../providers/sale_providers.dart';
import '../services/document_service.dart';
import 'qr_view_view.dart';
import '../providers/pengaturan_provider.dart';
import 'package:intl/intl.dart';

class TheCeremonyDialog extends ConsumerStatefulWidget {
  final Transaction? transaction;
  final List<Sale>? sales;

  const TheCeremonyDialog({super.key, this.transaction, this.sales})
      : assert(transaction != null || sales != null);

  @override
  ConsumerState<TheCeremonyDialog> createState() => _TheCeremonyDialogState();
}

class _TheCeremonyDialogState extends ConsumerState<TheCeremonyDialog> {
  int _currentStep = 0; // 0: Payment selection, 1: Success & Receipts
  String? _selectedPayment;
  bool _isFinalizing = false;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String get _totalDisplay {
    if (widget.transaction != null) {
      return _currencyFormat.format(widget.transaction!.totalAmount);
    }
    if (widget.sales != null) {
      final total = widget.sales!.fold(0, (sum, item) => sum + item.totalPrice);
      return _currencyFormat.format(total);
    }
    return 'Rp 0';
  }

  Future<void> _handlePaymentSelection(String method) async {
    setState(() {
      _selectedPayment = method;
      _isFinalizing = true;
    });

    try {
      if (widget.transaction != null) {
        await ref
            .read(transactionListProvider.notifier)
            .finalizeTransaction(widget.transaction!, method);
      } else if (widget.sales != null) {
        await ref
            .read(saleListProvider.notifier)
            .addSalesWithFinalization(widget.sales!, method);
      }

      setState(() {
        _isFinalizing = false;
        _currentStep = 1;
      });
    } catch (e) {
      setState(() => _isFinalizing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: (isDark ? Colors.white : theme.colorScheme.primary)
                .withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _currentStep == 0
              ? _buildPaymentStep()
              : _buildCompletionStep(),
        ),
      ),
    );
  }

  Widget _buildPaymentStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'PEMBAYARAN',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppColors.warning,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _totalDisplay,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),
        if (_isFinalizing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          )
        else ...[
          _PaymentOptionTile(
            icon: SolarIconsBold.wadOfMoney,
            label: 'Tunai',
            color: Colors.green,
            onTap: () => _handlePaymentSelection('Tunai'),
          ),
          _PaymentOptionTile(
            icon: SolarIconsBold.qrCode,
            label: 'QRIS',
            color: Colors.blue,
            onTap: () => _handlePaymentSelection('QRIS'),
            trailing:
                (ref.read(settingsProvider).qrisEnabled &&
                    ref.read(settingsProvider).qrisImagePath != null)
                ? IconButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black.withValues(alpha: 0.8),
                        builder: (_) => QRViewView(
                          imagePath: ref.read(settingsProvider).qrisImagePath!,
                          workshopName: ref.read(settingsProvider).workshopName,
                        ),
                      );
                    },
                    icon: const Icon(SolarIconsOutline.qrCode, size: 20),
                    tooltip: 'Lihat QR',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.1),
                      foregroundColor: Colors.blue,
                    ),
                  )
                : null,
          ),
          _PaymentOptionTile(
            icon: SolarIconsBold.cardTransfer,
            label: 'Transfer Bank',
            color: Colors.orange,
            onTap: () => _handlePaymentSelection('Transfer'),
          ),
        ],
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'BATAL',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionStep() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.green.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            SolarIconsBold.checkCircle,
            color: Colors.green,
            size: 64,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'BERHASIL!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.success,
          ),
        ),
        Text(
          'Pembayaran $_selectedPayment dikonfirmasi.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 32),
        _ActionTile(
          icon: SolarIconsOutline.chatRoundCheck,
          label: 'Kirim WhatsApp (Teks)',
          color: Colors.green,
          onTap: () {
            final settings = ref.read(settingsProvider);
            ref.read(documentServiceProvider).shareWhatsApp(
              phone: widget.transaction?.customerPhone ?? '',
              transaction: widget.transaction,
              sales: widget.sales,
              bengkelName: settings.workshopName,
              address: settings.workshopAddress,
              workshopWhatsapp: settings.workshopWhatsapp,
            );
          },
        ),
        _ActionTile(
          icon: SolarIconsOutline.printer,
          label: 'Cetak Struk (Thermal)',
          color: Colors.orange,
          onTap: () {
            final settings = ref.read(settingsProvider);
            ref.read(documentServiceProvider).generateAndPrint(
              transaction: widget.transaction,
              sales: widget.sales,
              bengkelName: settings.workshopName,
              address: settings.workshopAddress,
              workshopWhatsapp: settings.workshopWhatsapp,
              logoPath: settings.workshopLogoPath,
              isThermal: true,
            );
          },
        ),
        _ActionTile(
          icon: SolarIconsOutline.fileLeft,
          label: 'Simpan / Bagikan PDF',
          color: Colors.red,
          onTap: () {
            final settings = ref.read(settingsProvider);
            ref.read(documentServiceProvider).generateAndPrint(
              transaction: widget.transaction,
              sales: widget.sales,
              bengkelName: settings.workshopName,
              address: settings.workshopAddress,
              workshopWhatsapp: settings.workshopWhatsapp,
              logoPath: settings.workshopLogoPath,
              isThermal: false,
              isShare: true,
            );
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'SELESAI',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  ThemeData get theme => Theme.of(context);
}

class _PaymentOptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _PaymentOptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              if (trailing != null) ...[
                Container(
                  height: 24,
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: color.withValues(alpha: 0.2),
                ),
                trailing!,
              ] else ...[
                Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 20,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        dense: true,
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(SolarIconsOutline.altArrowRight, size: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.15), width: 1),
        ),
        tileColor: color.withValues(alpha: 0.1),
      ),
    );
  }
}

