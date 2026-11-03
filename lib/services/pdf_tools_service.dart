import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  // ===== Share =====
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

  // ===== Images to PDF =====
  Future<String> imagesToPdf(
    List<XFile> images, {
    String baseName = 'images',
    bool compress = true,
  }) async {
    final doc = pw.Document();
    for (final img in images) {
      final bytes = await img.readAsBytes();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    final outBytes = await doc.save();
    final outPath = await _uniquePath(baseName);
    await File(outPath).writeAsBytes(outBytes);
    return outPath;
  }

  // ===== Simple scan from camera =====
  Future<String?> scanFromCamera() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (photo == null) return null;
    return imagesToPdf([photo], baseName: 'scan');
  }

  // ===== Import images to PDF and register in DB =====
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
      name: p.basename(path),
      path: path,
      size: stat.size,
      groupId: groupId,
    );
  }

  // ===== Full backup as ZIP (using archive package) =====
  Future<File> exportFullBackup() async {
    final backupDir = await _db.getBackupDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final zipPath = p.join(
      backupDir.path,
      'PdfVaultBackup_v${DatabaseService.appVersion}_$ts.zip',
    );

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    final dbDir = await getDatabasesPath();
    final dbFile = File(p.join(dbDir, 'pdf_vault.db'));
    if (await dbFile.exists()) {
      await encoder.addFile(dbFile, 'pdf_vault.db');
    }

    final pdfs = await _pdfsDir();
    await for (final entity in pdfs.list()) {
      if (entity is File) {
        await encoder.addFile(entity, 'pdfs/${p.basename(entity.path)}');
      }
    }

    await encoder.close();
    return File(zipPath);
  }

  // ===== Restore from ZIP =====
  Future<void> restoreFullBackup(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    final dbDir = await getDatabasesPath();
    final pdfsDir = await _pdfsDir();

    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (name == 'pdf_vault.db') {
        final target = File(p.join(dbDir, 'pdf_vault.db'));
        await target.writeAsBytes(entry.content as List<int>);
      } else if (name.startsWith('pdfs/')) {
        final fileName = p.basename(name);
        final target = File(p.join(pdfsDir.path, fileName));
        await target.writeAsBytes(entry.content as List<int>);
      }
    }
  }
}