import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../domain/entities/expense.dart';
import '../../../domain/entities/expense_category.dart';

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
    final cat = _category;
    final catColor = _parseCategoryColor(cat?.colorHex, context);
    final catName = cat?.name ?? expense.category;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header (Category & Date)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _categoryEmoji(expense.category),
                          style: const TextStyle(fontSize: 10),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          catName,
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: catColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd MMM yyyy').format(expense.date),
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Body (Description & Amount)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description?.isNotEmpty == true
                              ? expense.description!
                              : catName,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (expense.isFromOcr) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Entri via AI Assistant',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    _currency.format(expense.amount),
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFEF4444), // Expense red
                    ),
                  ),
                ],
              ),

              // 3. Status Section (if applicable)
              if (expense.debtStatus != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (expense.debtStatus == 'LUNAS' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        expense.debtStatus == 'LUNAS' ? SolarIconsOutline.checkCircle : SolarIconsOutline.infoCircle,
                        size: 14,
                        color: expense.debtStatus == 'LUNAS' ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        expense.debtStatus!,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: expense.debtStatus == 'LUNAS' ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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

