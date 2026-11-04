import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'theme.dart';
import 'widgets.dart';

/// شعار البرنامج
class BrandMark extends StatelessWidget {
  final double size;
  final bool animate;
  const BrandMark({super.key, this.size = 84, this.animate = true});

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .3),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFF4DB97), AppColors.gold, Color(0xFF9C7526)],
        ),
        boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: .45), blurRadius: size * .4, offset: Offset(0, size * .12))],
      ),
      alignment: Alignment.center,
      child: Stack(alignment: Alignment.center, children: [
        Icon(Icons.storefront_rounded, size: size * .5, color: AppColors.ink),
        Positioned(
          top: size * .1,
          child: Icon(Icons.workspace_premium_rounded, size: size * .22, color: AppColors.ink.withValues(alpha: .85)),
        ),
      ]),
    );
    if (!animate) return mark;
    return mark
        .animate()
        .scaleXY(begin: .6, end: 1, duration: 700.ms, curve: Curves.easeOutBack)
        .fadeIn(duration: 400.ms)
        .then()
        .shimmer(duration: 1600.ms, color: Colors.white.withValues(alpha: .5));
  }
}

class BrandTitle extends StatelessWidget {
  final double size;
  const BrandTitle({super.key, this.size = 30});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      ShaderMask(
        shaderCallback: (r) => const LinearGradient(colors: [Color(0xFFF4DB97), AppColors.gold, Color(0xFFB08A3A)]).createShader(r),
        child: Text('مبيعات علي العراب',
            style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
      ),
      const SizedBox(height: 4),
      Text('هواتف • صيانة • إكسسوارات • خطوط',
          style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: size * .45, fontWeight: FontWeight.w600)),
    ]);
  }
}

/// خلفية متحركة ناعمة بتدرجات ذهبية
class AmbientBackground extends StatefulWidget {
  final Widget child;
  const AmbientBackground({super.key, required this.child});
  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor)),
      Positioned.fill(
        child: AnimatedBuilder(
          animation: _c,
          builder: (c, _) {
            final t = _c.value * 2 * math.pi;
            return CustomPaint(painter: _BlobPainter(t, cs.primary, AppColors.teal, context.isDark));
          },
        ),
      ),
      Positioned.fill(child: widget.child),
    ]);
  }
}

class _BlobPainter extends CustomPainter {
  final double t;
  final Color a, b;
  final bool dark;
  _BlobPainter(this.t, this.a, this.b, this.dark);

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset c, double r, Color color) {
      final p = Paint()
        ..shader = RadialGradient(colors: [color.withValues(alpha: dark ? .22 : .18), color.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, p);
    }

    final w = size.width, h = size.height;
    blob(Offset(w * (.8 + .08 * math.sin(t)), h * (.15 + .05 * math.cos(t))), w * .6, a);
    blob(Offset(w * (.15 + .06 * math.cos(t * .8)), h * (.85 + .05 * math.sin(t))), w * .55, b);
    blob(Offset(w * (.5 + .1 * math.sin(t * .6)), h * .5), w * .35, a);
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.t != t || old.dark != dark;
}
