import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/expense_provider.dart';
import '../../../core/providers/pengaturan_provider.dart';
import '../../../domain/entities/expense.dart';
import '../../../core/widgets/atelier_list_card.dart';

class CreateExpenseScreen extends ConsumerStatefulWidget {
  final Expense? existingExpense;
  final int? prefilledAmount;
  final String? prefilledCategory;
  final DateTime? prefilledDate;
  final String? prefilledDescription;
  final double? aiConfidence;
  final String? extractedText;

  const CreateExpenseScreen({
    super.key,
    this.existingExpense,
    this.prefilledAmount,
    this.prefilledCategory,
    this.prefilledDate,
    this.prefilledDescription,
    this.aiConfidence,
    this.extractedText,
  });

  bool get isEditMode => existingExpense != null;
  bool get hasAiData => aiConfidence != null;

  @override
  ConsumerState<CreateExpenseScreen> createState() =>
      _CreateExpenseScreenState();
}

class _CreateExpenseScreenState extends ConsumerState<CreateExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  static final _dateFormat = DateFormat('dd MMMM yyyy', 'id_ID');

  @override
  void initState() {
    super.initState();
    final e = widget.existingExpense;
    if (e != null) {
      _amountController.text = e.amount.toString();
      _descriptionController.text = e.description ?? '';
      _selectedCategory = e.category;
      _selectedDate = e.date;
    } else {
      if (widget.prefilledAmount != null && widget.prefilledAmount! > 0) {
        _amountController.text = widget.prefilledAmount.toString();
      }
      _descriptionController.text = widget.prefilledDescription ?? '';
      _selectedCategory = widget.prefilledCategory;
      _selectedDate = widget.prefilledDate ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).colorScheme.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori pengeluaran')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final bengkelId = ref.read(settingsProvider).bengkelId;
      final amount = int.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;

      final expense = widget.existingExpense ??
          Expense(
            amount: amount,
            category: _selectedCategory!,
            bengkelId: bengkelId,
          );

      expense
        ..amount = amount
        ..category = _selectedCategory!
        ..date = _selectedDate
        ..description = _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim()
        ..isVerified = true;

      if (widget.aiConfidence != null) {
        expense.aiConfidence = widget.aiConfidence;
        expense.extractedText = widget.extractedText;
      }

      final notifier = ref.read(expenseListProvider(bengkelId).notifier);
      if (widget.isEditMode) {
        await notifier.updateExpense(expense);
      } else {
        await notifier.addExpense(expense);
      }

      HapticFeedback.mediumImpact();

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditMode
                  ? 'Pengeluaran berhasil diperbarui'
                  : 'Pengeluaran berhasil disimpan',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bengkelId = ref.watch(settingsProvider).bengkelId;
    final categories = ref.watch(expenseCategoryListProvider(bengkelId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.isEditMode ? 'Edit Pengeluaran' : 'Tambah Pengeluaran',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          children: [
            // AI Banner
            if (widget.hasAiData) ...[
              const SizedBox(height: 16),
              _AiBanner(confidence: widget.aiConfidence!),
            ],
            const SizedBox(height: 20),

            // Amount field
            AtelierListGroup(
              label: 'Jumlah',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: const Color(0xFFEF4444),
                    ),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      prefixStyle: GoogleFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      hintText: '0',
                      hintStyle: GoogleFonts.manrope(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      ),
                      border: InputBorder.none,
                    ),
                    validator: (val) {
                      final v = int.tryParse(
                            (val ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
                          ) ??
                          0;
                      if (v <= 0) return 'Masukkan jumlah pengeluaran';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Category
            AtelierListGroup(
              label: 'Kategori',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((cat) {
                      final isSelected = _selectedCategory == cat.logicKey;
                      final color = _parseCategoryColor(cat.colorHex, context);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(cat.name),
                        labelStyle: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                        selectedColor: color,
                        checkmarkColor: Colors.white,
                        backgroundColor:
                            color.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: isSelected
                              ? color
                              : color.withValues(alpha: 0.3),
                          width: isSelected ? 1.5 : 1,
                        ),
                        onSelected: (_) =>
                            setState(() => _selectedCategory = cat.logicKey),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Date
            AtelierListGroup(
              label: 'Tanggal',
              children: [
                AtelierListTile(
                  icon: SolarIconsOutline.calendar,
                  iconColor: theme.colorScheme.primary,
                  title: _dateFormat.format(_selectedDate),
                  onTap: _pickDate,
                  trailing: Icon(
                    SolarIconsOutline.calendar,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Description (optional)
            AtelierListGroup(
              label: 'Keterangan (opsional)',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tambahkan catatan...',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.isEditMode
                        ? 'Simpan Perubahan'
                        : 'Simpan Pengeluaran',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ),
    );
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
}

class _AiBanner extends StatelessWidget {
  final double confidence;

  const _AiBanner({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final isHigh = confidence >= 0.8;
    final color = isHigh ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final pct = (confidence * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isHigh
                ? SolarIconsBold.shieldCheck
                : SolarIconsOutline.shieldWarning,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHigh ? 'Data AI terdeteksi ($pct%)' : 'Data AI — perlu verifikasi ($pct%)',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: color,
                  ),
                ),
                Text(
                  'Periksa kembali sebelum menyimpan',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
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
