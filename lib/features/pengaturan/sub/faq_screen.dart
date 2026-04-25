import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/widgets/atelier_header.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          const SliverAtelierHeaderSub(
            title: 'Bantuan & FAQ',
            subtitle: 'Solusi cepat untuk pertanyaan Anda seputar ServisLog+.',
            showBackButton: true,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel(context, 'KEAMANAN & DATA'),
                  const SizedBox(height: 12),
                  _buildFAQItem(
                    context,
                    'Apakah data bisa dipulihkan jika HP ganti/install ulang?',
                    'YA, data Anda tetap aman dan dapat dipulihkan sepenuhnya baik di perangkat yang sama maupun perangkat baru, selama Akun Google dan PIN yang digunakan tetap sama.',
                  ),
                  _buildFAQItem(
                    context,
                    'Bagaimana alur keamanan ServisLog?',
                    '1. Data Lokal: Disimpan di HP untuk kecepatan.\n2. Cloud Encryption: Data disinkronkan ke Google Cloud dalam kondisi terenkripsi (acak). Tidak ada yang bisa membacanya tanpa kunci Anda.\n3. PIN Power: Saat install ulang, aplikasi menarik "Kunci Terbungkus" dari Cloud. PIN Anda digunakan untuk membuka kunci tersebut di memori (RAM) untuk mendekripsi data.',
                  ),
                  _buildFAQItem(
                    context,
                    'Apa risiko jika saya lupa PIN?',
                    'Ini adalah risiko terbesar. Karena sistem arsitektur Zero-Knowledge, jika Anda lupa PIN, kunci pembuka data hilang selamanya. Kami tidak menyimpan kunci cadangan demi privasi Anda.',
                  ),
                  const SizedBox(height: 24),
                  _buildSectionLabel(context, 'SINKRONISASI'),
                  const SizedBox(height: 12),
                  _buildFAQItem(
                    context,
                    'Bisakah saya menggunakan tanpa internet?',
                    'Tentu. Anda bisa tetap mencatat transaksi saat offline. Data akan sinkron secara otomatis saat internet tersedia kembali.',
                  ),
                  _buildFAQItem(
                    context,
                    'Cara menyambungkan HP staf?',
                    'Gunakan menu "Gabung Bengkel" di HP staf, lalu masukkan Bengkel ID dan Master Password yang sama dengan Pemilik.',
                  ),
                  const SizedBox(height: 24),
                  _buildSectionLabel(context, 'FITUR & OPERASIONAL'),
                  const SizedBox(height: 12),
                  _buildFAQItem(
                    context,
                    'Printer apa yang didukung?',
                    'Mendukung semua Bluetooth Thermal Printer standar (58mm/80mm) yang kompatibel dengan protokol ESC/POS.',
                  ),
                  _buildFAQItem(
                    context,
                    'Cara kirim struk via WhatsApp?',
                    'Klik ikon WhatsApp pada halaman Detail Transaksi. Aplikasi akan menyiapkan teks invoice untuk dikirim ke nomor pelanggan.',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: theme.colorScheme.primary.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, String question, String answer) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20))),
          title: Text(
            question,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          expandedAlignment: Alignment.topLeft,
          children: [
            Text(
              answer,
              style: GoogleFonts.inter(
                fontSize: 13,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

