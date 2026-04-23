import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/expense.dart';
import '../../../domain/entities/expense_category.dart';
import '../../../core/widgets/atelier_list_card.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final List<ExpenseCategory> categories;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ExpenseCard({
    super.key,
    required this.expense,
    required this.categories,
    required this.onTap,
    this.onLongPress,
  });

  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _dateFormat = DateFormat('dd MMM yyyy', 'id_ID');

  ExpenseCategory? get _category {
    try {
      return categories.firstWhere((c) => c.logicKey == expense.category);
    } catch (_) {
      return null;
    }
  }

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cat = _category;
    final catColor = _parseCategoryColor(cat?.colorHex, context);
    final catName = cat?.name ?? expense.category;

    return AtelierListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      customLeading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: catColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            _categoryEmoji(expense.category),
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
      customTitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  expense.description?.isNotEmpty == true
                      ? expense.description!
                      : catName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (expense.isFromOcr)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: expense.isHighConfidenceAI
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'AI',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: expense.isHighConfidenceAI
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  catName,
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: catColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _dateFormat.format(expense.date),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (expense.debtStatus != null)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (expense.debtStatus == 'LUNAS' ? Colors.green : (expense.debtStatus == 'PARTIAL' ? Colors.orange : Colors.red)).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    expense.debtStatus!,
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: (expense.debtStatus == 'LUNAS' ? Colors.green : (expense.debtStatus == 'PARTIAL' ? Colors.orange : Colors.red)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      trailing: Text(
        _currency.format(expense.amount),
        style: GoogleFonts.manrope(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: const Color(0xFFEF4444),
        ),
      ),
    );
  }

  String _categoryEmoji(String logicKey) {
    const map = {
      'LISTRIK': '⚡',
      'AIR': '💧',
      'GAJI': '👥',
      'SEWA': '🏪',
      'BELI_STOK': '📦',
      'INTERNET': '📶',
      'TRANSPORT': '🚚',
      'LAINNYA': '📋',
    };
    return map[logicKey] ?? '📋';
  }
}
