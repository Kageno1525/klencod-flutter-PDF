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

  // ─── PDF MERGE & SPLIT ───

  Future<List<Uint8List>> renderPdfPages(File file, {int dpi = 130}) async {
    final bytes = await file.readAsBytes();
    final images = <Uint8List>[];
    await for (final page in Printing.raster(bytes, dpi: dpi.toDouble())) {
      images.add(await page.toPng());
      await page.dispose();
    }
    return images;
  }

  Future<File> imagesToSinglePdf(List<Uint8List> pageImages,
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

  Future<File> mergePdfs(List<String> paths,
      {String baseName = 'merged'}) async {
    final all = <Uint8List>[];
    for (final path in paths) {
      final pages = await renderPdfPages(File(path));
      all.addAll(pages);
    }
    return imagesToSinglePdf(all, baseName: baseName);
  }

  Future<File> splitPdf(String sourcePath, List<int> keepPageIndices,
      {String baseName = 'split'}) async {
    final all = await renderPdfPages(File(sourcePath));
    final selected = <Uint8List>[];
    for (final idx in keepPageIndices) {
      if (idx >= 0 && idx < all.length) selected.add(all[idx]);
    }
    return imagesToSinglePdf(selected, baseName: baseName);
  }

  Future<File> extractRange(String sourcePath, int startPage, int endPage,
      {String baseName = 'extracted'}) async {
    final all = await renderPdfPages(File(sourcePath));
    final from = (startPage - 1).clamp(0, all.length);
    final to = endPage.clamp(from, all.length);
    return imagesToSinglePdf(all.sublist(from, to), baseName: baseName);
  }

  // ─── BACKUP ───

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