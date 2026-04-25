import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart' as launch_url;
import 'package:url_launcher/url_launcher.dart'; // Keep for LaunchMode etc if needed
import '../../domain/entities/transaction.dart';
import '../../domain/entities/sale.dart';
import 'package:intl/intl.dart';
import '../constants/app_strings.dart';
import '../utils/app_logger.dart';

/// Interface for platform-dependent actions in DocumentService
abstract class DocumentPlatformActions {
  Future<bool> launchUrl(Uri url, {LaunchMode mode = LaunchMode.platformDefault});
  Future<bool> canLaunchUrl(Uri url);
  Future<void> layoutPdf({required Future<Uint8List> Function(PdfPageFormat) onLayout});
  Future<void> shareXFiles(List<XFile> files, {String? subject});
}

/// Default implementation using real plugins
class DefaultDocumentPlatformActions implements DocumentPlatformActions {
  @override
  Future<bool> launchUrl(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) =>
      launch_url.launchUrl(url, mode: mode);

  @override
  Future<bool> canLaunchUrl(Uri url) => launch_url.canLaunchUrl(url);

  @override
  Future<void> layoutPdf({required Future<Uint8List> Function(PdfPageFormat) onLayout}) =>
      Printing.layoutPdf(onLayout: onLayout);

  @override
  Future<void> shareXFiles(List<XFile> files, {String? subject}) =>
      Share.shareXFiles(files, subject: subject);
}

class DocumentService {
  final DocumentPlatformActions _actions;

  DocumentService({DocumentPlatformActions? actions})
      : _actions = actions ?? DefaultDocumentPlatformActions();

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: AppStrings.date.localeID,
    symbol: '${AppStrings.common.currencySymbol} ',
    decimalDigits: 0,
  );

  /// Share WhatsApp Receipt (Text based)
  Future<void> shareWhatsApp({
    required String phone,
    Transaction? transaction,
    List<Sale>? sales,
    required String bengkelName,
    String? address,
    String? workshopWhatsapp,
  }) async {
    final String message = _buildWhatsAppMessage(
      transaction: transaction,
      sales: sales,
      bengkelName: bengkelName,
      address: address,
      workshopWhatsapp: workshopWhatsapp,
    );

    final cleanedPhone = _cleanPhoneNumber(phone);

    if (kIsWeb) {
      final webUrl = "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}";
      await _actions.launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    } else {
      final appUrl = "whatsapp://send?phone=$cleanedPhone&text=${Uri.encodeComponent(message)}";
      if (await _actions.canLaunchUrl(Uri.parse(appUrl))) {
        await _actions.launchUrl(Uri.parse(appUrl));
      } else {
        final webUrl = "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}";
        await _actions.launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Send WhatsApp Service Reminder
  Future<void> sendReminderWhatsApp({
    required String phone,
    required Transaction transaction,
    required String bengkelName,
  }) async {
    final nextDate = transaction.nextServiceDate;
    final dateStr = nextDate != null
        ? DateFormat(AppStrings.date.displayDate).format(nextDate)
        : '-';
    final targetKm = transaction.targetServiceKm;
    final kmStr = targetKm != null ? "${AppStrings.transaction.kmOrReminder}$targetKm" : "";

    final String message = AppStrings.whatsapp.serviceReminder(
      customerName: transaction.customerName,
      vehiclePlate: transaction.vehiclePlate,
      vehicleModel: transaction.vehicleModel,
      bengkelName: bengkelName,
      dateStr: dateStr,
      kmStr: kmStr,
    );

    final cleanedPhone = _cleanPhoneNumber(phone);

    if (kIsWeb) {
      final webUrl = "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}";
      await _actions.launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    } else {
      final appUrl = "whatsapp://send?phone=$cleanedPhone&text=${Uri.encodeComponent(message)}";
      if (await _actions.canLaunchUrl(Uri.parse(appUrl))) {
        await _actions.launchUrl(Uri.parse(appUrl));
      } else {
        final webUrl = "https://wa.me/$cleanedPhone?text=${Uri.encodeComponent(message)}";
        await _actions.launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
      }
    }
  }

  String _cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    }
    return cleaned;
  }

  String _buildWhatsAppMessage({
    Transaction? transaction,
    List<Sale>? sales,
    required String bengkelName,
    String? address,
    String? workshopWhatsapp,
  }) {
    final sb = StringBuffer();
    sb.writeln("*${AppStrings.transaction.whatsappReceiptHeader} - $bengkelName*");
    if (address != null && address.isNotEmpty) sb.writeln(address);
    if (workshopWhatsapp != null && workshopWhatsapp.isNotEmpty) sb.writeln("WA: $workshopWhatsapp");
    sb.writeln("-----------------------------------------");

    if (transaction != null) {
      sb.writeln("${AppStrings.transaction.trxNumberLabel}: ${transaction.trxNumber}");
      sb.writeln(
        "${AppStrings.transaction.vehicleLabel}: ${transaction.vehicleModel} (${transaction.vehiclePlate})",
      );
      sb.writeln("${AppStrings.common.customerNameLabel}: ${transaction.customerName}");
      sb.writeln("");
      sb.writeln("*${AppStrings.transaction.detailLabel}:*");
      for (var item in transaction.items) {
          sb.writeln(
          "- ${item.name} x${item.quantity}: ${_currencyFormat.format(item.price * item.quantity)}",
        );
      }
      sb.writeln("-----------------------------------------");
      sb.writeln("*${AppStrings.transaction.totalLabel}: ${_currencyFormat.format(transaction.totalAmount)}*");
    } else if (sales != null && sales.isNotEmpty) {
      sb.writeln("${AppStrings.transaction.trxNumberLabel}: ${sales.first.trxNumber}");
      sb.writeln("${AppStrings.common.typeLabel}: ${AppStrings.catalog.salesLabel}");
      sb.writeln("${AppStrings.transaction.labelCustomer}: ${sales.first.customerName ?? AppStrings.common.noCategory}");
      sb.writeln("");
      sb.writeln("*${AppStrings.transaction.detailLabel}:*");
      for (var s in sales) {
        sb.writeln(
          "- ${s.itemName} x${s.quantity}: ${_currencyFormat.format(s.totalPrice)}",
        );
      }
      sb.writeln("-----------------------------------------");
      final total = sales.fold(0, (sum, item) => sum + item.totalPrice);
      sb.writeln("*${AppStrings.transaction.totalLabel}: ${_currencyFormat.format(total)}*");
    }
    if (transaction != null) {
      final notes = transaction.mechanicNotes ?? AppStrings.transaction.serviceDoneLabel;
      sb.writeln("");
      sb.writeln("*${AppStrings.transaction.techNotesLabelReceipt}:*");
      sb.writeln(notes);

      final recKm = transaction.recommendationKm;
      final recTime = transaction.recommendationTimeMonth;
      if (recKm != null || recTime != null) {
        sb.writeln("");
        sb.writeln("*${AppStrings.transaction.recServiceLabel}:*");
        if (recKm != null) sb.writeln("- ${AppStrings.transaction.recKmLabel}$recKm KM");
        if (recTime != null) sb.writeln("- ${AppStrings.transaction.recTimeLabel}$recTime ${AppStrings.transaction.month}");
      } else {
        sb.writeln("");
        sb.writeln("*${AppStrings.transaction.recServiceLabel}:*");
        sb.writeln(AppStrings.transaction.recDefaultLabel);
      }
    }

    sb.writeln("");
    sb.writeln(AppStrings.whatsapp.thankYou);
    return sb.toString();
  }

  /// Generate and Print/Share PDF Receipt
  Future<void> generateAndPrint({
    Transaction? transaction,
    List<Sale>? sales,
    required String bengkelName,
    String? address,
    String? workshopWhatsapp,
    String? logoPath,
    bool isThermal = true,
    bool isShare = false,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat(AppStrings.date.dateTimeReceipt).format(DateTime.now());

    pw.MemoryImage? logoImage;
    if (logoPath != null) {
      try {
        final file = File(logoPath);
        if (await file.exists()) {
          logoImage = pw.MemoryImage(await file.readAsBytes());
        }
      } catch (e) {
        appLogger.warning('Error loading logo for PDF', context: 'DocumentService', error: e);
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: isThermal
            ? const PdfPageFormat(58 * PdfPageFormat.mm, double.infinity)
            : PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoImage != null)
                pw.Center(
                  child: pw.Container(
                    height: isThermal ? 40 : 60,
                    margin: const pw.EdgeInsets.only(bottom: 5),
                    child: pw.Image(logoImage),
                  ),
                ),
              pw.Center(
                child: pw.Text(
                  bengkelName,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: isThermal ? 12 : 20,
                  ),
                ),
              ),
              if (address != null && address.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    address,
                    style: const pw.TextStyle(fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              if (workshopWhatsapp != null && workshopWhatsapp.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    "WhatsApp: $workshopWhatsapp",
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              pw.Divider(),
              pw.Text(
                "${AppStrings.common.dateLabel}: $dateStr",
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (transaction != null) ...[
                pw.Text(
                  "${AppStrings.transaction.trxNumberLabel}: ${transaction.trxNumber}",
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  "${AppStrings.transaction.unitLabel}: ${transaction.vehicleModel} (${transaction.vehiclePlate})",
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Divider(),
                ...transaction.items.map(
                  (item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "${item.name} x${item.quantity}",
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        _currencyFormat.format(item.price * item.quantity),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      AppStrings.transaction.totalLabel,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      _currencyFormat.format(transaction.totalAmount),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  "${AppStrings.transaction.techNotesLabelReceipt.toUpperCase()}:",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                ),
                pw.Text(
                  transaction.mechanicNotes ?? AppStrings.transaction.serviceDoneLabel,
                  style: const pw.TextStyle(fontSize: 8),
                ),

                pw.SizedBox(height: 8),
                pw.Text(
                  "${AppStrings.transaction.recServiceLabel.toUpperCase()}:",
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                    ),
                ),
                if (transaction.recommendationKm == null &&
                    transaction.recommendationTimeMonth == null)
                  pw.Text(
                    AppStrings.transaction.recDefaultLabel,
                    style: const pw.TextStyle(fontSize: 8),
                  )
                else ...[
                  if (transaction.recommendationKm != null)
                    pw.Text(
                      "- ${AppStrings.transaction.recKmLabel}${transaction.recommendationKm} KM",
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  if (transaction.recommendationTimeMonth != null)
                    pw.Text(
                      "- ${AppStrings.transaction.recTimeLabel}${transaction.recommendationTimeMonth} ${AppStrings.transaction.month}",
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                ],
              ] else if (sales != null && sales.isNotEmpty) ...[
                pw.Text(
                  "${AppStrings.transaction.trxNumberLabel}: ${sales.first.trxNumber}",
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Text(
                  AppStrings.catalog.salesLabel,
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.Divider(),
                ...sales.map(
                  (s) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        "${s.itemName} x${s.quantity}",
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                      pw.Text(
                        _currencyFormat.format(s.totalPrice),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      AppStrings.transaction.totalLabel,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    pw.Text(
                      _currencyFormat.format(
                        sales.fold(0, (sum, item) => sum + item.totalPrice),
                      ),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
              pw.SizedBox(height: 20),
              pw.Center(
                child: pw.Text(
                  AppStrings.common.thankYouShort,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (isShare) {
      final bytes = await pdf.save();
      await _actions.shareXFiles([
        XFile.fromData(
          bytes,
          name: 'Nota-$dateStr.pdf',
          mimeType: 'application/pdf',
        ),
      ]);
    } else {
      await _actions.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    }
  }
}

// 🔄 Riverpod Provider
final documentServiceProvider = Provider<DocumentService>((ref) => DocumentService());

