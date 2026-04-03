import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App-private offline copies for Premium (PDF + audio). Not the system Downloads folder.
class OfflineMediaStore {
  OfflineMediaStore._();

  static String safeSlug(String slug) {
    final s = slug.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (s.isEmpty) return 'topic';
    return s.length > 80 ? s.substring(0, 80) : s;
  }

  static Future<Directory> _root() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory(p.join(base.path, 'offline_media'));
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    return d;
  }

  static Future<File> pdfFile(String slug) async {
    final root = await _root();
    return File(p.join(root.path, '${safeSlug(slug)}.pdf'));
  }

  static Future<bool> pdfExists(String slug) async {
    return (await pdfFile(slug)).exists();
  }

  static Future<void> savePdf(String slug, Uint8List bytes) async {
    final f = await pdfFile(slug);
    await f.writeAsBytes(bytes, flush: true);
  }

  static Future<void> deletePdf(String slug) async {
    final f = await pdfFile(slug);
    if (await f.exists()) await f.delete();
  }

  static String _audioExtFromUrl(String url) {
    try {
      final path = Uri.parse(url).path.toLowerCase();
      final ext = p.extension(path);
      const ok = {'.mp3', '.m4a', '.aac', '.wav', '.ogg', '.flac', '.opus'};
      if (ext.isNotEmpty && ok.contains(ext)) return ext;
    } catch (_) {}
    return '.mp3';
  }

  static Future<File> audioFile(String slug, String sourceUrl) async {
    final root = await _root();
    return File(p.join(root.path, '${safeSlug(slug)}${_audioExtFromUrl(sourceUrl)}'));
  }

  static Future<bool> audioExists(String slug, String sourceUrl) async {
    return (await audioFile(slug, sourceUrl)).exists();
  }

  static Future<void> saveAudio(String slug, String sourceUrl, Uint8List bytes) async {
    final f = await audioFile(slug, sourceUrl);
    await f.writeAsBytes(bytes, flush: true);
  }

  static Future<void> deleteAudio(String slug, String sourceUrl) async {
    final f = await audioFile(slug, sourceUrl);
    if (await f.exists()) await f.delete();
  }
}
