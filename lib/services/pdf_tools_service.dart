import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

class PdfToolsService {
  static final PdfToolsService instance = PdfToolsService._();
  PdfToolsService._();

  final DatabaseService _db = DatabaseService.instance;

  static const int _rasterDpi = 200;

  Future<Directory> _pdfsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/pdfs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _uniquePath(String suffix, {String ext = 'pdf'}) async {
    final dir = await _pdfsDir();
    final ts = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${ts}_$suffix.$ext');
  }

  // ══════════════════ Share ══════════════════

  Future<void> shareFile(String path, String name) async {
    await Share.shareXFiles(
      [XFile(path, name: name)],
      subject: name,
      text: 'شاهد هذا الملف',
    );
  }

  Future<void> shareBackup(String path) async {
    final name = p.basename(path);
    await Share.shareXFiles([XFile(path, name: name)], subject: name);
  }

  // ══════════════════ Images → PDF ══════════════════

  Future<String> imagesToPdf(List<XFile> images,
      {String baseName = 'images'}) async {
    final doc = pw.Document();
    for (final img in images) {
      final bytes = await img.readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (_) =>
              pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
    }
    final outBytes = await doc.save();
    final outPath = await _uniquePath(baseName);
    await File(outPath).writeAsBytes(outBytes);
    return outPath;
  }

  Future<String?> scanFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
        source: ImageSource.camera, imageQuality: 90);
    if (photo == null) return null;
    return imagesToPdf([photo], baseName: 'scan');
  }

  Future<int?> importImagesAsPdf(BuildContext context, {int? groupId}) async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return null;
    final path = await imagesToPdf(
      images,
      baseName: 'images_${DateTime.now().millisecondsSinceEpoch}',
    );
    final stat = await File(path).stat();
    return _db.insertFile(
        name: p.basename(path), path: path, size: stat.size, groupId: groupId);
  }

  // ══════════════════ Raster rendering ══════════════════

  Future<List<Uint8List>> _renderPages(File file,
      {int dpi = _rasterDpi}) async {
    final bytes = await file.readAsBytes();
    final images = <Uint8List>[];
    await for (final page in Printing.raster(bytes, dpi: dpi.toDouble())) {
      images.add(await page.toPng());
    }
    return images;
  }

  Future<File> _imagesToSinglePdf(List<Uint8List> pageImages,
      {String baseName = 'output'}) async {
    final doc = pw.Document();
    for (final img in pageImages) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(0),
          build: (_) => pw.Center(
            child: pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final bytes = await doc.save();
    final outPath = await _uniquePath(baseName);
    await File(outPath).writeAsBytes(bytes);
    return File(outPath);
  }

  // ══════════════════ Merge ══════════════════

  Future<File> mergePdfs(List<String> paths,
      {String baseName = 'merged'}) async {
    final all = <Uint8List>[];
    for (final path in paths) {
      final pages = await _renderPages(File(path));
      all.addAll(pages);
    }
    return _imagesToSinglePdf(all, baseName: baseName);
  }

  // ══════════════════ Extract range ══════════════════

  Future<File> extractRange(String sourcePath, int startPage, int endPage,
      {String baseName = 'extracted'}) async {
    final all = await _renderPages(File(sourcePath));
    final from = (startPage - 1).clamp(0, all.length);
    final to = endPage.clamp(from, all.length);
    return _imagesToSinglePdf(all.sublist(from, to), baseName: baseName);
  }

  // ══════════════════ Delete page ══════════════════

  Future<File> deletePage(String sourcePath, int pageIndex,
      {String baseName = 'deleted'}) async {
    final pages = await _renderPages(File(sourcePath));
    if (pageIndex < 0 || pageIndex >= pages.length) {
      throw Exception('صفحة غير موجودة');
    }
    if (pages.length <= 1) {
      throw Exception('لا يمكن حذف الصفحة الوحيدة');
    }
    pages.removeAt(pageIndex);
    return _imagesToSinglePdf(pages, baseName: baseName);
  }

  // ══════════════════ Save page as image ══════════════════

  Future<File> savePageAsImage(String sourcePath, int pageIndex,
      {int dpi = 300}) async {
    final pages = await _renderPages(File(sourcePath), dpi: dpi);
    if (pageIndex < 0 || pageIndex >= pages.length) {
      throw Exception('صفحة غير موجودة');
    }
    final backupDir = await _db.getBackupDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final outPath =
        p.join(backupDir.path, '${ts}_page_${pageIndex + 1}.png');
    await File(outPath).writeAsBytes(pages[pageIndex]);
    return File(outPath);
  }

  // ══════════════════ Watermark ══════════════════

  Future<File> addWatermark(
    String sourcePath,
    String watermarkText, {
    double fontSize = 60,
    int argbColor = 0x30888888,
  }) async {
    final pages = await _renderPages(File(sourcePath));

    pw.Font? font;
    try {
      font = await PdfGoogleFonts.cairoRegular();
    } catch (_) {}

    final doc = pw.Document();
    for (final img in pages) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              pw.Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child:
                    pw.Image(pw.MemoryImage(img), fit: pw.BoxFit.contain),
              ),
              pw.Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: pw.Align(
                  alignment: pw.Alignment.center,
                  child: pw.Transform.rotate(
                    angle: -0.5,
                    child: pw.Text(
                      watermarkText,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: fontSize,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromInt(argbColor),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final bytes = await doc.save();
    final outPath = await _uniquePath('watermarked');
    await File(outPath).writeAsBytes(bytes);
    return File(outPath);
  }

  // ══════════════════ THUMBNAILS ══════════════════

  Future<File?> getThumbnail(String pdfPath, {int dpi = 100}) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbsDir = Directory('${appDir.path}/thumbnails');
      if (!await thumbsDir.exists()) await thumbsDir.create(recursive: true);

      final hash = pdfPath.hashCode.toRadixString(16).replaceAll('-', 'n');
      final thumbFile = File('${thumbsDir.path}/$hash.png');

      if (await thumbFile.exists()) return thumbFile;

      final bytes = await File(pdfPath).readAsBytes();
      await for (final page
          in Printing.raster(bytes, dpi: dpi.toDouble(), pages: const [0])) {
        final png = await page.toPng();
        await thumbFile.writeAsBytes(png);
        return thumbFile;
      }
    } catch (_) {}
    return null;
  }

  // ══════════════════ Backup ══════════════════

  Future<File> exportFullBackup() async {
    final backupDir = await _db.getBackupDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final zipPath = p.join(backupDir.path,
        'PdfVaultBackup_v${DatabaseService.appVersion}_$ts.zip');

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    final dbDir = await getDatabasesPath();
    final dbFile = File(p.join(dbDir, 'pdf_vault.db'));
    if (await dbFile.exists()) await encoder.addFile(dbFile, 'pdf_vault.db');

    final pdfs = await _pdfsDir();
    await for (final entity in pdfs.list()) {
      if (entity is File) {
        await encoder.addFile(entity, 'pdfs/${p.basename(entity.path)}');
      }
    }
    await encoder.close();
    return File(zipPath);
  }

  Future<void> restoreFullBackup(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dbDir = await getDatabasesPath();
    final pdfsDir = await _pdfsDir();
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name == 'pdf_vault.db') {
        await File(p.join(dbDir, 'pdf_vault.db'))
            .writeAsBytes(entry.content as List<int>);
      } else if (name.startsWith('pdfs/')) {
        final fileName = p.basename(name);
        await File(p.join(pdfsDir.path, fileName))
            .writeAsBytes(entry.content as List<int>);
      }
    }
  }
}