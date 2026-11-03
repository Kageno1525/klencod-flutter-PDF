import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import 'pdf_service.dart';

class ImportService {
  static Future<int> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return 0;

    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory(p.join(appDir.path, 'pdfs'));
    if (!await pdfDir.exists()) await pdfDir.create(recursive: true);

    int imported = 0;
    for (final file in result.files) {
      if (file.path == null) continue;
      final original = File(file.path!);
      final fileName = p.basename(original.path);
      final targetPath = p.join(pdfDir.path, fileName);
      try {
        await original.copy(targetPath);
      } catch (_) {
        continue;
      }

      final results = await Future.wait([
        PdfService.generateThumbnail(targetPath),
        PdfService.getPageCount(targetPath),
        PdfService.getFileSize(targetPath),
      ]);

      await DatabaseService.instance.insert(PdfDoc(
        title: p.basenameWithoutExtension(fileName),
        filePath: targetPath,
        thumbPath: results[0] as String?,
        pageCount: results[1] as int,
        fileSize: results[2] as int,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ));
      imported++;
    }
    return imported;
  }
}