import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';

// ─────────────────────────────────────────────────────────────
// ATELIER SKELETON — Centralized Shimmer Loading System
// (Phase 4 — UX Standardization)
//
// Digunakan di seluruh aplikasi untuk loading state yang konsisten
// dengan desain "Precision Atelier".
//
// Penggunaan:
//   AtelierSkeleton.transactionCard()   — Kartu transaksi
//   AtelierSkeleton.listItem()          — Item daftar umum
//   AtelierSkeleton.statCard()          — Kartu statistik
//   AtelierSkeleton.text(width: 120)    — Teks placeholder
//   AtelierSkeleton.circle(size: 40)    — Avatar / ikon
//   AtelierSkeleton.custom(child: ...)  — Bebas bentuk
// ─────────────────────────────────────────────────────────────

class AtelierSkeleton extends StatelessWidget {
  final Widget child;

  const AtelierSkeleton({super.key, required this.child});

  /// Wraps any widget with the Atelier shimmer effect.
  static Widget custom({required Widget child}) {
    return _AtelierShimmerWrapper(child: child);
  }

  // ── Predefined Skeletons ───────────────────────────────────

  /// Skeleton untuk kartu transaksi di HomeScreen
  static Widget transactionCard() {
    return _AtelierShimmerWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: avatar + title
              Row(
                children: [
                  _ShimmerBox(width: 44, height: 44, radius: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerBox(width: double.infinity, height: 14, radius: 6),
                        SizedBox(height: 6),
                        _ShimmerBox(width: 120, height: 12, radius: 6),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  _ShimmerBox(width: 70, height: 28, radius: 8),
                ],
              ),
              SizedBox(height: 12),
              // Divider placeholder
              _ShimmerBox(width: double.infinity, height: 1, radius: 0),
              SizedBox(height: 12),
              // Footer row: info chips
              Row(
                children: [
                  _ShimmerBox(width: 80, height: 22, radius: 11),
                  SizedBox(width: 8),
                  _ShimmerBox(width: 60, height: 22, radius: 11),
                  Spacer(),
                  _ShimmerBox(width: 90, height: 14, radius: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Skeleton untuk item daftar umum (Stok, Pelanggan, Staff, dll.)
  static Widget listItem({bool hasSubtitle = true}) {
    return _AtelierShimmerWrapper(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const _ShimmerBox(width: 48, height: 48, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ShimmerBox(width: double.infinity, height: 14, radius: 6),
                  if (hasSubtitle) ...[
                    const SizedBox(height: 6),
                    const _ShimmerBox(width: 160, height: 12, radius: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const _ShimmerBox(width: 60, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }

  /// Skeleton untuk kartu statistik (Statistik screen)
  static Widget statCard() {
    return _AtelierShimmerWrapper(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShimmerBox(width: 40, height: 40, radius: 12),
            SizedBox(height: 12),
            _ShimmerBox(width: 100, height: 24, radius: 6),
            SizedBox(height: 6),
            _ShimmerBox(width: 80, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }

  /// Skeleton untuk teks inline
  static Widget text({double width = double.infinity, double height = 14}) {
    return _AtelierShimmerWrapper(
      child: _ShimmerBox(width: width, height: height, radius: 6),
    );
  }

  /// Skeleton untuk avatar bulat
  static Widget circle({double size = 40}) {
    return _AtelierShimmerWrapper(
      child: _ShimmerBox(width: size, height: size, radius: size / 2),
    );
  }

  // ── Build untuk instance-based usage ──────────────────────
  @override
  Widget build(BuildContext context) {
    return _AtelierShimmerWrapper(child: child);
  }

  // ── Helper: Multiple items ──────────────────────────────────

  /// Render N buah skeleton berturut-turut dalam Column
  static Widget listOf(int count, Widget Function() itemBuilder) {
    return Column(
      children: List.generate(count, (_) => itemBuilder()),
    );
  }
}

// ── Internal: Shimmer Wrapper dengan tema Atelier ────────────

class _AtelierShimmerWrapper extends StatelessWidget {
  final Widget child;

  const _AtelierShimmerWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: isDark
          ? AppColors.surfaceLow.withValues(alpha: 0.8)
          : Colors.grey.withValues(alpha: 0.12),
      highlightColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.grey.withValues(alpha: 0.04),
      period: const Duration(milliseconds: 1200),
      child: child,
    );
  }
}

// ── Internal: Basic shimmer box ──────────────────────────────

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
