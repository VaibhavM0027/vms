import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/visitor_model.dart';

class PdfService {
  static Future<Uint8List> generateVisitorIdCard(Visitor visitor) async {
    final pdf = pw.Document();

    // Load visitor photo if available
    pw.MemoryImage? photoImage;
    String? imageUrl = visitor.photoUrl ?? visitor.idImageUrl;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final imageBytes = await _getImageFromUrl(imageUrl);
        photoImage = pw.MemoryImage(imageBytes);
      } catch (e) {
        print('Error loading visitor photo: $e');
        photoImage = null;
      }
    }

    // ID Card format: 85.6mm x 54mm (credit card size)
    final idCardFormat = const PdfPageFormat(85.6 * PdfPageFormat.mm, 54 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: idCardFormat,
        margin: const pw.EdgeInsets.all(4),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue, width: 1.5),
              borderRadius: pw.BorderRadius.circular(5),
            ),
            padding: const pw.EdgeInsets.all(4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  color: PdfColors.blue,
                  child: pw.Center(
                    child: pw.Text(
                      'VISITOR ID CARD',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),

                // Photo and details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    if (photoImage != null)
                      pw.Container(
                        height: 35,
                        width: 35,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey, width: 0.5),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 2,
                          verticalRadius: 2,
                          child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                        ),
                      )
                    else
                      pw.Container(
                        height: 35,
                        width: 35,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey, width: 0.5),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'No Photo',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 5, color: PdfColors.grey),
                          ),
                        ),
                      ),
                    pw.SizedBox(width: 5),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildIdDetailRow('Name', visitor.name, fontSize: 6.5),
                          _buildIdDetailRow('Phone', visitor.contact, fontSize: 6.5),
                          _buildIdDetailRow('Host', visitor.hostName ?? 'N/A', fontSize: 6.5),
                          _buildIdDetailRow('Purpose', visitor.purpose ?? 'N/A', fontSize: 6.5),
                        ],
                      ),
                    ),
                  ],
                ),

                // QR and validity
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.all(2),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.5),
                      ),
                      height: 30,
                      width: 30,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: visitor.qrCode ?? visitor.id ?? 'No QR',
                        drawText: false,
                      ),
                    ),
                    pw.SizedBox(width: 4),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'Valid: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                            style: pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700),
                          ),
                          pw.Text(
                            'Signature:',
                            style: pw.TextStyle(fontSize: 5, color: PdfColors.grey600),
                          ),
                          pw.Container(
                            height: 5,
                            width: 40,
                            decoration: pw.BoxDecoration(
                              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildIdDetailRow(String label, String value, {double fontSize = 8}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: fontSize)),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> _getImageFromUrl(String url) async {
    try {
      print('Loading image from URL: $url');

      if (url.contains('firebasestorage.googleapis.com')) {
        final storageRef = FirebaseStorage.instance.refFromURL(url);
        final downloadUrl = await storageRef.getDownloadURL();
        final response = await http.get(Uri.parse(downloadUrl), headers: {'Accept': 'image/*'});
        if (response.statusCode == 200) return response.bodyBytes;
        throw Exception('Failed to load image: ${response.statusCode}');
      } else {
        final response = await http.get(Uri.parse(url), headers: {'Accept': 'image/*'});
        if (response.statusCode == 200) return response.bodyBytes;
        throw Exception('Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading image: $e');
      rethrow;
    }
  }

  static Future<String> downloadVisitorIdCard(Visitor visitor) async {
    final pdfData = await generateVisitorIdCard(visitor);
    final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
    final fileName = 'visitor_id_card_${visitor.id ?? 'unknown'}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfData);
    print('PDF saved to: ${file.path}');
    return file.path;
  }

  static Future<void> downloadAndOpenVisitorIdCard(Visitor visitor) async {
    final filePath = await downloadVisitorIdCard(visitor);
    final result = await OpenFile.open(filePath);
    print('Open file result: ${result.message}');
  }
}
