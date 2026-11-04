import 'package:flutter/material.dart';

import 'format.dart';
import 'widgets.dart';

/// رسم أعمدة لسلسلة واحدة (مبيعات يومية) — لون واحد، أعمدة رفيعة بحواف علوية مدورة،
/// خطوط شبكة خافتة، والضغط على أي عمود يعرض قيمته.
class DailyBars extends StatefulWidget {
  final List<(DateTime, int)> data;
  final double height;
  const DailyBars({super.key, required this.data, this.height = 190});
  @override
  State<DailyBars> createState() => _DailyBarsState();
}

class _DailyBarsState extends State<DailyBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..forward();
  int? _sel;

  @override
  void didUpdateWidget(covariant DailyBars old) {
    super.didUpdateWidget(old);
    if (old.data.length != widget.data.length) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final data = widget.data;
    final maxV = data.fold<int>(0, (m, e) => e.$2 > m ? e.$2 : m);
    final sel = _sel ?? (data.isEmpty ? null : data.length - 1);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 48,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: sel == null
              ? const SizedBox()
              : Column(
                  key: ValueKey(sel),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(money(data[sel].$2), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text('${weekday(data[sel].$1)} ${dateStr(data[sel].$1)}',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: widget.height,
        child: LayoutBuilder(builder: (c, cons) {
          final n = data.length;
          final slot = n == 0 ? 0.0 : cons.maxWidth / n;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              if (n == 0) return;
              // الاتجاه من اليمين لليسار: أول يوم في اليمين
              final fromRight = cons.maxWidth - d.localPosition.dx;
              setState(() => _sel = (fromRight / slot).floor().clamp(0, n - 1));
            },
            child: AnimatedBuilder(
              animation: _c,
              builder: (c, _) => CustomPaint(
                size: Size(cons.maxWidth, widget.height),
                painter: _BarsPainter(
                  values: data.map((e) => e.$2).toList(),
                  maxV: maxV,
                  t: Curves.easeOutCubic.transform(_c.value),
                  bar: cs.primary,
                  barMuted: cs.primary.withValues(alpha: .45),
                  grid: cs.outline.withValues(alpha: .45),
                  selected: sel,
                ),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < data.length; i++)
          Expanded(
            child: Text(
              data.length > 10 ? (i % 5 == 0 ? '${data[i].$1.day}/${data[i].$1.month}' : '') : '${data[i].$1.day}/${data[i].$1.month}',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                color: i == sel ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: i == sel ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
      ]),
    ]);
  }
}

class _BarsPainter extends CustomPainter {
  final List<int> values;
  final int maxV;
  final double t;
  final Color bar, barMuted, grid;
  final int? selected;
  _BarsPainter({required this.values, required this.maxV, required this.t, required this.bar, required this.barMuted, required this.grid, this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    final gp = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gp);
    }
    if (values.isEmpty || maxV == 0) return;
    final n = values.length;
    final slot = size.width / n;
    final w = (slot * .5).clamp(4.0, 28.0);
    for (var i = 0; i < n; i++) {
      // RTL: العنصر الأول في اليمين
      final cx = size.width - (i + .5) * slot;
      final h = (values[i] / maxV) * (size.height - 4) * t;
      if (h <= 0) continue;
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - w / 2, size.height - h, w, h),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(r, Paint()..color = i == selected ? bar : barMuted);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter o) => o.t != t || o.selected != selected || o.values != values;
}

/// شريط نسبة أفقي (للتقارير: توزيع حسب الأقسام)
class ShareBar extends StatelessWidget {
  final String label;
  final int value, max;
  final Color color;
  final String trailing;
  const ShareBar({super.key, required this.label, required this.value, required this.max, required this.color, required this.trailing});
  @override
  Widget build(BuildContext context) {
    final frac = max == 0 ? 0.0 : value / max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
          Text(trailing, style: TextStyle(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: frac),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (c, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: color,
              backgroundColor: context.cs.surfaceContainerHighest,
            ),
          ),
        ),
      ]),
    );
  }
}
