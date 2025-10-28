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

    // Vertical ID Card format (credit card size, portrait)
    final idCardFormat = const PdfPageFormat(54 * PdfPageFormat.mm, 85.6 * PdfPageFormat.mm);

    pdf.addPage(
      pw.Page(
        pageFormat: idCardFormat,
        margin: const pw.EdgeInsets.all(6),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue, width: 1.2),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                // Header Bar
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(5),
                      topRight: pw.Radius.circular(5),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'VISITOR ID CARD',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),

                pw.SizedBox(height: 6),

                // Visitor Photo
                if (photoImage != null)
                  pw.Container(
                    height: 40,
                    width: 40,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.ClipRRect(
                      horizontalRadius: 4,
                      verticalRadius: 4,
                      child: pw.Image(photoImage, fit: pw.BoxFit.cover),
                    ),
                  )
                else
                  pw.Container(
                    height: 40,
                    width: 40,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey600, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'No Photo',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                      ),
                    ),
                  ),

                pw.SizedBox(height: 6),

                // Visitor Details (center aligned)
                _buildDetailLine('Name', visitor.name),
                _buildDetailLine('Phone', visitor.contact),
                _buildDetailLine('Host', visitor.hostName ?? 'N/A'),
                _buildDetailLine('Purpose', visitor.purpose ?? 'N/A'),

                pw.SizedBox(height: 8),

                // Divider Line
                pw.Container(
                  height: 0.6,
                  width: 40,
                  color: PdfColors.grey400,
                ),

                pw.SizedBox(height: 8),

                // QR Code Section
                pw.Text(
                  'QR CODE',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Container(
                  height: 35,
                  width: 35,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.5),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: visitor.qrCode ?? visitor.id ?? 'No QR',
                    drawText: false,
                  ),
                ),

                pw.SizedBox(height: 6),

                // Validity & Signature
                pw.Text(
                  'Valid: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                  style: pw.TextStyle(fontSize: 6, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Signature:',
                  style: pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
                ),
                pw.Container(
                  height: 6,
                  width: 40,
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildDetailLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5, horizontal: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.start,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Text(value, style: pw.TextStyle(fontSize: 7)),
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
