import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    
    if (bengkelId == null) return const SizedBox.shrink();

    final activeDebts = ref.watch(activeDebtsProvider(bengkelId));
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildTotalHeader(activeDebts, currencyFormat, theme, isDark),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          sliver: activeDebts.isEmpty
              ? SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState(theme))
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final debt = activeDebts[index];
                      return _DebtCard(
                        debt: debt,
                        currencyFormat: currencyFormat,
                        isDark: isDark,
                      );
                    },
                    childCount: activeDebts.length,
                  ),
                ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildTotalHeader(
    List<Expense> debts,
    NumberFormat currencyFormat,
    ThemeData theme,
    bool isDark,
  ) {
    final totalDebt = debts.fold<double>(0, (sum, item) => sum + (item.debtBalance ?? 0));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning,
            AppColors.warning.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.3),
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
              const Icon(SolarIconsBold.walletMoney, color: Color(0xFF1A1528), size: 18),
              const SizedBox(width: 8),
              Text(
                'Total Hutang Aktif',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF1A1528).withValues(alpha: 0.6),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(totalDebt),
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF1A1528),
              fontWeight: FontWeight.w900,
              fontSize: 32,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(SolarIconsBold.infoCircle, size: 14, color: Color(0xFF1A1528)),
                const SizedBox(width: 6),
                Text(
                  '${debts.length} Tagihan Menunggu Pelunasan',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF1A1528),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
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
            size: 64,
            color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Semua Hutang Lunas!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tidak ada tagihan supplier yang aktif',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontWeight: FontWeight.w500,
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
  final bool isDark;

  const _DebtCard({
    required this.debt,
    required this.currencyFormat,
    required this.isDark,
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
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: !isDark ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ] : [],
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
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      debt.description ?? 'Pembelian Stok',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(debt.debtStatus ?? 'HUTANG', theme),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sisa Tagihan',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currencyFormat.format(remaining),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Pagu Awal',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  Text(
                    currencyFormat.format(debt.amount),
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress with label
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                AppHaptic.light();
                showDialog(
                  context: context,
                  builder: (context) => PayDebtDialog(debt: debt),
                );
              },
              icon: const Icon(SolarIconsOutline.cardTransfer, size: 18),
              label: Text(
                'PELUNASAN TAGIHAN',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status, ThemeData theme) {
    final color = status == 'PARTIAL' ? Colors.orange : theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

