import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/expense_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../domain/entities/expense.dart';
import '../../../core/utils/app_haptic.dart';
import '../widgets/pay_debt_dialog.dart';

class HutangTab extends ConsumerWidget {
  const HutangTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bengkelId = ref.watch(bengkelIdProvider);
    
    if (bengkelId == null) return const SizedBox.shrink();

    final activeDebts = ref.watch(activeDebtsProvider(bengkelId));
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Column(
      children: [
        _buildTotalHeader(activeDebts, currencyFormat, theme),
        Expanded(
          child: activeDebts.isEmpty
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: activeDebts.length,
                  itemBuilder: (context, index) {
                    final debt = activeDebts[index];
                    return _DebtCard(
                      debt: debt,
                      currencyFormat: currencyFormat,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTotalHeader(
    List<Expense> debts,
    NumberFormat currencyFormat,
    ThemeData theme,
  ) {
    final totalDebt = debts.fold<double>(0, (sum, item) => sum + (item.debtBalance ?? 0));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.error,
            theme.colorScheme.error.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.error.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(SolarIconsBold.walletMoney, color: theme.colorScheme.onError, size: 20),
              const SizedBox(width: 8),
              Text(
                'Total Hutang Aktif',
                style: GoogleFonts.plusJakartaSans(
                  color: theme.colorScheme.onError.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(totalDebt),
            style: GoogleFonts.plusJakartaSans(
              color: theme.colorScheme.onError,
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${debts.length} Transaksi Belum Lunas',
              style: GoogleFonts.plusJakartaSans(
                color: theme.colorScheme.onError,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            SolarIconsOutline.checkCircle,
            size: 80,
            color: theme.colorScheme.tertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Semua Hutang Lunas!',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada tagihan supplier yang aktif',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  final Expense debt;
  final NumberFormat currencyFormat;

  const _DebtCard({
    required this.debt,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remaining = debt.debtBalance ?? 0;
    final progress = 1 - (remaining / debt.amount);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.supplierName ?? 'Supplier Tidak Dikenal',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      debt.description ?? 'Pembelian Stok',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (debt.debtStatus == 'PARTIAL' ? Colors.orange : Colors.red)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  debt.debtStatus ?? 'HUTANG',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: debt.debtStatus == 'PARTIAL' ? Colors.orange : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sisa Hutang',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    currencyFormat.format(remaining),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Total Awal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    currencyFormat.format(debt.amount),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.5 ? theme.colorScheme.tertiary : Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                AppHaptic.light();
                showDialog(
                  context: context,
                  builder: (context) => PayDebtDialog(debt: debt),
                );
              },
              icon: const Icon(SolarIconsOutline.cardTransfer, size: 18),
              label: const Text('Bayar Cicilan / Lunas'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
