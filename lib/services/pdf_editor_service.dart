import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

enum PdfEditType { cover, text }

class PdfEdit {
  final PdfEditType type;
  final int pageIndex;
  final Rect normalizedBounds;
  final String? text;
  final Color? color;
  final double fontSize;

  PdfEdit({
    required this.type,
    required this.pageIndex,
    required this.normalizedBounds,
    this.text,
    this.color,
    this.fontSize = 16.0,
  });
}

class PdfEditorService {
  static final PdfEditorService instance = PdfEditorService._();
  PdfEditorService._();

  static const int previewDpi = 150;
  static const int outputDpi = 200;

  Future<List<Uint8List>> renderPagesForPreview(File file) async {
    return _renderPages(file, previewDpi);
  }

  Future<List<Uint8List>> _renderPages(File file, int dpi) async {
    final bytes = await file.readAsBytes();
    final images = <Uint8List>[];
    await for (final page in Printing.raster(bytes, dpi: dpi.toDouble())) {
      images.add(await page.toPng());
    }
    return images;
  }

  Size getImageSize(Uint8List pngBytes) {
    try {
      final decoded = img.decodeImage(pngBytes);
      if (decoded != null) {
        return Size(decoded.width.toDouble(), decoded.height.toDouble());
      }
    } catch (_) {}
    return const Size(595, 842);
  }

  Future<File> applyEdits(
    String sourcePath,
    List<PdfEdit> edits, {
    String baseName = 'edited',
  }) async {
    final pageImages = await _renderPages(File(sourcePath), outputDpi);

    final doc = pw.Document();

    pw.Font? cairoFont;
    try {
      cairoFont = await PdfGoogleFonts.cairoRegular();
    } catch (_) {}
    final helveticaFont = pw.Font.helvetica();

    for (int i = 0; i < pageImages.length; i++) {
      final pngBytes = pageImages[i];
      final decoded = img.decodeImage(pngBytes);
      final widthPt =
          decoded != null ? decoded.width * 72.0 / outputDpi : 595.0;
      final heightPt =
          decoded != null ? decoded.height * 72.0 / outputDpi : 842.0;
      final pageFormat = PdfPageFormat(widthPt, heightPt);

      final pageEdits = edits.where((e) => e.pageIndex == i).toList();
      final memoryImage = pw.MemoryImage(pngBytes);

      doc.addPage(pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (ctx) => pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.Image(memoryImage, fit: pw.BoxFit.fill),
            ),
            ...pageEdits.map((edit) {
              final left = edit.normalizedBounds.left * pageFormat.width;
              final top = edit.normalizedBounds.top * pageFormat.height;
              final width = edit.normalizedBounds.width * pageFormat.width;
              final height = edit.normalizedBounds.height * pageFormat.height;

              if (edit.type == PdfEditType.cover) {
                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Container(
                    width: width,
                    height: height,
                    color: PdfColor.fromInt(edit.color?.value ?? 0xFFFFFFFF),
                  ),
                );
              } else {
                final text = edit.text ?? '';
                final hasArabic =
                    text.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
                final font =
                    hasArabic ? (cairoFont ?? helveticaFont) : helveticaFont;

                return pw.Positioned(
                  left: left,
                  top: top,
                  child: pw.Text(
                    text,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: edit.fontSize,
                      color:
                          PdfColor.fromInt(edit.color?.value ?? 0xFF000000),
                    ),
                  ),
                );
              }
            }),
          ],
        ),
      ));
    }

    final bytes = await doc.save();
    final appDir = await getApplicationDocumentsDirectory();
    final pdfsDir = Directory('${appDir.path}/pdfs');
    if (!await pdfsDir.exists()) await pdfsDir.create(recursive: true);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final safeName =
        baseName.replaceAll(RegExp(r'[^a-zA-Z0-9_\u0600-\u06FF]'), '_');
    final outPath = p.join(pdfsDir.path, '${ts}_$safeName.pdf');
    await File(outPath).writeAsBytes(bytes);
    return File(outPath);
  }
}