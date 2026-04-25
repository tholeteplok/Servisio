import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_icons.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/standard_dialog.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/pengaturan_provider.dart';
import '../../core/widgets/critical_action_guard.dart';
import '../../core/widgets/atelier_header.dart';
import '../../core/services/session_manager.dart';
import '../../domain/entities/transaction.dart' as entity;

class TransactionDetailScreen extends ConsumerWidget {
  final entity.Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat(AppStrings.date.fullDateTime, AppStrings.date.localeID);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── Gold Standard Header Section ──
          SliverAtelierHeaderSub(
            title: transaction.trxNumber,
            subtitle: dateFormat.format(transaction.createdAt),
            actions: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    transaction.status.toUpperCase() == 'PAID'
                        ? AppStrings.transaction.statusPaid
                        : transaction.status.toUpperCase() == 'UNPAID'
                            ? AppStrings.transaction.statusUnpaid
                            : transaction.status.toUpperCase(),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
              CriticalActionGuard(
                actionType: CriticalActionType.deleteTransaction,
                onVerified: () => _confirmDelete(context, ref),
                child: IconButton(
                  onPressed: null, // Guard will handle the tap
                  icon: const Icon(
                    SolarIconsOutline.trashBinTrash,
                    color: Colors.white,
                  ),
                  tooltip: AppStrings.transaction.deleteTrxTooltip,
                  style: const ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(Size(48, 48)),
                    // Note: original had custom style, using standard IconButton.styleFrom for cleaner migration if needed, 
                    // but keeping logic consistent with existing guard pattern.
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Details Section ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),
                _buildReminderBanner(context, ref),
                _buildInfoSection(
                  context,
                  title: AppStrings.transaction.sectionCustomerDetail,
                  children: [
                    _DetailRow(
                      icon: SolarIconsOutline.user,
                      label: AppStrings.transaction.customerName,
                      value: transaction.customerName,
                    ),
                    _DetailRow(
                      icon: SolarIconsOutline.phone,
                      label: AppStrings.transaction.phoneNumber,
                      value: transaction.customerPhone,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoSection(
                  context,
                  title: AppStrings.transaction.sectionVehicleDetail,
                  children: [
                    _DetailRow(
                      icon: SolarIconsOutline.scooter,
                      label: AppStrings.transaction.vehicleModel,
                      value: transaction.vehicleModel,
                    ),
                    _DetailRow(
                      icon: SolarIconsOutline.plate,
                      label: AppStrings.transaction.plateNumber,
                      value: transaction.vehiclePlate,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoSection(
                  context,
                  title: AppStrings.transaction.sectionCostTime,
                  children: [
                    _DetailRow(
                      icon: SolarIconsOutline.wadOfMoney,
                      label: AppStrings.transaction.totalCost,
                      value:
                          'Rp ${NumberFormat('#,###', 'id_ID').format(transaction.totalAmount)}',
                      valueColor: theme.colorScheme.primary,
                      isBold: true,
                    ),
                    _DetailRow(
                      icon: SolarIconsOutline.calendar,
                      label: AppStrings.transaction.transactionDate,
                      value: dateFormat.format(transaction.createdAt),
                    ),
                    if (transaction.mechanicName != null)
                      _DetailRow(
                        icon: SolarIconsOutline.userHandUp,
                        label: AppStrings.transaction.labelTechnician,
                        value: transaction.mechanicName!,
                      ),
                    if (transaction.paymentMethod != null)
                      _DetailRow(
                        icon: SolarIconsOutline.cardTransfer,
                        label: AppStrings.transaction.paymentMethod,
                        value: transaction.paymentMethod!,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (transaction.complaint != null ||
                    transaction.mechanicNotes != null) ...[
                  _buildInfoSection(
                    context,
                    title: AppStrings.transaction.sectionServiceNotes,
                    children: [
                      if (transaction.complaint != null)
                        _DetailRow(
                          icon: SolarIconsOutline.notes,
                          label: AppStrings.transaction.complaint,
                          value: transaction.complaint!,
                        ),
                      if (transaction.mechanicNotes != null)
                        _DetailRow(
                          icon: SolarIconsOutline.pen,
                          label: AppStrings.transaction.techNotesTitle,
                          value: transaction.mechanicNotes!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (transaction.recommendationTimeMonth != null ||
                    transaction.recommendationKm != null) ...[
                  _buildInfoSection(
                    context,
                    title: AppStrings.transaction.sectionReturnRecommendation,
                    children: [
                      if (transaction.recommendationTimeMonth != null)
                        _DetailRow(
                          icon: SolarIconsOutline.calendar,
                          label: AppStrings.transaction.byTime,
                          value: AppStrings.transaction.returnMonthsValue(transaction.recommendationTimeMonth!),
                          valueColor: theme.colorScheme.primary,
                        ),
                      if (transaction.recommendationKm != null)
                        _DetailRow(
                          icon: SolarIconsOutline.map,
                          label: AppStrings.transaction.byDistance,
                          value: AppStrings.transaction.returnDistanceValue(NumberFormat('#,###', 'id_ID').format(transaction.recommendationKm)),
                          valueColor: theme.colorScheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                _buildInfoSection(
                  context,
                  title: AppStrings.transaction.sectionServiceItems,
                  children: transaction.items.isEmpty
                      ? [Text(AppStrings.transaction.noItemsRecorded)]
                      : transaction.items
                            .map(
                              (item) => Column(
                                children: [
                                  _DetailRow(
                                    icon: item.isService
                                        ? AppIcons.service
                                        : SolarIconsOutline.box,
                                    label: '${item.quantity}x ${item.name}',
                                    value:
                                        'Rp ${NumberFormat('#,###', 'id_ID').format(item.subtotal)}',
                                    isBold: false,
                                  ),
                                  if (transaction.items.last != item)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 48),
                                      child: Divider(height: 1),
                                    ),
                                ],
                              ),
                            )
                            .toList(),
                ),
                const SizedBox(height: 12),

                // ── Photo Proof Section ──
                if (transaction.photoLocalPath != null &&
                    File(transaction.photoLocalPath!).existsSync())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          AppStrings.transaction.sectionPhotos,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        height: 400,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.file(
                            File(transaction.photoLocalPath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderBanner(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isOverdue = transaction.isOverdue;
    final isDueSoon = transaction.isDueSoon(settings.reminderThresholdDays);

    if (!isOverdue && !isDueSoon) return const SizedBox.shrink();

    final Color color = isOverdue ? Colors.red : Colors.orange;
    final String text = isOverdue
        ? AppStrings.transaction.overdueBanner
        : AppStrings.transaction.dueSoonBanner;
    final nextDate = transaction.nextServiceDate;
    final dateStr = nextDate != null
        ? DateFormat(AppStrings.date.displayDate).format(nextDate)
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isOverdue ? SolarIconsBold.dangerCircle : SolarIconsBold.bell,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.transaction.followUpMessage(dateStr),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.05),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StandardDialog(
        icon: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            SolarIconsOutline.trashBinTrash,
            color: Colors.red,
            size: 36,
          ),
        ),
        title: AppStrings.transaction.deleteTrxTitle,
        message: AppStrings.transaction.deleteTrxDesc,
        primaryActionLabel: AppStrings.common.delete,
        primaryActionColor: Colors.red,
        onPrimaryAction: () {
          ref.read(transactionListProvider.notifier).deleteTransaction(
                transaction.id,
                transaction.uuid,
              );
          Navigator.pop(context); // Close dialog
          Navigator.pop(context); // Close detail screen
        },
        secondaryActionLabel: AppStrings.common.cancel,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                    color:
                        valueColor ?? Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

