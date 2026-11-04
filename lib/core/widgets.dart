import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/session.dart';
import 'format.dart';
import 'theme.dart';

// =====================================================================
// مساعدات عامة
// =====================================================================

extension Ctx on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  double get w => MediaQuery.sizeOf(this).width;
  bool get isTablet => MediaQuery.sizeOf(this).shortestSide >= 600;
  bool get isWide => MediaQuery.sizeOf(this).width >= 900;
}

void toast(BuildContext context, String msg, {bool error = false, IconData? icon}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    duration: Duration(milliseconds: error ? 3500 : 2200),
    content: Row(children: [
      Icon(icon ?? (error ? Icons.error_outline_rounded : Icons.check_circle_rounded),
          color: error ? AppColors.danger : AppColors.success),
      const SizedBox(width: 10),
      Expanded(child: Text(msg)),
    ]),
  ));
}

String errText(Object e) => e.toString().replaceFirst('Exception: ', '');

/// تنفيذ عملية مع عرض الخطأ للمستخدم بشكل لطيف
Future<T?> guard<T>(BuildContext context, Future<T> Function() fn, {String? success}) async {
  try {
    final r = await fn();
    if (success != null && context.mounted) toast(context, success);
    return r;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), error: true);
    return null;
  }
}

Future<bool> confirm(BuildContext context, String title, String message,
    {String ok = 'تأكيد', bool danger = false, IconData icon = Icons.help_outline_rounded}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: Icon(danger ? Icons.warning_amber_rounded : icon,
          size: 40, color: danger ? AppColors.danger : c.cs.primary),
      title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// نافذة سفلية على الموبايل، ونافذة وسطية أنيقة على التابلت
Future<T?> showAppSheet<T>(BuildContext context, Widget child, {double maxWidth = 640}) {
  if (context.isTablet) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (c, a1, a2) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.sizeOf(c).height * .92),
            child: Material(
              color: c.cs.surfaceContainer,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: Padding(padding: const EdgeInsets.only(top: 12), child: child),
            ),
          ),
        ),
      ),
      transitionBuilder: (c, a, s, child) {
        final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(c).bottom),
      child: child,
    ),
  );
}

/// غلاف محتوى النوافذ: عنوان + محتوى قابل للتمرير + أزرار ثابتة بالأسفل
class SheetScaffold extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? footer;
  final List<Widget> actions;
  const SheetScaffold({super.key, required this.title, this.icon, required this.child, this.footer, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(children: [
          if (icon != null) ...[
            IconBadge(icon: icon!, color: context.cs.primary, size: 40),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          ...actions,
        ]),
      ),
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: child,
        ),
      ),
      if (footer != null)
        Container(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: context.cs.surfaceContainer,
            border: Border(top: BorderSide(color: context.cs.outline.withValues(alpha: .5))),
          ),
          child: footer,
        ),
    ]);
  }
}

// =====================================================================
// صلاحيات المدير
// =====================================================================

typedef AdminVerifier = Future<bool> Function(String pin);

class AdminGate {
  /// يُضبط من التطبيق (للتحقق من رمز المدير)
  static AdminVerifier? verifier;

  /// يتحقق أن المستخدم مدير، وإلا يطلب رمز المدير على نفس الجهاز
  static Future<bool> require(BuildContext context, {String reason = 'هذه العملية تحتاج صلاحية المدير'}) async {
    if (Session.instance.isAdmin) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => _AdminPinDialog(reason: reason),
    );
    return ok ?? false;
  }
}

class _AdminPinDialog extends StatefulWidget {
  final String reason;
  const _AdminPinDialog({required this.reason});
  @override
  State<_AdminPinDialog> createState() => _AdminPinDialogState();
}

class _AdminPinDialogState extends State<_AdminPinDialog> {
  final _key = GlobalKey<PinPadState>();
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const IconBadge(icon: Icons.admin_panel_settings_rounded, color: AppColors.gold, size: 56),
          const SizedBox(height: 12),
          const Text('تأكيد المدير', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(widget.reason, textAlign: TextAlign.center, style: TextStyle(color: context.cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          PinPad(
            key: _key,
            compact: true,
            onComplete: (pin) async {
              final ok = await (AdminGate.verifier?.call(pin) ?? Future.value(false));
              if (!context.mounted) return;
              if (ok) {
                Navigator.pop(context, true);
              } else {
                _key.currentState?.shakeError();
              }
            },
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء'))],
    );
  }
}

// =====================================================================
// لوحة إدخال الرمز السري
// =====================================================================

class PinPad extends StatefulWidget {
  final int length;
  final bool compact;
  final FutureOr<void> Function(String pin) onComplete;
  const PinPad({super.key, this.length = 4, this.compact = false, required this.onComplete});
  @override
  State<PinPad> createState() => PinPadState();
}

class PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _error = false;
  bool _busy = false;
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void shakeError() {
    HapticFeedback.heavyImpact();
    setState(() {
      _error = true;
      _pin = '';
    });
    _shake.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _error = false);
    });
  }

  void reset() => setState(() => _pin = '');

  Future<void> _tap(String d) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    if (d == '<') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= widget.length) return;
    setState(() => _pin += d);
    if (_pin.length == widget.length) {
      _busy = true;
      await Future.delayed(const Duration(milliseconds: 120));
      try {
        await widget.onComplete(_pin);
      } finally {
        _busy = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final size = widget.compact ? 62.0 : 74.0;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedBuilder(
        animation: _shake,
        builder: (c, child) {
          final t = _shake.value;
          final dx = t == 0 ? 0.0 : 14 * (1 - t) * ((t * 18).floor().isEven ? 1 : -1);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: List.generate(widget.length, (i) {
            final filled = i < _pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              margin: const EdgeInsets.symmetric(horizontal: 9),
              width: filled ? 20 : 16,
              height: filled ? 20 : 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _error ? AppColors.danger : (filled ? cs.primary : Colors.transparent),
                border: Border.all(color: _error ? AppColors.danger : cs.primary.withValues(alpha: .6), width: 2),
                boxShadow: filled && !_error
                    ? [BoxShadow(color: cs.primary.withValues(alpha: .45), blurRadius: 12)]
                    : null,
              ),
            );
          }),
        ),
      ),
      SizedBox(height: widget.compact ? 16 : 28),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'])
              SizedBox(
                width: size,
                height: size,
                child: d.isEmpty
                    ? null
                    : Pressable(
                        onTap: () => _tap(d),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: d == '<' ? Colors.transparent : cs.surfaceContainerHigh,
                            border: d == '<' ? null : Border.all(color: cs.outline.withValues(alpha: .6)),
                          ),
                          alignment: Alignment.center,
                          child: d == '<'
                              ? Icon(Icons.backspace_outlined, color: cs.onSurfaceVariant)
                              : Text(d, style: TextStyle(fontSize: widget.compact ? 24 : 28, fontWeight: FontWeight.w700)),
                        ),
                      ),
              ),
          ],
        ),
      ),
    ]);
  }
}

// =====================================================================
// عناصر واجهة
// =====================================================================

/// تأثير ضغط ناعم (تصغير بسيط) لأي عنصر
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  const Pressable({super.key, required this.child, this.onTap, this.onLongPress, this.scale = .96});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;
  final double radius;
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.color,
    this.gradient,
    this.borderColor,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final box = Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? cs.surfaceContainer) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? cs.outline.withValues(alpha: .55)),
        boxShadow: context.isDark
            ? null
            : [BoxShadow(color: Colors.black.withValues(alpha: .04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    if (onTap == null && onLongPress == null) return box;
    return Pressable(scale: .98, child: box);
  }
}

class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .32),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [color.withValues(alpha: .28), color.withValues(alpha: .12)],
        ),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * .52),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  final bool solid;
  const Pill(this.text, {super.key, required this.color, this.icon, this.solid = false});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
        border: solid ? null : Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: solid ? Colors.white : color),
          const SizedBox(width: 4),
        ],
        Text(text,
            style: TextStyle(
                color: solid ? Colors.white : color, fontSize: 12, fontWeight: FontWeight.w800, height: 1.2)),
      ]),
    );
  }
}

/// رقم يعدّ تصاعدياً بحركة ناعمة
class CountUp extends StatelessWidget {
  final int value;
  final TextStyle? style;
  final bool asMoney;
  final String suffix;
  const CountUp(this.value, {super.key, this.style, this.asMoney = true, this.suffix = ''});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutExpo,
      builder: (c, v, _) => Text(
        asMoney ? money(v) : '${numFmt(v)}$suffix',
        style: style,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(color: context.cs.primary, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 13)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                context.cs.primary.withValues(alpha: .22),
                context.cs.primary.withValues(alpha: .04),
              ]),
            ),
            child: Icon(icon, size: 44, color: context.cs.primary),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.06, duration: 1600.ms, curve: Curves.easeInOut),
          const SizedBox(height: 18),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(message!, textAlign: TextAlign.center, style: TextStyle(color: context.cs.onSurfaceVariant)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: .08, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

class SearchField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final Widget? trailing;
  final bool autofocus;
  const SearchField({super.key, this.hint = 'بحث...', required this.onChanged, this.trailing, this.autofocus = false});
  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final _c = TextEditingController();
  Timer? _debounce;
  @override
  void dispose() {
    _debounce?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      autofocus: widget.autofocus,
      textInputAction: TextInputAction.search,
      onChanged: (v) {
        setState(() {});
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 220), () => widget.onChanged(v));
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _c.text.isEmpty
            ? widget.trailing
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  _c.clear();
                  setState(() {});
                  widget.onChanged('');
                },
              ),
      ),
    );
  }
}

/// حقل مبلغ بالدينار مع فواصل آلاف تلقائية
class MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<int>? onChanged;
  final bool autofocus;
  final String? Function(int v)? validator;
  final List<int> quick;
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.autofocus = false,
    this.validator,
    this.quick = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextFormField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsFormatter()],
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: label,
          suffixText: 'د.ع',
          prefixIcon: const Icon(Icons.payments_outlined),
        ),
        validator: validator == null ? null : (v) => validator!(parseMoney(v ?? '')),
        onChanged: (v) => onChanged?.call(parseMoney(v)),
      ),
      if (quick.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final q in quick)
            ActionChip(
              label: Text(numFmt(q)),
              onPressed: () {
                controller.text = numFmt(q);
                onChanged?.call(q);
              },
            ),
        ]),
      ],
    ]);
  }
}

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final n = parseMoney(newValue.text);
    if (newValue.text.trim().isEmpty) return newValue.copyWith(text: '');
    final t = numFmt(n);
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

/// شبكة اختيار بالبطاقات (اختيار فقط بدون كتابة)
class ChoiceGrid<T> extends StatelessWidget {
  final List<T> items;
  final T? selected;
  final String Function(T) label;
  final String Function(T)? sublabel;
  final Color Function(T)? color;
  final IconData Function(T)? icon;
  final ValueChanged<T> onSelect;
  final double minTileWidth;
  const ChoiceGrid({
    super.key,
    required this.items,
    required this.selected,
    required this.label,
    required this.onSelect,
    this.sublabel,
    this.color,
    this.icon,
    this.minTileWidth = 120,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, cons) {
      final cols = (cons.maxWidth / minTileWidth).floor().clamp(2, 6);
      final tileW = (cons.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < items.length; i++)
            SizedBox(
              width: tileW,
              child: _ChoiceTile(
                label: label(items[i]),
                sublabel: sublabel?.call(items[i]),
                color: color?.call(items[i]) ?? context.cs.primary,
                icon: icon?.call(items[i]),
                selected: items[i] == selected,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(items[i]);
                },
              ).animate().fadeIn(delay: (30 * i).ms, duration: 250.ms).scaleXY(begin: .92, end: 1, curve: Curves.easeOutBack),
            ),
        ],
      );
    });
  }
}

class _ChoiceTile extends StatelessWidget {
  final String label;
  final String? sublabel;
  final Color color;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceTile({required this.label, this.sublabel, required this.color, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected ? color.withValues(alpha: .18) : cs.surfaceContainerHigh.withValues(alpha: .7),
          border: Border.all(color: selected ? color : cs.outline.withValues(alpha: .6), width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6))] : null,
        ),
        child: Row(children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: selected ? color : cs.onSurface)),
              if (sublabel != null)
                Text(sublabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
            ]),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: selected
                ? Icon(Icons.check_circle_rounded, key: const ValueKey(1), color: color, size: 22)
                : const SizedBox(key: ValueKey(0), width: 22),
          ),
        ]),
      ),
    );
  }
}

/// يعرض بيانات من قاعدة البيانات ويعيد تحميلها تلقائياً عند أي تغيير
class DataView<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final Object? reloadKey;
  const DataView({super.key, required this.load, required this.builder, this.reloadKey});
  @override
  State<DataView<T>> createState() => _DataViewState<T>();
}

class _DataViewState<T> extends State<DataView<T>> {
  T? _data;
  Object? _error;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    DataBus.instance.addListener(_reload);
    _reload();
  }

  @override
  void didUpdateWidget(covariant DataView<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _reload();
  }

  @override
  void dispose() {
    DataBus.instance.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    final t = ++_token;
    try {
      final d = await widget.load();
      if (mounted && t == _token) setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (mounted && t == _token) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null && _data == null) {
      return EmptyState(icon: Icons.error_outline_rounded, title: 'حدث خطأ', message: errText(_error!));
    }
    final d = _data;
    if (d == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }
    return widget.builder(context, d);
  }
}

/// ظهور متتابع لعناصر القوائم
extension StaggerX on Widget {
  Widget stagger(int index, {int step = 35, int max = 12}) => animate()
      .fadeIn(delay: (step * (index < max ? index : max)).ms, duration: 320.ms)
      .slideY(begin: .12, end: 0, curve: Curves.easeOutCubic, duration: 380.ms);
}

/// أيقونات الأقسام
IconData categoryIcon(String key) => switch (key) {
      'phone' => Icons.smartphone_rounded,
      'headphones' => Icons.headphones_rounded,
      'charger' => Icons.cable_rounded,
      'shield' => Icons.shield_rounded,
      'case' => Icons.phone_iphone_rounded,
      'chip' => Icons.memory_rounded,
      'card' => Icons.sim_card_rounded,
      'watch' => Icons.watch_rounded,
      'speaker' => Icons.speaker_rounded,
      'tablet' => Icons.tablet_android_rounded,
      _ => Icons.inventory_2_rounded,
    };

const categoryIconKeys = ['phone', 'headphones', 'charger', 'shield', 'case', 'chip', 'card', 'watch', 'speaker', 'tablet', 'box'];

const palette = [
  0xFF3E8BFF, 0xFF8B5CF6, 0xFF14B8A6, 0xFFD9B25F, 0xFFEC4899, 0xFFF5A524,
  0xFFE5202E, 0xFF2FBF71, 0xFF7B2D8E, 0xFF0EA5E9, 0xFF64748B, 0xFFF97316,
];

class ColorPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const ColorPicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final c in palette)
        Pressable(
          onTap: () => onChanged(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(color: value == c ? context.cs.onSurface : Colors.transparent, width: 3),
            ),
            child: value == c ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
          ),
        ),
    ]);
  }
}

/// صف معلومات (عنوان: قيمة)
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool bold;
  final Color? color;
  const InfoRow(this.label, this.value, {super.key, this.icon, this.bold = false, this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: context.cs.onSurfaceVariant),
          const SizedBox(width: 8),
        ],
        Text(label, style: TextStyle(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700, color: color, fontSize: bold ? 16 : 14)),
        ),
      ]),
    );
  }
}
