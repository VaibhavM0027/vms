import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/visitor_model.dart';

class PdfService {
  static Future<Uint8List> generateVisitorIdCard(Visitor visitor) async {
    final pdf = pw.Document();

    // Load visitor photo if available
    pw.MemoryImage? photoImage;
    if (visitor.photoUrl != null && visitor.photoUrl!.isNotEmpty) {
      try {
        final imageBytes = await _getImageFromUrl(visitor.photoUrl!);
        photoImage = pw.MemoryImage(imageBytes);
      } catch (e) {
        // Handle image loading error
        photoImage = null;
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.standard,
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue, width: 2),
            ),
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header with company name
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.blue,
                  child: pw.Center(
                    child: pw.Text(
                      'VISITOR ID CARD',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                
                // Visitor photo
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (photoImage != null)
                      pw.Container(
                        height: 80,
                        width: 80,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey),
                        ),
                        child: pw.Image(photoImage),
                      )
                    else
                      pw.Container(
                        height: 80,
                        width: 80,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'Photo\nNot\nAvailable',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey,
                            ),
                          ),
                        ),
                      ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildIdDetailRow('Name', visitor.name),
                          _buildIdDetailRow('Phone', visitor.contact),
                          _buildIdDetailRow('Email', visitor.email ?? 'N/A'),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                
                // Additional details
                _buildIdDetailRow('Host', visitor.hostName ?? 'N/A'),
                _buildIdDetailRow('Purpose', visitor.purpose ?? 'N/A'),
                pw.SizedBox(height: 5),
                
                // Valid period
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Text(
                    'Valid: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.SizedBox(height: 5),
                
                // QR Code
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'SCAN QR CODE',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Container(
                        height: 70,
                        width: 70,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.black),
                        ),
                        child: pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: visitor.qrCode ?? visitor.id ?? 'No QR',
                          drawText: false,
                        ),
                      ),
                    ],
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

  static pw.Widget _buildIdDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 40,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> _getImageFromUrl(String url) async {
    try {
      // For Firebase Storage URLs, we might need to handle authentication
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'image/*',
          'User-Agent': 'Mozilla/5.0 (compatible; VMS/1.0)',
        },
      );
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        // Handle unauthorized access - might need to refresh token or use different approach
        print('Unauthorized access to image. Status code: ${response.statusCode}');
        throw Exception('Unauthorized access to image. Please check permissions.');
      } else {
        print('Failed to load image with status code: ${response.statusCode}');
        throw Exception('Failed to load image with status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading image from URL: $e');
      // Try alternative approach for Firebase Storage URLs
      if (url.contains('firebasestorage.googleapis.com')) {
        print('Attempting to load Firebase Storage image with alternative method');
        // Could implement Firebase Storage SDK approach here if needed
      }
      rethrow;
    }
  }

  static Future<String> downloadVisitorIdCard(Visitor visitor) async {
    try {
      final pdfData = await generateVisitorIdCard(visitor);
      
      // Get the downloads directory
      final dir = await getDownloadsDirectory() ?? await getTemporaryDirectory();
      final fileName = 'visitor_id_card_${visitor.id ?? 'unknown'}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfData);
      
      print('PDF saved to: ${file.path}');
      return file.path; // Return the file path so UI can inform user
    } catch (e) {
      print('Error generating PDF: $e');
      rethrow;
    }
  }
  
  static Future<void> downloadAndOpenVisitorIdCard(Visitor visitor) async {
    try {
      final filePath = await downloadVisitorIdCard(visitor);
      // Automatically open the file
      final result = await OpenFile.open(filePath);
      print('Open file result: ${result.message}');
    } catch (e) {
      print('Error opening PDF: $e');
      rethrow;
    }
  }
}