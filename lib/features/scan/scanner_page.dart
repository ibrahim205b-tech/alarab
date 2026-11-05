import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// فتح الكاميرا لقراءة باركود أو IMEI. يعيد النص المقروء أو null.
Future<String?> scanCode(BuildContext context, {String title = 'امسح الباركود'}) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => _ScannerPage(title: title)));

/// زر كاميرا صغير يوضع داخل حقول الإدخال
class ScanButton extends StatelessWidget {
  final ValueChanged<String> onCode;
  final String title;
  const ScanButton({super.key, required this.onCode, this.title = 'امسح الباركود'});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'مسح بالكاميرا',
        icon: const Icon(Icons.qr_code_scanner_rounded),
        onPressed: () async {
          final code = await scanCode(context, title: title);
          if (code != null && code.isNotEmpty) onCode(code);
        },
      );
}

class _ScannerPage extends StatefulWidget {
  final String title;
  const _ScannerPage({required this.title});
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    final code = capture.barcodes.map((b) => b.rawValue ?? '').firstWhere((v) => v.trim().isNotEmpty, orElse: () => '');
    if (code.isEmpty) return;
    _done = true;
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final box = (size.shortestSide * .72).clamp(220.0, 420.0);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'الفلاش',
            icon: Icon(_torch ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
          IconButton(
            tooltip: 'تبديل الكاميرا',
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (c, e) => EmptyState(
              icon: Icons.no_photography_rounded,
              title: 'تعذر فتح الكاميرا',
              message: 'اسمح للبرنامج باستخدام الكاميرا من إعدادات الجهاز',
            ),
          ),
        ),
        Center(
          child: Container(
            width: box,
            height: box * .62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black54, spreadRadius: 2000)],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Text(
            'وجّه الكاميرا نحو الباركود أو رقم IMEI على علبة الجهاز',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
    );
  }
}
