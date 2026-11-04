import 'dart:io';
import 'dart:typed_data';

import 'package:alarab/data/db.dart';
import 'package:alarab/data/models.dart';
import 'package:alarab/data/repos/settings_repo.dart';
import 'package:alarab/services/printer.dart';
import 'package:alarab/services/receipt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await AppDb.instance.open(path: inMemoryDatabasePath);
    await SettingsRepo.instance.load();
  });

  test('invoice and repair receipts build for 58/80mm and A5', () async {
    final inv = Invoice(
      id: 1,
      type: InvoiceType.sale,
      number: 12,
      customerName: 'حسين علي',
      subtotal: 805000,
      discount: 5000,
      total: 800000,
      paid: 300000,
      payment: 'credit',
      userName: 'علي',
      createdAt: DateTime(2026, 11, 4, 16, 30).millisecondsSinceEpoch,
      items: const [
        InvoiceItem(name: 'iPhone 13 128GB', detail: 'IMEI: 356789104455661', price: 790000),
        InvoiceItem(name: 'لاصقة حماية 9D', qty: 3, price: 5000),
      ],
    );
    for (final paper in [58, 80]) {
      final bytes = await ReceiptBuilder.invoice(inv, paper: paper);
      expect(bytes.length, greaterThan(1000));
      if (Platform.environment['SCREENSHOTS'] == '1') File('test/goldens/receipt_$paper.pdf').writeAsBytesSync(bytes);
    }
    expect((await ReceiptBuilder.invoice(inv, format: PdfPageFormat.a5)).length, greaterThan(1000));
    final r = Repair(id: 1, number: 7, customerName: 'زهراء', deviceModel: 'Galaxy A32', issue: 'منفذ الشحن', receivedAt: DateTime.now().millisecondsSinceEpoch, deposit: 5000);
    expect((await ReceiptBuilder.repairIntake(r)).length, greaterThan(1000));
    expect((await ReceiptBuilder.testPage(58)).length, greaterThan(500));
  });

  test('ESC/POS raster encodes black pixels', () {
    // صورة 16x2: البكسل الأول أسود والباقي أبيض
    final px = List<int>.filled(16 * 2 * 4, 255);
    px[0] = px[1] = px[2] = 0;
    final out = PrinterService.rasterToEscPos(Uint8List.fromList(px), 16, 2, 384);
    expect(out.sublist(0, 8), [0x1D, 0x76, 0x30, 0x00, 2, 0, 2, 0]);
    expect(out[8], 0x80);
    expect(out.length, 8 + 2 * 2);
  });
}
