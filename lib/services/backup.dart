import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../data/db.dart';
import '../data/repos/base.dart';
import '../data/repos/settings_repo.dart';
import 'session.dart';
import 'telegram.dart';

/// النسخ الاحتياطي والاستعادة — حماية بيانات المحل من الضياع
class BackupService {
  static Future<List<int>> exportBytes() async {
    final data = <String, Object?>{
      'app': 'alarab',
      'version': AppDb.version,
      'created_at': nowMs(),
    };
    for (final t in AppDb.tables) {
      data[t] = await db.query(t);
    }
    return utf8.encode(jsonEncode(data));
  }

  static String fileName() {
    final n = DateTime.now();
    return 'alarab-backup-${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}.json';
  }

  static Future<File> _writeTemp(List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, fileName()));
    await f.writeAsBytes(bytes, flush: true);
    return f;
  }

  /// مشاركة النسخة (حفظ في الملفات / إرسال واتساب / درايف ...)
  static Future<void> share() async {
    final f = await _writeTemp(await exportBytes());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(f.path, mimeType: 'application/json')],
      subject: 'نسخة احتياطية - ${SettingsRepo.instance.shopName}',
    ));
  }

  static Future<String?> sendToTelegram() async {
    final bytes = await exportBytes();
    return TelegramService.instance
        .sendDocument(bytes, fileName(), '🗄 نسخة احتياطية — ${SettingsRepo.instance.shopName}\n${dateTimeStr(DateTime.now())}');
  }

  /// نسخة تلقائية يومية داخل ذاكرة التطبيق (آخر 7 نسخ)
  static Future<void> autoBackup() async {
    try {
      final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'backups'));
      await dir.create(recursive: true);
      final n = DateTime.now();
      final name = 'auto-${n.year}${two(n.month)}${two(n.day)}.json';
      final f = File(p.join(dir.path, name));
      if (await f.exists()) return;
      await f.writeAsBytes(await exportBytes(), flush: true);
      final files = (await dir.list().toList()).whereType<File>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final old in files.skip(7)) {
        await old.delete();
      }
    } catch (_) {}
  }

  static Future<List<File>> autoBackups() async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'backups'));
    if (!await dir.exists()) return [];
    return (await dir.list().toList()).whereType<File>().toList()..sort((a, b) => b.path.compareTo(a.path));
  }

  static Future<List<int>?> pickFile() async {
    final f = await FilePicker.pickFile(type: FileType.any, dialogTitle: 'اختر ملف النسخة الاحتياطية');
    if (f == null) return null;
    return f.readAsBytes();
  }

  /// استعادة كاملة: تستبدل كل البيانات الحالية بمحتوى النسخة
  static Future<void> restore(List<int> bytes) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('الملف غير صالح');
    }
    if (data['app'] != 'alarab') throw Exception('هذا الملف ليس نسخة احتياطية من برنامج العراب');
    await db.transaction((txn) async {
      for (final t in AppDb.tables.reversed) {
        await txn.delete(t);
      }
      for (final t in AppDb.tables) {
        final rows = (data[t] as List?) ?? const [];
        final b = txn.batch();
        for (final r in rows) {
          b.insert(t, Map<String, Object?>.from(r as Map));
        }
        await b.commit(noResult: true);
      }
    });
    await SettingsRepo.instance.load();
    await logActivity(db, 'استعادة نسخة احتياطية', Session.instance.actor);
    changed();
  }
}
