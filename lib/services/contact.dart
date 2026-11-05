import 'package:url_launcher/url_launcher.dart';

/// التواصل مع الزبائن: اتصال مباشر أو رسالة واتساب جاهزة
class Contact {
  /// تحويل الرقم العراقي إلى الصيغة الدولية: 07701234567 ← 9647701234567
  static String intl(String phone) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    var d = phone.split('').map((c) {
      final i = ar.indexOf(c);
      return i >= 0 ? '$i' : c;
    }).join().replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('964')) return d;
    if (d.startsWith('0')) d = d.substring(1);
    return '964$d';
  }

  static bool valid(String phone) => phone.replaceAll(RegExp(r'[^0-9٠-٩]'), '').length >= 10;

  static Future<bool> call(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')), mode: LaunchMode.externalApplication);

  static Future<bool> whatsapp(String phone, String text) => launchUrl(
        Uri.parse('https://wa.me/${intl(phone)}?text=${Uri.encodeComponent(text)}'),
        mode: LaunchMode.externalApplication,
      );
}
