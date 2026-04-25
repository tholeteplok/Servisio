import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/device_session_service.dart';
import '../../../core/providers/system_providers.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Layar yang tampil di perangkat LAMA saat session-nya dicabut.
/// Menginformasikan Owner dari perangkat mana login terjadi,
/// dan memberikan opsi Remote Wipe ("Nuclear Button") jika diperlukan.
/// ─────────────────────────────────────────────────────────────────────────
class SessionDisplacedScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool isWipeRequested;

  const SessionDisplacedScreen({
    super.key,
    required this.userId,
    this.isWipeRequested = false,
  });

  @override
  ConsumerState<SessionDisplacedScreen> createState() =>
      _SessionDisplacedScreenState();
}

class _SessionDisplacedScreenState
    extends ConsumerState<SessionDisplacedScreen>
    with TickerProviderStateMixin {
  DeviceInfo? _newDeviceInfo;
  bool _isLoading = true;
  bool _isWiping = false;
  bool _wipeComplete = false;
  int _countdownSeconds = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initialize();
  }

  Future<void> _initialize() async {
    final service = ref.read(deviceSessionServiceProvider);
    final info = await service.getActiveDeviceInfo(widget.userId);

    if (widget.isWipeRequested) {
      // Grace period — beri waktu sync sebelum wipe
      setState(() {
        _newDeviceInfo = info;
        _isLoading = false;
        _isWiping = true;
        _countdownSeconds = 3;
      });
      await _runWipeSequence(service);
    } else {
      setState(() {
        _newDeviceInfo = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _runWipeSequence(DeviceSessionService service) async {
    // Countdown 3 detik (grace period untuk sync terakhir)
    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdownSeconds = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;

    // Eksekusi wipe
    await service.gracePeriodDelay();
    await service.executeLocalWipe();
    await service.clearWipeFlag(widget.userId);

    if (!mounted) return;
    setState(() {
      _isWiping = false;
      _wipeComplete = true;
    });

    // Tunggu sebentar lalu force logout
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) _forceLogout();
  }

  void _forceLogout() {
    // Navigator ke login screen
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Stack(
        children: [
          // Background gradient aura
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.3),
                  radius: 1.2,
                  colors: [
                    AppColors.error.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _isLoading
                    ? CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : _wipeComplete
                        ? _buildWipeCompleteState()
                        : _isWiping
                            ? _buildWipingState()
                            : _buildDisplacedState(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── State 1: Sesi Dicabut (bukan wipe) ─────────────────────
  Widget _buildDisplacedState() {
    final loginAt = _newDeviceInfo?.loginAt;
    final timeStr = loginAt != null
        ? '${loginAt.hour.toString().padLeft(2, '0')}:${loginAt.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon animasi
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    SolarIconsOutline.shieldWarning,
                    color: AppColors.error,
                    size: 48,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              Text(
                'Sesi Dialihkan',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Akun ServisLog+ Anda telah masuk dari perangkat lain.\nSesi di perangkat ini telah diakhiri demi keamanan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 24),

              // Info perangkat baru
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurfaceLighter.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      SolarIconsOutline.smartphone,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _newDeviceInfo?.model ?? 'Perangkat Baru',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Login pukul $timeStr · ${_newDeviceInfo?.osVersion ?? ''}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Bukan Anda? Amankan akun Anda sekarang.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.warning.withValues(alpha: 0.8),
                ),
              ),

              const SizedBox(height: 32),

              // Tombol utama
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _forceLogout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Saya Mengerti',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  // ── State 2: Remote Wipe sedang berjalan ────────────────────
  Widget _buildWipingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            '$_countdownSeconds',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: AppColors.error,
            ),
          ),
        ),

        const SizedBox(height: 32),

        Text(
          'Menghapus Data Lokal...',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Memberi waktu sinkronisasi terakhir\nsebelum data dihapus.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ── State 3: Wipe selesai ───────────────────────────────────
  Widget _buildWipeCompleteState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          SolarIconsBold.checkCircle,
          color: AppColors.success,
          size: 80,
        ),
        const SizedBox(height: 24),
        Text(
          'Data Lokal Dihapus',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Semua data lokal di perangkat ini\ntelah berhasil dihapus.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.5),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
// DIALOG: Ditampilkan di perangkat BARU saat mendeteksi ada
// sesi aktif di perangkat lain (sebelum login selesai penuh)
// ──────────────────────────────────────────────────────────────

class ActiveSessionConflictDialog extends ConsumerWidget {
  final String userId;
  final DeviceInfo? existingDeviceInfo;
  final VoidCallback onContinue;
  final VoidCallback onWipe;

  const ActiveSessionConflictDialog({
    super.key,
    required this.userId,
    required this.existingDeviceInfo,
    required this.onContinue,
    required this.onWipe,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: (isDark ? Colors.white : Theme.of(context).colorScheme.primary)
                    .withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    SolarIconsOutline.smartphone,
                    color: AppColors.warning,
                    size: 40,
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Sesi Aktif Terdeteksi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Akun Anda masih aktif di perangkat lain.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: (isDark ? Colors.white : Colors.black87)
                        .withValues(alpha: 0.55),
                    height: 1.5,
                  ),
                ),

                if (existingDeviceInfo != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceLighter.withValues(alpha: 0.5)
                          : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.07),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          SolarIconsOutline.smartphone,
                          color: Theme.of(context).colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                existingDeviceInfo!.model,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                existingDeviceInfo!.osVersion,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: (isDark ? Colors.white : Colors.black87)
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // Tombol: Lanjutkan saja (kick perangkat lama)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Masuk & Keluarkan Sesi Lama',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Nuclear Button: Kick + Wipe
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onWipe,
                  icon: const Icon(
                    SolarIconsOutline.trashBinTrash,
                    size: 16,
                    color: AppColors.error,
                  ),
                  label: Text(
                    'Keluarkan & Hapus Data Lokal',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.error,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '⚠️ Data lokal di perangkat lama akan dihapus permanen setelah 3 detik sinkronisasi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: (isDark ? Colors.white : Colors.black87)
                      .withValues(alpha: 0.3),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
);
  }
}

