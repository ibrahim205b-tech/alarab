import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/format.dart';
import '../data/db.dart';
import '../data/repos/settings_repo.dart';

/// إشعارات تليجرام: كل عملية بيع مؤكدة تُرسل رسالة للبوت.
/// إذا لم يتوفر إنترنت تُحفظ الرسالة في صندوق الانتظار وتُعاد المحاولة تلقائياً.
class TelegramService {
  TelegramService._();
  static final TelegramService instance = TelegramService._();

  /// يمكن استبداله في الاختبارات
  http.Client client = http.Client();
  Timer? _timer;
  bool _flushing = false;

  SettingsRepo get _s => SettingsRepo.instance;
  bool get configured => _s.get('tg_token').isNotEmpty && _s.get('tg_chat').isNotEmpty;
  bool get enabled => _s.flag('tg_enabled') && configured;

  void startAutoRetry() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => flush());
  }

  static String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  /// event: sale | line | repair | debt | expense
  Future<void> notify(String event, String text) async {
    if (!enabled || !_s.flag('tg_ev_$event')) return;
    final shop = esc(_s.shopName);
    final full = '$text\n\n🏪 <b>$shop</b>';
    await AppDb.instance.db.insert('telegram_outbox', {'text': full, 'attempts': 0, 'created_at': nowMs()});
    unawaited(flush());
  }

  Future<int> pendingCount() async {
    final r = await AppDb.instance.db.rawQuery('SELECT COUNT(*) c FROM telegram_outbox');
    return (r.first['c'] as num).toInt();
  }

  Future<void> flush() async {
    if (_flushing || !enabled || !AppDb.instance.isOpen) return;
    _flushing = true;
    try {
      final db = AppDb.instance.db;
      final rows = await db.query('telegram_outbox', orderBy: 'id', limit: 30);
      for (final r in rows) {
        final err = await _send(_s.get('tg_token'), _s.get('tg_chat'), r['text'].toString());
        if (err == null) {
          await db.delete('telegram_outbox', where: 'id = ?', whereArgs: [r['id']]);
        } else {
          final attempts = (r['attempts'] as num).toInt() + 1;
          // رسالة مرفوضة نهائياً من تليجرام (وليس انقطاع إنترنت) تُحذف بعد عدة محاولات
          if (attempts >= 20) {
            await db.delete('telegram_outbox', where: 'id = ?', whereArgs: [r['id']]);
          } else {
            await db.update('telegram_outbox', {'attempts': attempts}, where: 'id = ?', whereArgs: [r['id']]);
          }
          break; // غالباً لا يوجد إنترنت — نتوقف ونحاول لاحقاً
        }
      }
    } catch (e) {
      debugPrint('telegram flush: $e');
    } finally {
      _flushing = false;
    }
  }

  /// يعيد null عند النجاح أو رسالة الخطأ
  Future<String?> _send(String token, String chat, String text) async {
    try {
      final res = await client
          .post(
            Uri.parse('https://api.telegram.org/bot$token/sendMessage'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'chat_id': chat,
              'text': text,
              'parse_mode': 'HTML',
              'disable_web_page_preview': true,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) return null;
      try {
        return (jsonDecode(res.body) as Map)['description']?.toString() ?? 'HTTP ${res.statusCode}';
      } catch (_) {
        return 'HTTP ${res.statusCode}';
      }
    } catch (e) {
      return 'تعذر الاتصال بالإنترنت';
    }
  }

  Future<String?> test(String token, String chat) => _send(token.trim(), chat.trim(),
      '✅ تم ربط البوت بنجاح\nسيصلك إشعار هنا عند كل عملية بيع في <b>${esc(_s.shopName)}</b>');

  /// جلب معرّف المحادثة تلقائياً من آخر رسالة أُرسلت للبوت
  Future<(String?, String?)> detectChatId(String token) async {
    try {
      final res = await client
          .get(Uri.parse('https://api.telegram.org/bot${token.trim()}/getUpdates'))
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map;
      if (body['ok'] != true) return (null, body['description']?.toString() ?? 'رمز البوت غير صحيح');
      final results = (body['result'] as List).reversed;
      for (final u in results) {
        final msg = (u as Map)['message'] ?? u['channel_post'] ?? u['my_chat_member'];
        final chat = (msg as Map?)?['chat'] as Map?;
        if (chat != null) return (chat['id'].toString(), null);
      }
      return (null, 'أرسل أي رسالة للبوت من تليجرام ثم أعد المحاولة');
    } catch (e) {
      return (null, 'تعذر الاتصال بالإنترنت');
    }
  }

  /// إرسال ملف (نسخة احتياطية) إلى تليجرام
  Future<String?> sendDocument(List<int> bytes, String filename, String caption) async {
    if (!configured) return 'لم يتم إعداد بوت تليجرام';
    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('https://api.telegram.org/bot${_s.get('tg_token')}/sendDocument'))
        ..fields['chat_id'] = _s.get('tg_chat')
        ..fields['caption'] = caption
        ..files.add(http.MultipartFile.fromBytes('document', bytes, filename: filename));
      final res = await client.send(req).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) return null;
      return 'HTTP ${res.statusCode}';
    } catch (e) {
      return 'تعذر الإرسال: تأكد من الإنترنت';
    }
  }
}
