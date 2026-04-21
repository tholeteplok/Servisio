import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:share_plus/share_plus.dart';
import 'glass_card.dart';

class QRViewView extends StatefulWidget {
  final String imagePath;
  final String? workshopName;

  const QRViewView({super.key, required this.imagePath, this.workshopName});

  @override
  State<QRViewView> createState() => _QRViewViewState();
}

class _QRViewViewState extends State<QRViewView> {
  double? _originalBrightness;

  @override
  void initState() {
    super.initState();
    _initBrightness();
    _triggerHaptic();
  }

  Future<void> _initBrightness() async {
    try {
      _originalBrightness = await ScreenBrightness.instance.application;
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
    } catch (e) {
      debugPrint('Failed to boost brightness: $e');
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      if (_originalBrightness != null) {
        await ScreenBrightness.instance.setApplicationScreenBrightness(
          _originalBrightness!,
        );
      } else {
        await ScreenBrightness.instance.resetApplicationScreenBrightness();
      }
    } catch (e) {
      debugPrint('Failed to restore brightness: $e');
    }
  }

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _shareQR() async {
    try {
      await Share.shareXFiles([
        XFile(widget.imagePath),
      ], text: 'QRIS ${widget.workshopName ?? "Bengkel"}');
    } catch (e) {
      debugPrint('Failed to share QR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Glass Backdrop ──
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.transparent,
            ),
          ),

          // ── Main Content ──
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GlassCard(
                borderRadius: 32,
                blur: 20,
                opacity: 0.1,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'QRIS STATIS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    if (widget.workshopName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.workshopName!,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // ── HIGH CONTRAST QR CONTAINER ──
                    Hero(
                      tag: 'qris_hero',
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white, // Critical for scanning
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(widget.imagePath),
                            fit: BoxFit.contain,
                            width: MediaQuery.of(context).size.width * 0.7,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _shareQR,
                            icon: const Icon(SolarIconsOutline.share),
                            label: const Text('BAGIKAN'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(SolarIconsOutline.closeCircle),
                            label: const Text('TUTUP'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40), // Spacer from bottom
            ],
          ),
        ],
      ),
    );
  }
}
