import 'package:intl/intl.dart';

final _num = NumberFormat('#,##0', 'en_US');

/// تنسيق المبالغ بالدينار العراقي
String money(num v) => '${_num.format(v.round())} د.ع';
String numFmt(num v) => _num.format(v.round());

/// تحويل نص فيه أرقام عربية/فواصل إلى رقم
int parseMoney(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = ar.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (RegExp(r'[0-9]').hasMatch(ch)) {
      b.write(ch);
    }
  }
  return int.tryParse(b.toString()) ?? 0;
}

String two(int n) => n.toString().padLeft(2, '0');

String dateStr(DateTime d) => '${d.year}/${two(d.month)}/${two(d.day)}';

String timeStr(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${two(h)}:${two(d.minute)} ${d.hour < 12 ? 'ص' : 'م'}';
}

String dateTimeStr(DateTime d) => '${dateStr(d)}  ${timeStr(d)}';
String dateTimeMs(int ms) => dateTimeStr(DateTime.fromMillisecondsSinceEpoch(ms));
String dateMs(int ms) => dateStr(DateTime.fromMillisecondsSinceEpoch(ms));

const _weekdays = ['الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
const _months = [
  'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
  'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول'
];

String weekday(DateTime d) => _weekdays[d.weekday - 1];
String monthName(int m) => _months[m - 1];
String longDate(DateTime d) => '${weekday(d)}، ${d.day} ${monthName(d.month)} ${d.year}';

/// وقت نسبي مختصر
String ago(int ms) {
  final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 30) return 'قبل ${diff.inDays} يوم';
  return dateMs(ms);
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
int nowMs() => DateTime.now().millisecondsSinceEpoch;

/// تطبيع النص العربي للبحث (إزالة التشكيل وتوحيد الألف والياء والتاء المربوطة)
String normalizeAr(String s) {
  var t = s.toLowerCase().trim();
  t = t.replaceAll(RegExp('[ً-ْـ]'), '');
  t = t.replaceAll(RegExp('[أإآ]'), 'ا').replaceAll('ى', 'ي').replaceAll('ة', 'ه');
  return t;
}
