import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/app_haptic.dart';
import '../../core/widgets/atelier_header.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/providers/reminder_provider.dart';
import '../../core/providers/pengaturan_provider.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/services/document_service.dart';
import '../../domain/entities/transaction.dart';

class ReminderScreen extends ConsumerWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(reminderTransactionsProvider);
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAtelierHeaderSub(
            title: AppStrings.reminder.title,
            subtitle: AppStrings.reminder.subtitle,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
            sliver: reminders.isEmpty
              ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      title: AppStrings.reminder.emptyTitle,
                      message: AppStrings.reminder.emptyMessage,
                      iconData: SolarIconsOutline.bellOff,
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final trx = reminders[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _ReminderCard(trx: trx, settings: settings),
                      );
                    }, childCount: reminders.length),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

}

class _ReminderCard extends ConsumerStatefulWidget {
  final Transaction trx;
  final SettingsState settings;

  const _ReminderCard({required this.trx, required this.settings});

  @override
  ConsumerState<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<_ReminderCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = widget.trx.isOverdue;
    final statusColor = isOverdue ? Colors.red : Colors.orange;
    final nextDate = widget.trx.nextServiceDate;
    final dateStr = nextDate != null
        ? DateFormat(AppStrings.date.displayDate).format(nextDate)
        : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: [
            // Header Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              color: statusColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(
                    isOverdue
                        ? SolarIconsBold.dangerSquare
                        : SolarIconsBold.bell,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isOverdue ? AppStrings.reminder.overdue : AppStrings.reminder.upcoming,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.trx.customerName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.amethyst.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.trx.vehiclePlate,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.amethyst,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.trx.vehicleModel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              SolarIconsOutline.calendar,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.reminder.estimateLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dateStr,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                        if (widget.trx.targetServiceKm != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                SolarIconsOutline.rulerAngular,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                AppStrings.reminder.kmTargetLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.trx.targetServiceKm}${AppStrings.reminder.kmSuffix}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // WhatsApp Button
                  Material(
                    color: _isLoading 
                        ? Colors.grey.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _isLoading ? null : () async {
                        setState(() => _isLoading = true);
                        try {
                          AppHaptic.light();
                          await ref.read(documentServiceProvider).sendReminderWhatsApp(
                            phone: widget.trx.customerPhone,
                            transaction: widget.trx,
                            bengkelName: widget.settings.workshopName,
                          );

                          // 🔥 Anti-Spam: Update waktu pengiriman terakhir
                          widget.trx.lastReminderSentAt = DateTime.now();
                          await ref
                              .read(transactionListProvider.notifier)
                              .updateTransaction(widget.trx);
                        } finally {
                          if (mounted) setState(() => _isLoading = false);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        child: _isLoading 
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.green,
                              ),
                            )
                          : const Icon(
                            SolarIconsBold.outgoingCall,
                            color: Colors.green,
                          ),
                      ),
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
}

