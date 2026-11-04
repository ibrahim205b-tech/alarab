import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

import '../data/repos/settings_repo.dart';
import 'receipt.dart';

class BtDevice {
  final String name, mac;
  const BtDevice(this.name, this.mac);
}

/// الطباعة: طابعة بلوتوث حرارية (58/80 مم) أو طباعة النظام (واي فاي/USB/PDF).
/// إذا لم تتوفر طابعة يستمر البرنامج بالعمل بشكل طبيعي.
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  SettingsRepo get _s => SettingsRepo.instance;

  /// none | bluetooth | system
  String get mode => _s.get('printer_mode', 'none');
  int get paper => _s.integer('paper_width', 58);
  bool get hasPrinter => mode == 'bluetooth' ? _s.get('bt_mac').isNotEmpty : mode == 'system';
  bool get autoPrint => _s.flag('auto_print') && hasPrinter;
  String get btName => _s.get('bt_name');

  Future<bool> ensureBtPermission() async {
    if (!Platform.isAndroid) return true;
    final res = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    final granted = res.values.every((s) => s.isGranted || s.isLimited);
    if (granted) return true;
    // أجهزة أندرويد 11 وأقدم لا تحتاج هذه الصلاحيات
    return await PrintBluetoothThermal.isPermissionBluetoothGranted;
  }

  Future<(List<BtDevice>, String?)> pairedDevices() async {
    try {
      if (!await ensureBtPermission()) return (<BtDevice>[], 'يجب السماح بصلاحية البلوتوث');
      if (!await PrintBluetoothThermal.bluetoothEnabled) return (<BtDevice>[], 'شغّل البلوتوث أولاً');
      final list = await PrintBluetoothThermal.pairedBluetooths;
      return (list.map((e) => BtDevice(e.name, e.macAdress)).toList(), null);
    } catch (e) {
      return (<BtDevice>[], 'تعذر قراءة أجهزة البلوتوث');
    }
  }

  /// يطبع ملف PDF حسب الإعداد. يعيد null عند النجاح أو رسالة خطأ
  Future<String?> printPdf({required Future<Uint8List> Function(int paper, PdfPageFormat? format) build, String name = 'receipt'}) async {
    try {
      switch (mode) {
        case 'bluetooth':
          final bytes = await build(paper, null);
          return await _printBluetooth(bytes);
        case 'system':
          final ok = await Printing.layoutPdf(
            name: name,
            format: PdfPageFormat.a5,
            onLayout: (f) => build(paper, f),
          );
          return ok ? null : 'تم إلغاء الطباعة';
        default:
          return 'لا توجد طابعة مضبوطة — يمكنك ضبطها من الإدارة ← الطابعة';
      }
    } catch (e) {
      debugPrint('print error: $e');
      return 'تعذرت الطباعة: تأكد من تشغيل الطابعة واتصالها';
    }
  }

  Future<String?> _printBluetooth(Uint8List pdf) async {
    final mac = _s.get('bt_mac');
    if (mac.isEmpty) return 'لم يتم اختيار طابعة البلوتوث';
    if (!await ensureBtPermission()) return 'يجب السماح بصلاحية البلوتوث';
    if (!await PrintBluetoothThermal.bluetoothEnabled) return 'البلوتوث مطفأ';
    var connected = await PrintBluetoothThermal.connectionStatus;
    if (!connected) {
      connected = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    }
    if (!connected) return 'تعذر الاتصال بالطابعة ($btName)';
    final bytes = await pdfToEscPos(pdf, paper);
    // إرسال على دفعات حتى لا يمتلئ مخزن الطابعة
    const chunk = 4096;
    for (var i = 0; i < bytes.length; i += chunk) {
      final ok = await PrintBluetoothThermal.writeBytes(bytes.sublist(i, i + chunk > bytes.length ? bytes.length : i + chunk));
      if (!ok) return 'انقطع الاتصال أثناء الطباعة';
    }
    return null;
  }

  /// تحويل صفحة PDF إلى صورة نقطية بأوامر ESC/POS (يدعم العربية بالكامل لأنها تُطبع كصورة)
  static Future<List<int>> pdfToEscPos(Uint8List pdf, int paper) async {
    final dots = paper >= 80 ? 576 : 384;
    final dpi = dots / (ReceiptBuilder.printableMm(paper) / 25.4);
    final out = <int>[0x1B, 0x40]; // تهيئة
    await for (final page in Printing.raster(pdf, dpi: dpi)) {
      out.addAll(rasterToEscPos(page.pixels, page.width, page.height, dots));
    }
    out.addAll([0x1B, 0x64, 0x04]); // تغذية 4 أسطر
    out.addAll([0x1D, 0x56, 0x42, 0x00]); // قص الورق (إن وُجدت القاطعة)
    return out;
  }

  /// RGBA → أبيض وأسود → أمر GS v 0
  static List<int> rasterToEscPos(Uint8List rgba, int width, int height, int maxDots) {
    final w = width > maxDots ? maxDots : width;
    final bytesPerRow = (w + 7) ~/ 8;
    final out = <int>[];
    const band = 128;
    for (var y0 = 0; y0 < height; y0 += band) {
      final h = (y0 + band > height) ? height - y0 : band;
      out.addAll([0x1D, 0x76, 0x30, 0x00, bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF, h & 0xFF, (h >> 8) & 0xFF]);
      for (var y = y0; y < y0 + h; y++) {
        for (var bx = 0; bx < bytesPerRow; bx++) {
          var byte = 0;
          for (var bit = 0; bit < 8; bit++) {
            final x = bx * 8 + bit;
            if (x >= w) continue;
            final i = (y * width + x) * 4;
            final a = rgba[i + 3];
            final lum = (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
            if (a > 100 && lum < 150) byte |= 0x80 >> bit;
          }
          out.add(byte);
        }
      }
    }
    return out;
  }

  Future<String?> testPrint() async {
    final doc = await ReceiptBuilder.testPage(paper);
    return printPdf(build: (p, f) async => doc, name: 'test');
  }
}
