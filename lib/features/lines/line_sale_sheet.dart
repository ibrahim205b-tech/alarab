import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/lines_repo.dart';
import '../invoices/receipt_actions.dart';

/// نافذة إضافة خط مباع — كلها اختيارات (بدون كتابة)
Future<void> showLineSaleSheet(BuildContext context, {LineType? type, Service? service, LineSale? edit}) async {
  final r = await showAppSheet<(LineSale, Invoice)>(
      context, _LineSaleSheet(initialType: type, initialService: service, edit: edit),
      maxWidth: 720);
  if (r == null || !context.mounted) return;
  final (sale, inv) = r;
  await showInvoiceSuccess(context, inv, subtitle: '${sale.carrierName} • ${sale.lineTypeName} • ${sale.serviceName}');
}

class _LineSaleSheet extends StatefulWidget {
  final LineType? initialType;
  final Service? initialService;
  final LineSale? edit;
  const _LineSaleSheet({this.initialType, this.initialService, this.edit});
  @override
  State<_LineSaleSheet> createState() => _LineSaleSheetState();
}

class _LineSaleSheetState extends State<_LineSaleSheet> {
  List<LineType> _types = [];
  List<Service> _allServices = [];
  LineType? _type;
  Service? _service;
  int? _amount;
  final _phone = TextEditingController();
  bool _busy = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final types = await LinesRepo.lineTypes(activeOnly: true);
    final services = await LinesRepo.services(activeOnly: true);
    if (!mounted) return;
    setState(() {
      _types = types;
      _allServices = services;
      _loading = false;
      final e = widget.edit;
      if (e != null) {
        _type = types.where((t) => t.id == e.lineTypeId).firstOrNull;
        _service = services.where((s) => s.id == e.serviceId).firstOrNull;
        _amount = e.amount;
        _phone.text = e.customerPhone;
      } else {
        _type = widget.initialType == null ? null : types.where((t) => t.id == widget.initialType!.id).firstOrNull;
        _service = widget.initialService == null ? null : services.where((s) => s.id == widget.initialService!.id).firstOrNull;
        _amount = _service?.price;
      }
    });
  }

  List<Service> get _services => _type == null ? const [] : _allServices.where((s) => s.lineTypeId == _type!.id).toList();

  Future<void> _submit() async {
    if (_type == null || _service == null || (_amount ?? 0) <= 0) return;
    setState(() => _busy = true);
    try {
      if (widget.edit != null) {
        await LinesRepo.updateSale(widget.edit!, type: _type!, service: _service!, amount: _amount!, phone: _phone.text.trim());
        if (mounted) {
          Navigator.pop(context);
          toast(context, 'تم تعديل الخط #${widget.edit!.number}');
        }
        return;
      }
      final r = await LinesRepo.sell(type: _type!, service: _service!, amount: _amount!, customerPhone: _phone.text);
      if (mounted) Navigator.pop(context, r);
    } catch (e) {
      if (mounted) toast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _customAmount() async {
    final c = TextEditingController(text: _amount == null ? '' : numFmt(_amount!));
    final v = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('مبلغ آخر'),
        content: MoneyField(controller: c, label: 'المبلغ المستلم', autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, parseMoney(c.text)), child: const Text('اعتماد')),
        ],
      ),
    );
    if (v != null && v > 0) setState(() => _amount = v);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final ready = _type != null && _service != null && (_amount ?? 0) > 0;
    return SheetScaffold(
      title: widget.edit != null ? 'تعديل الخط #${widget.edit!.number}' : 'إضافة خط تم بيعه',
      icon: Icons.sim_card_rounded,
      footer: FilledButton.icon(
        onPressed: ready && !_busy ? _submit : null,
        icon: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
            : const Icon(Icons.check_circle_rounded),
        label: Text(ready ? '${widget.edit != null ? 'حفظ التعديل' : 'تأكيد البيع'} • ${money(_amount!)}' : 'اختر نوع الخط والخدمة'),
      ),
      child: _loading
          ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          : _types.isEmpty
              ? const EmptyState(icon: Icons.sim_card_alert_rounded, title: 'لا توجد أنواع خطوط', message: 'أضفها من الإدارة ← الخطوط والخدمات')
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _StepLabel(n: 1, text: 'نوع الخط', done: _type != null),
                  ChoiceGrid<LineType>(
                    items: _types,
                    selected: _type,
                    label: (t) => t.name,
                    sublabel: (t) => t.carrierName,
                    color: (t) => Color(t.color),
                    icon: (t) => Icons.sim_card_rounded,
                    onSelect: (t) => setState(() {
                      if (_type?.id != t.id) {
                        _type = t;
                        _service = null;
                        _amount = null;
                      }
                    }),
                  ),
                  const SizedBox(height: 18),
                  _StepLabel(n: 2, text: 'الخدمة المباعة', done: _service != null),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: _type == null
                        ? _Hint('اختر نوع الخط أولاً لتظهر خدماته')
                        : _services.isEmpty
                            ? _Hint('لا توجد خدمات لنوع "${_type!.name}" — أضفها من الإدارة')
                            : ChoiceGrid<Service>(
                                key: ValueKey(_type!.id),
                                items: _services,
                                selected: _service,
                                minTileWidth: 140,
                                label: (s) => s.name,
                                sublabel: (s) => money(s.price),
                                color: (s) => Color(_type!.color),
                                onSelect: (s) => setState(() {
                                  _service = s;
                                  _amount = s.price;
                                }),
                              ),
                  ),
                  const SizedBox(height: 18),
                  _StepLabel(n: 3, text: 'المبلغ المستلم', done: (_amount ?? 0) > 0),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: _service == null
                        ? _Hint('اختر الخدمة ليظهر سعرها')
                        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(colors: [
                                  Color(_type!.color).withValues(alpha: .22),
                                  Color(_type!.color).withValues(alpha: .06),
                                ]),
                                border: Border.all(color: Color(_type!.color).withValues(alpha: .4)),
                              ),
                              child: Row(children: [
                                Icon(Icons.payments_rounded, color: Color(_type!.color), size: 30),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                                    child: Text(money(_amount ?? 0),
                                        key: ValueKey(_amount),
                                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                                  ),
                                ),
                              ]),
                            ).animate().fadeIn().slideY(begin: .15, end: 0),
                            const SizedBox(height: 10),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final v in {_service!.price, _service!.price + 1000, _service!.price + 2000, _service!.price - 1000}
                                  .where((v) => v > 0))
                                ChoiceChip(
                                  label: Text(numFmt(v)),
                                  selected: _amount == v,
                                  onSelected: (_) => setState(() => _amount = v),
                                ),
                              ActionChip(
                                avatar: const Icon(Icons.edit_rounded, size: 18),
                                label: const Text('مبلغ آخر'),
                                onPressed: _customAmount,
                              ),
                            ]),
                          ]),
                  ),
                  const SizedBox(height: 14),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: _phone.text.isNotEmpty,
                      tilePadding: EdgeInsets.zero,
                      leading: Icon(Icons.phone_iphone_rounded, color: cs.onSurfaceVariant),
                      title: Text('رقم الخط / الزبون (اختياري)', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                      children: [
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(hintText: '07xx xxx xxxx', prefixIcon: Icon(Icons.dialpad_rounded)),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ]),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int n;
  final String text;
  final bool done;
  const _StepLabel({required this.n, required this.text, required this.done});
  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 28,
          height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done ? cs.primary : cs.surfaceContainerHighest),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check_rounded, size: 18, color: cs.onPrimary)
              : Text('$n', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _Hint extends StatelessWidget {
  final String text;
  const _Hint(this.text);
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.cs.outline, style: BorderStyle.solid),
          color: context.cs.surfaceContainerHigh.withValues(alpha: .4),
        ),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.cs.onSurfaceVariant)),
      );
}
