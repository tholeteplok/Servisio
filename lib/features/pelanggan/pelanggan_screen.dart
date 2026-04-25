import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../core/constants/app_strings.dart';
import '../../core/providers/pelanggan_provider.dart';
import '../../core/widgets/atelier_list_card.dart';
import '../../core/widgets/standard_dialog.dart';
import '../../domain/entities/pelanggan.dart';
import 'pelanggan_detail_screen.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/widgets/atelier_header.dart';
import '../main/responsive_layout_builder.dart';
import '../../core/widgets/critical_action_guard.dart';
import '../../core/services/session_manager.dart';

class PelangganScreen extends ConsumerStatefulWidget {
  const PelangganScreen({super.key});

  @override
  ConsumerState<PelangganScreen> createState() => _PelangganScreenState();
}

class _PelangganScreenState extends ConsumerState<PelangganScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔍 Listen to navigation changes to clear search
    ref.listen(navigationProvider, (previous, next) {
      if (next != 1) {
        // 1 is Pelanggan tab
        _searchController.clear();
      }
    });

    final theme = Theme.of(context);
    final pelangganList = ref.watch(pelangganListProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAtelierHeader(
            title: AppStrings.customer.title,
            subtitle: AppStrings.customer.subtitle,
            showBackButton: false,
            searchController: _searchController,
            searchHint: AppStrings.customer.searchHint,
            onSearchChanged: (val) =>
                ref.read(pelangganListProvider.notifier).updateSearch(val),
            actions: [
              IconButton(
                onPressed: () => ref.invalidate(pelangganListProvider),
                icon: Icon(SolarIconsOutline.refresh,
                    color: theme.colorScheme.onSurface, size: 20),
                tooltip: AppStrings.common.refresh,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),

          pelangganList.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          SolarIconsOutline.usersGroupTwoRounded,
                          size: 64,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.customer.emptyMessage,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final p = pelangganList[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PelangganCard(pelanggan: p),
                      );
                    }, childCount: pelangganList.length),
                  ),
                ),
        ],
      ),
    );
  }
}

class _PelangganCard extends ConsumerWidget {
  final Pelanggan pelanggan;
  const _PelangganCard({required this.pelanggan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AtelierListGroup(
      children: [
        AtelierListTile(
          customLeading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              image: pelanggan.photoLocalPath != null
                  ? DecorationImage(
                      image: ResizeImage(
                        FileImage(File(pelanggan.photoLocalPath!)),
                        width: 150,
                      ),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: pelanggan.photoLocalPath == null
                ? Text(
                    pelanggan.nama.characters.isNotEmpty
                        ? pelanggan.nama.characters.first.toUpperCase()
                        : '?',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          title: pelanggan.nama,
          subtitle: pelanggan.telepon,
          onTap: () => AdaptiveNavigator.push(
            context: context,
            ref: ref,
            detailContent: PelangganDetailScreen(pelanggan: pelanggan),
            routeBuilder: () => PelangganDetailScreen(pelanggan: pelanggan),
          ),
          onLongPress: () {
            CriticalActionGuard.check(
              ref,
              context,
              CriticalActionType.deleteCustomer,
            ).then((verified) {
              if (verified && context.mounted) {
                _confirmDelete(context, ref);
              }
            });
          },
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
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
        message: AppStrings.customer.deleteConfirmation(pelanggan.nama),
        primaryActionLabel: AppStrings.common.delete,
        primaryActionColor: theme.colorScheme.error,
        onPrimaryAction: () {
          ref.read(pelangganListProvider.notifier).remove(pelanggan.id);
          Navigator.pop(context);
        },
        secondaryActionLabel: AppStrings.common.cancel,
      ),
    );
  }
}

