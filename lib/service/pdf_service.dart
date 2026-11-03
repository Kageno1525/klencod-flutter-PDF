import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfService {
  static Future<String?> generateThumbnail(String pdfPath) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(pdfPath);
      if (doc.pages.isEmpty) return null;
      final page = doc.pages.first;
      final pageImage = await page.render(
        width: 240,
        height: 340,
        fullWidth: page.width,
        fullHeight: page.height,
      );
      if (pageImage == null) return null;
      final image = img.Image.fromBytes(
        width: pageImage.width,
        height: pageImage.height,
        bytes: pageImage.pixels.buffer,
        numChannels: 4,
        order: img.ChannelOrder.rgba,
      );
      final dir = await getApplicationDocumentsDirectory();
      final thumbDir = Directory(p.join(dir.path, 'thumbs'));
      if (!await thumbDir.exists()) await thumbDir.create(recursive: true);
      final fileName = p.basenameWithoutExtension(pdfPath);
      final thumbPath = p.join(thumbDir.path, '$fileName.png');
      await File(thumbPath).writeAsBytes(img.encodePng(image));
      return thumbPath;
    } catch (_) {
      return null;
    } finally {
      await doc?.dispose();
    }
  }

  static Future<int> getPageCount(String pdfPath) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(pdfPath);
      return doc.pages.length;
    } catch (_) {
      return 0;
    } finally {
      await doc?.dispose();
    }
  }

  static Future<int> getFileSize(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }
}