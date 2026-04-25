import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/expense_provider.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../domain/entities/expense.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../core/widgets/atelier_list_card.dart';
import 'create_expense_screen.dart';

class ExpenseDetailScreen extends ConsumerWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _dateFormat = DateFormat('EEEE, dd MMMM yyyy', 'id_ID');

  Color _parseCategoryColor(String? hex, BuildContext context) {
    if (hex == null || hex.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }
    try {
      final cleaned = hex.replaceFirst('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bengkelId = ref.watch(settingsProvider).bengkelId;
    final categories = ref.watch(expenseCategoryListProvider(bengkelId));

    ExpenseCategory? cat;
    try {
      cat = categories.firstWhere((c) => c.logicKey == expense.category);
    } catch (_) {}

    final catColor = _parseCategoryColor(cat?.colorHex, context);
    final catName = cat?.name ?? expense.category;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Detail Pengeluaran',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(SolarIconsOutline.penNewSquare),
            tooltip: 'Edit',
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) =>
                      CreateExpenseScreen(existingExpense: expense),
                ),
              );
              if (result == true && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
          IconButton(
            icon: const Icon(
              SolarIconsOutline.trashBinMinimalistic,
              color: Color(0xFFEF4444),
            ),
            tooltip: 'Hapus',
            onPressed: () => _confirmDelete(context, ref, bengkelId),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
        children: [
          // Amount hero
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFEF4444).withValues(alpha: 0.15),
                  const Color(0xFFFEE2E2).withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        catName,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: catColor,
                        ),
                      ),
                    ),
                    if (expense.isFromOcr) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: expense.isHighConfidenceAI
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'AI • ${((expense.aiConfidence ?? 0) * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: expense.isHighConfidenceAI
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _currency.format(expense.amount),
                  style: GoogleFonts.manrope(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _dateFormat.format(expense.date),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details
          AtelierListGroup(
            label: 'Detail',
            children: [
              if (expense.description?.isNotEmpty == true)
                AtelierListTile(
                  icon: SolarIconsOutline.fileText,
                  iconColor: AppColors.info,
                  title: 'Keterangan',
                  subtitle: expense.description,
                  onTap: () {},
                  trailing: const SizedBox.shrink(),
                ),
              AtelierListTile(
                icon: SolarIconsOutline.calendar,
                iconColor: AppColors.precisionViolet,
                title: 'Tanggal Input',
                subtitle: _dateFormat.format(expense.createdAt),
                onTap: () {},
                trailing: const SizedBox.shrink(),
              ),
              if (expense.isVerified)
                AtelierListTile(
                  icon: SolarIconsOutline.shieldCheck,
                  iconColor: AppColors.success,
                  title: 'Status',
                  subtitle: 'Sudah diverifikasi',
                  onTap: () {},
                  trailing: const SizedBox.shrink(),
                ),
            ],
          ),

          // Photo
          if (expense.photoPath != null) ...[
            const SizedBox(height: 24),
            AtelierListGroup(
              label: 'Foto Nota',
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      File(expense.photoPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 120,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Icon(
                            SolarIconsOutline.gallery,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // OCR text (collapsed by default)
          if (expense.extractedText?.isNotEmpty == true) ...[
            const SizedBox(height: 24),
            AtelierListGroup(
              label: 'Teks OCR',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    expense.extractedText!,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String bengkelId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Hapus Pengeluaran?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Data pengeluaran ini akan dihapus. Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await ref
          .read(expenseListProvider(bengkelId).notifier)
          .deleteExpense(expense.id);
      if (context.mounted) Navigator.of(context).pop(true);
    }
  }
}

