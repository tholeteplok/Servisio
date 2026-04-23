import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:solar_icons/solar_icons.dart';

import '../../../core/services/expense_ai_service.dart';
import 'create_expense_screen.dart';

class ScanExpenseScreen extends StatefulWidget {
  const ScanExpenseScreen({super.key});

  @override
  State<ScanExpenseScreen> createState() => _ScanExpenseScreenState();
}

class _ScanExpenseScreenState extends State<ScanExpenseScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isScanning = false;
  String? _errorMessage;

  final _aiService = ExpenseAIService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() => _errorMessage = 'Tidak ada kamera yang tersedia');
        return;
      }

      final controller = CameraController(
        _cameras!.first,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Gagal membuka kamera: ${e.toString()}');
    }
  }

  Future<void> _captureAndScan() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isScanning) {
      return;
    }

    // Haptic feedback saat scan ditekan
    HapticFeedback.mediumImpact();
    setState(() => _isScanning = true);

    try {
      final xFile = await controller.takePicture();
      final imageFile = File(xFile.path);

      final result = await _aiService.scanReceipt(imageFile);

      if (!mounted) return;

      if (!result.success && (result.amount == 0 || result.fullText.isEmpty)) {
        // OCR gagal - tawarkan input manual
        _showFailureDialog();
        return;
      }

      // Navigasi ke form dengan data pre-filled
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => CreateExpenseScreen(
            prefilledAmount: result.amount > 0 ? result.amount : null,
            prefilledCategory:
                result.category.isNotEmpty ? result.category : null,
            prefilledDate: result.date,
            aiConfidence: result.confidence,
            extractedText: result.fullText,
          ),
        ),
      );

      if (saved == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal scan: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _showFailureDialog() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Teks Tidak Terdeteksi',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Pastikan nota terlihat jelas dan cukup terang. '
          'Atau gunakan input manual.',
          style: GoogleFonts.plusJakartaSans(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Coba Lagi'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx, true);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const CreateExpenseScreen(),
                ),
              );
            },
            child: const Text('Input Manual'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _aiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(
          'Scan Nota',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const CreateExpenseScreen(),
              ),
            ),
            child: Text(
              'Manual',
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: _errorMessage != null
          ? _buildError()
          : !_isInitialized
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera preview
                    CameraPreview(_controller!),

                    // Overlay guide
                    _buildOverlay(theme),

                    // Bottom controls
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: _buildControls(theme),
                    ),
                  ],
                ),
    );
  }

  Widget _buildOverlay(ThemeData theme) {
    return CustomPaint(
      painter: _ScanOverlayPainter(),
      child: Padding(
        padding: const EdgeInsets.only(top: 140),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Arahkan ke nota / struk pembayaran',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 48),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _isScanning ? null : _captureAndScan,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isScanning
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.white,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 4,
                ),
              ),
              child: _isScanning
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(
                      SolarIconsBold.camera,
                      color: Colors.black,
                      size: 32,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(SolarIconsOutline.camera, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Kamera tidak dapat dibuka',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CreateExpenseScreen(),
                ),
              ),
              child: const Text('Input Manual'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter untuk scan frame overlay.
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.black.withValues(alpha: 0.4);
    final clearPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear;
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Scan rect (centred, 80% wide, 40% tall)
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: size.width * 0.8,
      height: size.height * 0.38,
    );

    // Dim overlay
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, fillPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      clearPaint,
    );
    canvas.restore();

    // Corner accents
    final r = rect;
    const cl = 24.0; // corner length
    final paths = [
      // Top-left
      Path()
        ..moveTo(r.left, r.top + cl)
        ..lineTo(r.left, r.top)
        ..lineTo(r.left + cl, r.top),
      // Top-right
      Path()
        ..moveTo(r.right - cl, r.top)
        ..lineTo(r.right, r.top)
        ..lineTo(r.right, r.top + cl),
      // Bottom-left
      Path()
        ..moveTo(r.left, r.bottom - cl)
        ..lineTo(r.left, r.bottom)
        ..lineTo(r.left + cl, r.bottom),
      // Bottom-right
      Path()
        ..moveTo(r.right - cl, r.bottom)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.right, r.bottom - cl),
    ];

    for (final path in paths) {
      canvas.drawPath(path, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
