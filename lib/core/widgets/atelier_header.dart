import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import '../constants/app_colors.dart';
import 'standard_search_bar.dart';
import 'workshop_selector.dart';

/// ── ATELIER HEADER (MAIN) ──
/// Digunakan untuk Home, Katalog, Pelanggan, dan Riwayat.
/// Memiliki slot pencarian (SearchBar) bawaan.
class AtelierHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? icon; // Decorative header icon
  final Widget? leading;
  final List<Widget>? actions;
  final TextEditingController? searchController;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final BorderRadius? borderRadius;
  final double bottomPadding;
  final bool hideTopRow;
  final bool showWorkshopSelector;

  const AtelierHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.actions,
    this.searchController,
    this.searchHint,
    this.onSearchChanged,
    this.showBackButton = false,
    this.onBackPressed,
    this.borderRadius,
    this.bottomPadding = 12,
    this.hideTopRow = false,
    this.showWorkshopSelector = true,
  });

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final sub = subtitle;
    final ic = icon;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        statusBarHeight + 8,
        24,
        bottomPadding,
      ),
       decoration: BoxDecoration(
         gradient: AppColors.headerGradient(context),
         borderRadius: borderRadius,
         boxShadow: [
           BoxShadow(
             color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
             blurRadius: 32,
             offset: const Offset(0, 12),
           ),
         ],
       ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row TOP (Leading & Actions)
          if (!hideTopRow)
            SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  if (showBackButton)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        onPressed: onBackPressed ?? () => Navigator.pop(context),
                        icon: const Icon(
                          SolarIconsOutline.arrowLeft,
                          color: Colors.white,
                        ),
                       style: IconButton.styleFrom(
                         backgroundColor: Colors.white.withValues(alpha: 0.1),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(12),
                         ),
                         minimumSize: const Size(48, 48),
                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                       ),
                      ),
                    ),
                  leading ?? const SizedBox.shrink(),
                  if (showWorkshopSelector) 
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: WorkshopSelector(isDark: true),
                    ),
                  const Spacer(),

                  ...?actions,
                ],
              ),
            )
          else
            const SizedBox(height: 12),

          // Decorative page icon
          if (ic != null) ...[
            const SizedBox(height: 4),
            ic,
          ],

          const SizedBox(height: 12),

          // Title
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 0),
            Text(
              sub,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white70,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Search slot
          if (searchController != null || onSearchChanged != null) ...[
            const SizedBox(height: 12),
            StandardSearchBar(
              controller: searchController,
              hintText: searchHint ?? 'Cari...',
              onChanged: onSearchChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// ── ATELIER HEADER SUB ──
/// Dimensi lebih pendek, tanpa search bar.
/// Digunakan untuk sub-screen.
class AtelierHeaderSub extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool hideTopRow;
  final BorderRadius? borderRadius;
  final bool showWorkshopSelector;
  final double bottomPadding;

  const AtelierHeaderSub({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.showBackButton = true,
    this.onBackPressed,
    this.hideTopRow = false,
    this.borderRadius,
    this.showWorkshopSelector = false, // Default false for sub-headers
    this.bottomPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        MediaQuery.of(context).padding.top + 12,
        24,
        bottomPadding,
      ),
       decoration: BoxDecoration(
         gradient: AppColors.headerGradient(context),
         borderRadius: borderRadius,
         boxShadow: [
           BoxShadow(
             color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
             blurRadius: 32,
             offset: const Offset(0, 12),
           ),
         ],
       ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hideTopRow)
            const SizedBox(height: 48),

          if (!hideTopRow)
            SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  if (showBackButton)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: IconButton(
                        onPressed: onBackPressed ?? () => Navigator.pop(context),
                        icon: const Icon(
                          SolarIconsOutline.arrowLeft,
                          color: Colors.white,
                        ),
                       style: IconButton.styleFrom(
                         backgroundColor: Colors.white.withValues(alpha: 0.1),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(12),
                         ),
                         minimumSize: const Size(48, 48),
                         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                       ),
                      ),
                    ),
                  leading ?? const SizedBox.shrink(),
                  if (showWorkshopSelector) 
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: WorkshopSelector(isDark: true),
                    ),
                  const Spacer(),
                  ...?actions,
                ],
              ),
            ),

          const SizedBox(height: 4),

          // Title
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),

          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white70,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// ── SLIVER ATELIER HEADER (MAIN) ──
class SliverAtelierHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? icon; // Decorative header icon
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double? expandedHeight;
  final List<Widget>? actions;
  final Widget? leading;
  final TextEditingController? searchController;
  final String? searchHint;
  final ValueChanged<String>? onSearchChanged;
  final PreferredSizeWidget? bottom;
  final bool showWorkshopSelector;

  const SliverAtelierHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.showBackButton = true,
    this.onBackPressed,
    this.expandedHeight,
    this.actions,
    this.leading,
    this.searchController,
    this.searchHint,
    this.onSearchChanged,
    this.bottom,
    this.showWorkshopSelector = true,
  });

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        child: IconButton(
          icon: const Icon(SolarIconsOutline.arrowLeft, color: Colors.white),
          onPressed: onBackPressed ?? () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomHeight = bottom?.preferredSize.height ?? 0;

    final double calculatedExpandedHeight = expandedHeight ??
        ((searchController != null || onSearchChanged != null) ? 175 : 120) +
            statusBarHeight +
            bottomHeight;

    // FIX: collapsedHeight tanpa statusBarHeight — SliverAppBar sudah auto-handle statusBar offset
    final double collapsedHeight = kToolbarHeight + bottomHeight;

    return SliverAppBar(
      pinned: true,
      expandedHeight: calculatedExpandedHeight,
      collapsedHeight: collapsedHeight,
      toolbarHeight: kToolbarHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: actions,
      bottom: bottom,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;

          // FIX: threshold ketat dengan buffer minimal (+2) agar tidak over-collapse
          final double collapseThreshold =
              kToolbarHeight + statusBarHeight + bottomHeight + 2;

          final bool isCollapsed = top <= collapseThreshold;

          // FIX: opacity continuous (smooth fade) — bukan binary snap yang bisa ter-skip saat scroll cepat
           final double opacity =
               ((collapseThreshold + 40 - top) / 40).clamp(0.0, 1.0);

          return Container(
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient(context),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(isCollapsed ? 0 : 32),
              ),
              boxShadow: isCollapsed
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FlexibleSpaceBar(
              centerTitle: false,
              expandedTitleScale: 1.0,
              // FIX: Opacity biasa (bukan AnimatedOpacity) — AnimatedOpacity punya delay
              // internal yang bisa menyebabkan title invisible sejenak saat scroll cepat
              title: Opacity(
                opacity: opacity,
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              titlePadding: EdgeInsets.only(
                left: (leading == null && !showBackButton) ? 24 : 64,
                bottom: 16 + bottomHeight,
              ),
              background: AtelierHeader(
                title: title,
                subtitle: subtitle,
                icon: icon,
                showBackButton: showBackButton,
                onBackPressed: onBackPressed,
                searchController: searchController,
                searchHint: searchHint,
                onSearchChanged: onSearchChanged,
                hideTopRow: true,
                showWorkshopSelector: showWorkshopSelector,
                bottomPadding: 24,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
            ),
          );
        },
      ),
      leading:
          leading ?? (showBackButton ? _buildBackButton(context) : null),
    );
  }
}

/// ── SLIVER ATELIER HEADER SUB ──
class SliverAtelierHeaderSub extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final double? expandedHeight;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const SliverAtelierHeaderSub({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBackPressed,
    this.expandedHeight,
    this.actions,
    this.leading,
    this.bottom,
  });

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Center(
        child: IconButton(
          icon: const Icon(SolarIconsOutline.arrowLeft, color: Colors.white),
          onPressed: onBackPressed ?? () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomHeight = bottom?.preferredSize.height ?? 0;

    final double titleHeight = subtitle != null ? 50 : 36;

    final double calculatedExpandedHeight = expandedHeight ??
        (statusBarHeight + 48 + titleHeight + bottomHeight + 16);

    // FIX: collapsedHeight tanpa statusBarHeight
    final double collapsedHeight = kToolbarHeight + bottomHeight;

    return SliverAppBar(
      pinned: true,
      expandedHeight: calculatedExpandedHeight,
      collapsedHeight: collapsedHeight,
      toolbarHeight: kToolbarHeight,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: actions,
      bottom: bottom,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = constraints.biggest.height;

          // FIX: threshold ketat dengan buffer minimal (+2)
          final double collapseThreshold =
              kToolbarHeight + statusBarHeight + bottomHeight + 2;

          final bool isCollapsed = top <= collapseThreshold;

          // FIX: opacity continuous untuk smooth fade-in title
           final double opacity =
               ((collapseThreshold + 40 - top) / 40).clamp(0.0, 1.0);

          return Container(
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient(context),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(isCollapsed ? 0 : 32),
              ),
              boxShadow: isCollapsed
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: FlexibleSpaceBar(
              centerTitle: false,
              expandedTitleScale: 1.0,
              // FIX: Opacity biasa, bukan AnimatedOpacity
              title: Opacity(
                opacity: opacity,
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              titlePadding: EdgeInsets.only(
                left: (leading == null && !showBackButton) ? 24 : 64,
                bottom: 16 + bottomHeight,
              ),
              background: AtelierHeaderSub(
                title: title,
                subtitle: subtitle,
                showBackButton: showBackButton,
                onBackPressed: onBackPressed,
                hideTopRow: true,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
            ),
          );
        },
      ),
      leading:
          leading ?? (showBackButton ? _buildBackButton(context) : null),
    );
  }
}

