/// منطق توليد والتحقق من أكواد التفعيل (اشتراك البرنامج).
/// نفس هذا المنطق يُستخدم في التطبيق، وفي سكربت التوليد `tools/license_gen.dart`،
/// وفي صفحة التوليد `license-generator.html` — حتى تتطابق الأكواد في كل مكان.
/// الكود مرتبط بـ"رمز الجهاز"، فلا يعمل كود جهاز على جهاز آخر، ولا يمكن
/// تعديل تاريخ الانتهاء بدون كسر التوقيع.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// المفتاح السري الافتراضي. يمكن استبداله وقت البناء عبر:
///   flutter build apk --dart-define=ALARAB_LICENSE_SECRET=<المفتاح>
/// (يُضبط في GitHub Actions كـ Secret لحماية أقوى مع مستودع عام).
const _defaultSecret = 'a95296fdacc0eddc8568ff02c43cd097aed36e010645e830051b3f3cea16ac8f';
const licenseSecret = String.fromEnvironment('ALARAB_LICENSE_SECRET', defaultValue: _defaultSecret);

/// أبجدية Crockford Base32 (بدون الحروف المتشابهة I L O U)
const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

String _b32encode(List<int> bytes) {
  var bits = 0, value = 0;
  final out = StringBuffer();
  for (final b in bytes) {
    value = (value << 8) | b;
    bits += 8;
    while (bits >= 5) {
      out.write(_alphabet[(value >> (bits - 5)) & 31]);
      bits -= 5;
    }
  }
  if (bits > 0) out.write(_alphabet[(value << (5 - bits)) & 31]);
  return out.toString();
}

List<int>? _b32decode(String s) {
  var bits = 0, value = 0;
  final out = <int>[];
  for (final ch in s.split('')) {
    final idx = _alphabet.indexOf(ch);
    if (idx < 0) return null;
    value = (value << 5) | idx;
    bits += 5;
    if (bits >= 8) {
      out.add((value >> (bits - 8)) & 0xff);
      bits -= 8;
    }
  }
  return out;
}

/// تنقية ما يكتبه المستخدم: حروف كبيرة، وتصحيح الحروف المتشابهة
String normalizeCode(String s) {
  final b = StringBuffer();
  for (var ch in s.toUpperCase().split('')) {
    if (ch == 'I' || ch == 'L') ch = '1';
    if (ch == 'O') ch = '0';
    if (ch == 'U') ch = 'V';
    if (_alphabet.contains(ch)) b.write(ch);
  }
  return b.toString();
}

/// رمز الجهاز المعروض (ALRB-XXXX-XXXX-XXXX) → الصيغة القياسية (12 حرف)
String canonicalDeviceId(String shown) => normalizeCode(shown.replaceAll(RegExp('^ALRB', caseSensitive: false), ''));

List<int> _sig(String deviceId, int expiryDays, String secret) {
  final msg = '${canonicalDeviceId(deviceId)}:$expiryDays';
  return Hmac(sha256, utf8.encode(secret)).convert(utf8.encode(msg)).bytes.sublist(0, 4);
}

/// توليد كود تفعيل لجهاز معيّن حتى تاريخ معيّن (عدد الأيام منذ 1970)
String generateCode(String deviceId, int expiryDays, {String secret = licenseSecret}) {
  final sig = _sig(deviceId, expiryDays, secret);
  final payload = [(expiryDays >> 8) & 0xff, expiryDays & 0xff, ...sig];
  final code = _b32encode(payload);
  return '${code.substring(0, 5)}-${code.substring(5, 10)}';
}

/// توليد كود حتى تاريخ محدد
String generateCodeUntil(String deviceId, DateTime expiry, {String secret = licenseSecret}) =>
    generateCode(deviceId, expiry.millisecondsSinceEpoch ~/ 86400000, secret: secret);

/// التحقق من الكود. يعيد تاريخ الانتهاء (عدد الأيام) أو null إذا كان غير صالح لهذا الجهاز
int? verifyCode(String deviceId, String code, {String secret = licenseSecret}) {
  final bytes = _b32decode(normalizeCode(code));
  if (bytes == null || bytes.length < 6) return null;
  final expiryDays = (bytes[0] << 8) | bytes[1];
  final sig = bytes.sublist(2, 6);
  final expected = _sig(deviceId, expiryDays, secret);
  for (var i = 0; i < 4; i++) {
    if (sig[i] != expected[i]) return null;
  }
  return expiryDays;
}
