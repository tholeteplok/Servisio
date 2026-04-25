import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/app_icons.dart';
import '../../core/providers/transaction_providers.dart';
import '../../core/providers/sale_providers.dart';
import '../../core/providers/master_providers.dart';
import '../../core/providers/pelanggan_provider.dart';
import '../../core/providers/media_provider.dart';
import '../../core/widgets/atelier_list_card.dart';
import '../../core/widgets/glass_card.dart';
import '../../domain/entities/pelanggan.dart';
import '../../domain/entities/vehicle.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/sale.dart';
import 'create_pelanggan_screen.dart';
import 'create_vehicle_screen.dart';
import '../../core/widgets/critical_action_guard.dart';
import '../../core/services/session_manager.dart';
import '../../core/widgets/standard_dialog.dart';

class PelangganDetailScreen extends ConsumerWidget {
  final Pelanggan pelanggan;
  const PelangganDetailScreen({super.key, required this.pelanggan});

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final mediaService = ref.read(mediaServiceProvider);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.customer.changeProfilePhoto,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPickerOption(
                  context,
                  icon: SolarIconsOutline.camera,
                  label: AppStrings.common.camera,
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                  theme: Theme.of(context),
                ),
                _buildPickerOption(
                  context,
                  icon: SolarIconsOutline.gallery,
                  label: AppStrings.common.gallery,
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                  theme: Theme.of(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final image = await mediaService.pickImage(source);
      if (image != null) {
        final path = await mediaService.saveImageLocally(image);
        if (path != null) {
          ref
              .read(pelangganListProvider.notifier)
              .updatePhoto(pelanggan.id, path);
        }
      }
    }
  }

  Widget _buildPickerOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = ref
        .watch(pelangganListProvider)
        .firstWhere((e) => e.id == pelanggan.id, orElse: () => pelanggan);

    final vehicles = ref.watch(customerVehiclesProvider(p.id));
    final transactions = ref.watch(customerTransactionsProvider(p.id));
    final sales = ref.watch(customerSalesProvider(p.nama));

    // Combine and sort history
    final history = [...transactions, ...sales];
    history.sort((a, b) {
      final dateA = (a is Transaction) ? a.createdAt : (a as Sale).createdAt;
      final dateB = (b is Transaction) ? b.createdAt : (b as Sale).createdAt;
      return dateB.compareTo(dateA);
    });

    // Calculate total spending
    final totalSpending =
        transactions.fold(0.0, (sum, item) => sum + item.totalAmount) +
        sales.fold(0.0, (sum, item) => sum + item.totalPrice);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildHeader(context, ref, theme, p),
          _buildStatsRow(
            context,
            theme,
            vehicles.length,
            transactions.length,
            totalSpending,
          ),
          _buildInfoSection(theme, p),
          _buildVehiclesSection(context, theme, p, vehicles),
          _buildHistoryHeader(context, theme),
          _buildHistoryList(context, theme, history),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Pelanggan p,
  ) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final isDark = theme.brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(20, statusBarHeight + 12, 20, 24),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-1.1, -1.1),
            radius: 1.5,
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.5),
            ],
            stops: const [0.6, 1.0],
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    LucideIcons.chevronLeft,
                    color: theme.colorScheme.onPrimary,
                  ),
                  tooltip: AppStrings.common.back,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        AppIcons.edit,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                      tooltip: AppStrings.common.edit,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: 0.1),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CreatePelangganScreen(initialPelanggan: p),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        AppIcons.delete,
                        color: isDark ? theme.colorScheme.error : Colors.white,
                        size: 20,
                      ),
                      tooltip: AppStrings.common.delete,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: theme.colorScheme.error.withValues(alpha: isDark ? 0.2 : 0.8,),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        CriticalActionGuard.check(
                          ref,
                          context,
                          CriticalActionType.deleteCustomer,
                        ).then((verified) {
                          if (verified && context.mounted) {
                            _confirmDelete(context, ref, p);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            blurRadius: 32,
                            spreadRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _pickImage(context, ref),
                    borderRadius: BorderRadius.circular(64),
                    splashColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                    highlightColor: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'pelanggan_avatar_${p.id}',
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: p.photoLocalPath != null
                              ? FileImage(File(p.photoLocalPath!))
                              : null,
                          child: p.photoLocalPath == null
                              ? Text(
                                  p.nama.isNotEmpty
                                      ? p.nama[0].toUpperCase()
                                      : '?',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => _pickImage(context, ref),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          SolarIconsOutline.camera,
                          color: theme.colorScheme.onPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              p.nama,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -1,
              ),
            ),
            Text(
              p.telepon,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    ThemeData theme,
    int vehicleCount,
    int visitCount,
    double totalSpending,
  ) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3,),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            _buildStatItem(context, AppStrings.customer.vehicles, vehicleCount.toString()),
            _buildStatDivider(theme),
            _buildStatItem(context, AppStrings.customer.visits, visitCount.toString()),
            _buildStatDivider(theme),
            _buildStatItem(
              context,
              AppStrings.customer.totalSpending,
              NumberFormat.compactCurrency(
                locale: 'id',
                symbol: 'Rp',
              ).format(totalSpending),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider(ThemeData theme) {
    return Container(
      width: 1,
      height: 30,
      color: theme.dividerColor.withValues(alpha: 0.1),
    );
  }

  Widget _buildInfoSection(ThemeData theme, Pelanggan p) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 2),
        child: Column(
          children: [
            _buildInfoTile(
              theme,
              icon: AppIcons.location,
              label: AppStrings.customer.addressLabel,
              value: p.alamat.isNotEmpty ? p.alamat : AppStrings.common.none,
            ),
            if (p.catatan.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildInfoTile(
                theme,
                icon: SolarIconsOutline.notes,
                label: AppStrings.customer.noteLabel,
                value: p.catatan,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: AtelierListTile(
        padding: const EdgeInsets.all(16),
        customLeading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        customTitle: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
        customSubtitle: Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        onTap: () {},
        trailing: const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildVehiclesSection(
    BuildContext context,
    ThemeData theme,
    Pelanggan p,
    List<Vehicle> vehicles,
  ) {
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppStrings.customer.vehicles.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateVehicleScreen(pelanggan: p),
                    ),
                  ),
                  icon: const Icon(AppIcons.add, size: 18),
                  label: Text(
                    AppStrings.common.addShort,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          if (vehicles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassCard(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.layoutGrid,
                        size: 48,
                        color: theme.dividerColor.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppStrings.customer.noVehiclesReg,
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4,),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final v = vehicles[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateVehicleScreen(
                            pelanggan: p,
                            initialVehicle: v,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: theme.dividerColor.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                v.type.toLowerCase().contains(AppStrings.customer.mobil.toLowerCase())
                                    ? LucideIcons.car
                                    : LucideIcons.bike,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              v.plate,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              v.model,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryHeader(BuildContext context, ThemeData theme) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        child: Text(
          AppStrings.customer.historyActivity,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    ThemeData theme,
    List<dynamic> history,
  ) {
    if (history.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassCard(
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.history,
                    size: 40,
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.customer.noTransactionHistory,
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = history[index];
            final bool isTransaction = item is Transaction;
            final date =
                isTransaction ? item.createdAt : (item as Sale).createdAt;
            final amount =
                isTransaction ? item.totalAmount : (item as Sale).totalPrice;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: AtelierListTile(
                  padding: const EdgeInsets.all(16),
                  icon: isTransaction
                      ? LucideIcons.fileText
                      : LucideIcons.shoppingCart,
                   iconColor: isTransaction ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  title: isTransaction
                      ? (item.vehiclePlate.isNotEmpty
                          ? item.vehiclePlate
                          : AppStrings.common.service)
                      : item.itemName,
                  customSubtitle: Row(
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy', 'id').format(date),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color:
                              theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                      if (isTransaction) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(theme, item.status)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.status.toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: _getStatusColor(theme, item.status),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Text(
                    NumberFormat.compactCurrency(
                      locale: 'id',
                      symbol: 'Rp',
                    ).format(amount),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  onTap: () {
                    // Navigate to detail if needed
                  },
                ),
              ),
            );
          },
          childCount: history.length,
        ),
      ),
    );
  }

  Color _getStatusColor(ThemeData theme, String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'antri':
        return theme.colorScheme.secondary;
      case 'in_progress':
      case 'dikerjakan':
        return theme.colorScheme.tertiary;
      case 'completed':
      case 'selesai':
        return theme.colorScheme.primary;
      case 'lunas':
        return theme.colorScheme.primary;
      default:
        return theme.colorScheme.outline;
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Pelanggan p) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierColor: theme.shadowColor.withValues(alpha: 0.3),
      builder: (context) => StandardDialog(
        icon: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            SolarIconsOutline.trashBinTrash,
            color: theme.colorScheme.error,
            size: 36,
          ),
        ),
        title: AppStrings.customer.confirmDeleteTitle,
        message: AppStrings.customer.deleteConfirmation(p.nama),
        primaryActionLabel: AppStrings.common.delete,
        primaryActionColor: theme.colorScheme.error,
        onPrimaryAction: () {
          ref.read(pelangganListProvider.notifier).remove(p.id);
          Navigator.pop(context); // dialog
          Navigator.pop(context); // detail screen
        },
        secondaryActionLabel: AppStrings.common.cancel,
      ),
    );
  }
}

