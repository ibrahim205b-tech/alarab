import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../services/printer.dart';
import '../../services/receipt.dart';

typedef PdfBuild = Future<Uint8List> Function(int paper, PdfPageFormat? format);

PdfBuild invoicePdf(Invoice inv) => (paper, format) => ReceiptBuilder.invoice(inv, paper: paper, format: format);
PdfBuild repairPdf(Repair r) => (paper, format) => ReceiptBuilder.repairIntake(r, paper: paper, format: format);

Future<void> printDoc(BuildContext context, PdfBuild build, String name) async {
  final printer = PrinterService.instance;
  if (!printer.hasPrinter) {
    toast(context, 'لا توجد طابعة مضبوطة — اضبطها من الإدارة ← الطابعة', error: true, icon: Icons.print_disabled_rounded);
    return;
  }
  toast(context, 'جاري الطباعة...', icon: Icons.print_rounded);
  final err = await printer.printPdf(build: build, name: name);
  if (!context.mounted) return;
  if (err == null) {
    toast(context, 'تمت الطباعة', icon: Icons.print_rounded);
  } else {
    toast(context, err, error: true);
  }
}

Future<void> shareDoc(BuildContext context, PdfBuild build, String name) async {
  try {
    final bytes = await build(PrinterService.instance.paper, null);
    await Printing.sharePdf(bytes: bytes, filename: '$name.pdf');
  } catch (e) {
    if (context.mounted) toast(context, 'تعذرت المشاركة', error: true);
  }
}

Future<void> previewDoc(BuildContext context, PdfBuild build, String name) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (c) => Scaffold(
      appBar: AppBar(title: Text('معاينة $name')),
      body: PdfPreview(
        build: (f) => build(PrinterService.instance.paper, null),
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: '$name.pdf',
        loadingWidget: const CircularProgressIndicator(),
      ),
    ),
  ));
}

/// أزرار الإيصال (طباعة / مشاركة / معاينة)
class ReceiptButtons extends StatelessWidget {
  final PdfBuild doc;
  final String name;
  const ReceiptButtons({super.key, required this.doc, required this.name});

  @override
  Widget build(BuildContext context) {
    final has = PrinterService.instance.hasPrinter;
    return Row(children: [
      Expanded(
        child: FilledButton.icon(
          onPressed: () => printDoc(context, doc, name),
          style: has ? null : FilledButton.styleFrom(backgroundColor: context.cs.surfaceContainerHighest, foregroundColor: context.cs.onSurfaceVariant),
          icon: Icon(has ? Icons.print_rounded : Icons.print_disabled_rounded),
          label: const Text('طباعة'),
        ),
      ),
      const SizedBox(width: 10),
      IconButton.filledTonal(
        tooltip: 'مشاركة PDF',
        onPressed: () => shareDoc(context, doc, name),
        icon: const Icon(Icons.share_rounded),
        style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        tooltip: 'معاينة',
        onPressed: () => previewDoc(context, doc, name),
        icon: const Icon(Icons.visibility_rounded),
        style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
      ),
    ]);
  }
}

/// نافذة نجاح العملية مع الإيصال
Future<void> showSuccess(
  BuildContext context, {
  required String title,
  required String code,
  required int amount,
  required PdfBuild build,
  String? subtitle,
}) async {
  HapticFeedback.heavyImpact();
  final printer = PrinterService.instance;
  if (printer.autoPrint) {
    printer.printPdf(build: build, name: code).then((err) {
      if (err != null && context.mounted) toast(context, err, error: true);
    });
  }
  await showAppSheet(
    context,
    maxWidth: 460,
    Builder(
      builder: (c) => SheetScaffold(
        title: '',
        footer: Column(mainAxisSize: MainAxisSize.min, children: [
          ReceiptButtons(doc: build, name: code),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: () => Navigator.pop(c), child: const Text('تم')),
          ),
        ]),
        child: Column(children: [
          const SuccessCheck(size: 96),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))
              .animate()
              .fadeIn(delay: 350.ms)
              .slideY(begin: .3, end: 0),
          const SizedBox(height: 8),
          Pill(code, color: c.cs.primary, icon: Icons.tag_rounded).animate().fadeIn(delay: 450.ms),
          const SizedBox(height: 14),
          CountUp(amount, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: c.cs.primary)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: c.cs.onSurfaceVariant)),
          ],
          if (printer.autoPrint) ...[
            const SizedBox(height: 10),
            Pill('تم إرسال الإيصال للطابعة', color: AppColors.success, icon: Icons.print_rounded),
          ],
        ]),
      ),
    ),
  );
}

/// علامة صح متحركة
class SuccessCheck extends StatefulWidget {
  final double size;
  const SuccessCheck({super.key, this.size = 90});
  @override
  State<SuccessCheck> createState() => _SuccessCheckState();
}

class _SuccessCheckState extends State<SuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (c, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _CheckPainter(_c.value, AppColors.success),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t;
  final Color color;
  _CheckPainter(this.t, this.color);
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    final circleT = Curves.easeOutCubic.transform((t / .55).clamp(0, 1));
    final scale = Curves.easeOutBack.transform((t / .6).clamp(0, 1));
    canvas.drawCircle(c, r * scale, Paint()..color = color.withValues(alpha: .15));
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * .82),
      -math.pi / 2,
      2 * math.pi * circleT,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * .07
        ..strokeCap = StrokeCap.round,
    );
    final checkT = Curves.easeOutCubic.transform(((t - .45) / .55).clamp(0, 1));
    if (checkT > 0) {
      final p1 = Offset(s.width * .3, s.height * .52);
      final p2 = Offset(s.width * .44, s.height * .66);
      final p3 = Offset(s.width * .72, s.height * .38);
      final path = Path()..moveTo(p1.dx, p1.dy);
      final firstLen = (p2 - p1).distance, secondLen = (p3 - p2).distance;
      final total = firstLen + secondLen;
      final cur = total * checkT;
      if (cur <= firstLen) {
        final q = Offset.lerp(p1, p2, cur / firstLen)!;
        path.lineTo(q.dx, q.dy);
      } else {
        path.lineTo(p2.dx, p2.dy);
        final q = Offset.lerp(p2, p3, (cur - firstLen) / secondLen)!;
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s.width * .08
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter o) => o.t != t;
}

String invoiceTitle(Invoice inv) => switch (inv.type) {
      InvoiceType.sale => 'تمت عملية البيع',
      InvoiceType.line => 'تم بيع الخط',
      InvoiceType.repair => 'تم تسليم الجهاز',
      InvoiceType.debtPay => 'تم تسجيل الدفعة',
    };

Future<void> showInvoiceSuccess(BuildContext context, Invoice inv, {String? subtitle}) => showSuccess(
      context,
      title: invoiceTitle(inv),
      code: inv.code,
      amount: inv.total,
      build: invoicePdf(inv),
      subtitle: subtitle ?? (inv.items.length == 1 ? inv.items.first.name : '${inv.items.length} مواد'),
    );

String moneyLabel(int v) => money(v);
