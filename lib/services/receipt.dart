import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import '../data/models.dart';
import '../data/repos/settings_repo.dart';

/// إنشاء الإيصالات بصيغة PDF (تُستخدم للطباعة الحرارية والعادية والمشاركة)
class ReceiptBuilder {
  static pw.Font? _regular, _bold, _xbold;

  static Future<void> _fonts() async {
    _regular ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Medium.ttf'));
    _bold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-Bold.ttf'));
    _xbold ??= pw.Font.ttf(await rootBundle.load('assets/fonts/Tajawal-ExtraBold.ttf'));
  }

  /// عرض الورق القابل للطباعة بالمليمتر
  static double printableMm(int paper) => paper >= 80 ? 72 : 48;

  static PdfPageFormat rollFormat(int paper) {
    final w = printableMm(paper) * PdfPageFormat.mm;
    return PdfPageFormat(w, double.infinity, marginAll: 1.5 * PdfPageFormat.mm);
  }

  static String _title(InvoiceType t) => switch (t) {
        InvoiceType.sale => 'فاتورة بيع',
        InvoiceType.line => 'وصل بيع خط / خدمة',
        InvoiceType.repair => 'فاتورة صيانة',
        InvoiceType.debtPay => 'وصل تسديد',
      };

  static Future<Uint8List> invoice(Invoice inv, {int paper = 58, PdfPageFormat? format}) async {
    await _fonts();
    final s = SettingsRepo.instance;
    final doc = pw.Document(title: inv.code, author: s.shopName);
    final small = paper < 80;
    final fs = small ? 8.0 : 9.5;

    doc.addPage(pw.Page(
      pageFormat: format ?? rollFormat(paper),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _regular, bold: _bold),
      build: (c) => _frame(format, [
        ..._header(s, fs),
        _dash(),
        pw.Center(
          child: pw.Text(_title(inv.type), style: pw.TextStyle(font: _xbold, fontSize: fs + 3)),
        ),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: .8), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(
              inv.type == InvoiceType.line ? 'رقم الطلب ${inv.code}' : 'رقم ${inv.code}',
              textDirection: pw.TextDirection.rtl,
              style: pw.TextStyle(font: _xbold, fontSize: fs + 2),
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        _kv('التاريخ', dateTimeMs(inv.createdAt), fs),
        if (inv.customerName.isNotEmpty) _kv('الزبون', inv.customerName, fs),
        if (inv.customerPhone.isNotEmpty) _kv('الهاتف', inv.customerPhone, fs),
        _kv('الموظف', inv.userName, fs),
        if (inv.isVoid) pw.Center(child: pw.Text('*** فاتورة ملغاة ***', style: pw.TextStyle(font: _xbold, fontSize: fs + 2))),
        _dash(),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('المادة', style: pw.TextStyle(font: _bold, fontSize: fs))),
          pw.SizedBox(width: small ? 28 : 40, child: pw.Text('العدد', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: _bold, fontSize: fs))),
          pw.SizedBox(width: small ? 50 : 70, child: pw.Text('المبلغ', textAlign: pw.TextAlign.left, style: pw.TextStyle(font: _bold, fontSize: fs))),
        ]),
        pw.SizedBox(height: 2),
        for (final it in inv.items) ...[
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(it.name, style: pw.TextStyle(font: _bold, fontSize: fs)),
                if (it.detail.isNotEmpty) pw.Text(it.detail, style: pw.TextStyle(fontSize: fs - 1.5, color: PdfColors.grey800)),
                if (it.qty > 1) pw.Text('سعر المفرد ${numFmt(it.price)}', style: pw.TextStyle(fontSize: fs - 1.5)),
              ]),
            ),
            pw.SizedBox(width: small ? 28 : 40, child: pw.Text('${it.qty}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs))),
            pw.SizedBox(
                width: small ? 50 : 70,
                child: pw.Text(numFmt(it.total), textAlign: pw.TextAlign.left, style: pw.TextStyle(font: _bold, fontSize: fs))),
          ]),
          pw.SizedBox(height: 3),
        ],
        _dash(),
        if (inv.discount > 0) ...[
          _kv('المجموع', money(inv.subtotal), fs),
          _kv('الخصم', money(inv.discount), fs),
        ],
        pw.Container(
          margin: const pw.EdgeInsets.symmetric(vertical: 3),
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const pw.BoxDecoration(color: PdfColors.black),
          child: pw.Row(children: [
            pw.Text('الإجمالي', style: pw.TextStyle(font: _xbold, fontSize: fs + 2, color: PdfColors.white)),
            pw.Spacer(),
            pw.Text(money(inv.total), style: pw.TextStyle(font: _xbold, fontSize: fs + 3, color: PdfColors.white)),
          ]),
        ),
        if (inv.payment == 'credit') ...[
          _kv('طريقة الدفع', inv.paymentLabel, fs),
          _kv('المدفوع', money(inv.paid), fs),
          _kv('المتبقي (دين)', money(inv.remaining), fs, bold: true),
        ],
        if (inv.note.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 2), child: pw.Text(inv.note, style: pw.TextStyle(fontSize: fs - 1))),
        _dash(),
        ..._footer(s, fs),
      ]),
    ));
    return doc.save();
  }

  /// وصل استلام جهاز صيانة
  static Future<Uint8List> repairIntake(Repair r, {int paper = 58, PdfPageFormat? format}) async {
    await _fonts();
    final s = SettingsRepo.instance;
    final doc = pw.Document(title: r.code, author: s.shopName);
    final fs = paper < 80 ? 8.0 : 9.5;
    doc.addPage(pw.Page(
      pageFormat: format ?? rollFormat(paper),
      textDirection: pw.TextDirection.rtl,
      theme: pw.ThemeData.withFont(base: _regular, bold: _bold),
      build: (c) => _frame(format, [
        ..._header(s, fs),
        _dash(),
        pw.Center(child: pw.Text('وصل استلام جهاز صيانة', style: pw.TextStyle(font: _xbold, fontSize: fs + 3))),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.2), borderRadius: pw.BorderRadius.circular(4)),
            child: pw.Text(r.code, textDirection: pw.TextDirection.ltr, style: pw.TextStyle(font: _xbold, fontSize: fs + 8)),
          ),
        ),
        pw.SizedBox(height: 4),
        _kv('تاريخ الاستلام', dateTimeMs(r.receivedAt), fs),
        if (r.expectedAt != null) _kv('الموعد المتوقع', dateMs(r.expectedAt!), fs),
        _kv('الزبون', r.customerName, fs),
        if (r.customerPhone.isNotEmpty) _kv('الهاتف', r.customerPhone, fs),
        _dash(),
        _kv('الجهاز', r.device, fs, bold: true),
        if (r.imei.isNotEmpty) _kv('IMEI', r.imei, fs),
        _kv('العطل', r.issue, fs),
        if (r.accessories.isNotEmpty) _kv('الملحقات', r.accessories, fs),
        if (r.conditionNotes.isNotEmpty) _kv('حالة الجهاز', r.conditionNotes, fs),
        _dash(),
        if (r.estimatedCost > 0) _kv('الكلفة التقديرية', money(r.estimatedCost), fs, bold: true),
        if (r.deposit > 0) _kv('العربون المستلم', money(r.deposit), fs, bold: true),
        _kv('الموظف', r.userName, fs),
        if (s.get('repair_terms').isNotEmpty) ...[
          _dash(),
          pw.Text(s.get('repair_terms'), style: pw.TextStyle(fontSize: fs - 1.5)),
        ],
        _dash(),
        ..._footer(s, fs),
      ]),
    ));
    return doc.save();
  }

  static pw.Widget _frame(PdfPageFormat? format, List<pw.Widget> children) {
    final col = pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: children);
    if (format == null || format.height == double.infinity) return col;
    // ورق A4/A5: نضع الإيصال في المنتصف بعرض مناسب
    return pw.Align(
      alignment: pw.Alignment.topCenter,
      child: pw.Container(
        width: 90 * PdfPageFormat.mm,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: .6, color: PdfColors.grey600), borderRadius: pw.BorderRadius.circular(6)),
        child: col,
      ),
    );
  }

  static List<pw.Widget> _header(SettingsRepo s, double fs) => [
        pw.Center(child: pw.Text(s.shopName, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: _xbold, fontSize: fs + 7))),
        if (s.get('shop_address').isNotEmpty)
          pw.Center(child: pw.Text(s.get('shop_address'), textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: fs))),
        if (s.get('shop_phone').isNotEmpty)
          pw.Center(
              child: pw.Text(s.get('shop_phone'),
                  textDirection: pw.TextDirection.ltr, style: pw.TextStyle(font: _bold, fontSize: fs + 1))),
      ];

  static List<pw.Widget> _footer(SettingsRepo s, double fs) => [
        if (s.get('receipt_footer').isNotEmpty)
          pw.Center(child: pw.Text(s.get('receipt_footer'), textAlign: pw.TextAlign.center, style: pw.TextStyle(font: _bold, fontSize: fs))),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text(s.shopName, style: pw.TextStyle(fontSize: fs - 2, color: PdfColors.grey700))),
      ];

  static pw.Widget _kv(String k, String v, double fs, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('$k: ', style: pw.TextStyle(fontSize: fs, color: PdfColors.grey800)),
          pw.Expanded(
            child: pw.Text(v,
                textAlign: pw.TextAlign.left,
                style: pw.TextStyle(font: bold ? _xbold : _bold, fontSize: bold ? fs + 1 : fs)),
          ),
        ]),
      );

  static pw.Widget _dash() => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.LayoutBuilder(builder: (c, cons) {
          final n = ((cons?.maxWidth ?? 150) / 4).floor();
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: List.generate(n, (_) => pw.Container(width: 2, height: .7, color: PdfColors.black)),
          );
        }),
      );
}
