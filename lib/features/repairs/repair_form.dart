import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/repairs_repo.dart';
import '../invoices/receipt_actions.dart';
import '../scan/scanner_page.dart';

const _brands = ['Apple', 'Samsung', 'Xiaomi', 'Redmi', 'Oppo', 'Realme', 'Huawei', 'Honor', 'Infinix', 'Tecno', 'Vivo', 'Nokia'];
const _issues = ['تبديل شاشة', 'تبديل بطارية', 'منفذ الشحن', 'لا يشتغل', 'سقط بالماء', 'سوفتوير / تفليش', 'مشكلة شبكة', 'الكاميرا', 'السماعة / المايك', 'زر الباور / الصوت', 'تبديل ظهر', 'فك قفل / حساب'];
const _accessories = ['بدون ملحقات', 'شاحن', 'كفر', 'شريحة', 'ذاكرة', 'القلم', 'الكارتونة'];

/// استلام جهاز جديد للصيانة (أو تعديل — للمدير)
Future<void> showRepairForm(BuildContext context, {Repair? edit}) async {
  final r = await showAppSheet<Repair>(context, _RepairForm(edit: edit), maxWidth: 760);
  if (r == null || !context.mounted) return;
  await showSuccess(
    context,
    title: 'تم استلام الجهاز',
    code: r.code,
    amount: r.estimatedCost,
    build: repairPdf(r),
    subtitle: '${r.device} • ${r.customerName}\nاطبع وصل الاستلام وسلّمه للزبون',
  );
}

class _RepairForm extends StatefulWidget {
  final Repair? edit;
  const _RepairForm({this.edit});
  @override
  State<_RepairForm> createState() => _RepairFormState();
}

class _RepairFormState extends State<_RepairForm> {
  final _form = GlobalKey<FormState>();
  late final Repair? e = widget.edit;
  late final _name = TextEditingController(text: e?.customerName);
  late final _phone = TextEditingController(text: e?.customerPhone);
  late final _brand = TextEditingController(text: e?.deviceBrand);
  late final _model = TextEditingController(text: e?.deviceModel);
  late final _imei = TextEditingController(text: e?.imei);
  late final _issue = TextEditingController(text: e?.issue);
  late final _password = TextEditingController(text: e?.devicePassword);
  late final _condition = TextEditingController(text: e?.conditionNotes);
  late final _estimate = TextEditingController(text: e == null || e!.estimatedCost == 0 ? '' : numFmt(e!.estimatedCost));
  late final _deposit = TextEditingController(text: e == null || e!.deposit == 0 ? '' : numFmt(e!.deposit));
  late final Set<String> _acc = {...?e?.accessories.split('، ').where((x) => x.isNotEmpty)};
  late DateTime? _expected = e?.expectedAt == null ? null : DateTime.fromMillisecondsSinceEpoch(e!.expectedAt!);
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final r = Repair(
      id: e?.id ?? 0,
      number: e?.number ?? 0,
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      deviceBrand: _brand.text.trim(),
      deviceModel: _model.text.trim(),
      imei: _imei.text.trim(),
      issue: _issue.text.trim(),
      devicePassword: _password.text.trim(),
      accessories: _acc.join('، '),
      conditionNotes: _condition.text.trim(),
      estimatedCost: parseMoney(_estimate.text),
      deposit: parseMoney(_deposit.text),
      expectedAt: _expected?.millisecondsSinceEpoch,
      receivedAt: e?.receivedAt ?? 0,
    );
    final res = await guard(context, () async {
      if (e != null) {
        await RepairsRepo.update(r);
        return r;
      }
      return RepairsRepo.create(r);
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (res != null) {
      if (e != null) {
        Navigator.pop(context);
        toast(context, 'تم حفظ التعديلات');
      } else {
        Navigator.pop(context, res);
      }
    }
  }

  void _appendIssue(String s) {
    final t = _issue.text.trim();
    if (t.contains(s)) return;
    _issue.text = t.isEmpty ? s : '$t، $s';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return SheetScaffold(
      title: e == null ? 'استلام جهاز صيانة' : 'تعديل ${e!.code}',
      icon: Icons.build_circle_rounded,
      footer: FilledButton.icon(
        onPressed: _busy ? null : _save,
        icon: const Icon(Icons.save_rounded),
        label: Text(e == null ? 'استلام الجهاز' : 'حفظ التعديلات'),
      ),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('الزبون'),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'اسم الزبون *', prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_rounded)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const SectionTitle('الجهاز'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final b in _brands)
              ChoiceChip(
                label: Text(b),
                selected: _brand.text == b,
                onSelected: (_) => setState(() => _brand.text = b),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(controller: _brand, decoration: const InputDecoration(labelText: 'الشركة', prefixIcon: Icon(Icons.business_rounded))),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _model,
                decoration: const InputDecoration(labelText: 'الموديل *', prefixIcon: Icon(Icons.smartphone_rounded)),
                validator: (v) => (v ?? '').trim().isEmpty ? 'مطلوب' : null,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _imei,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'IMEI',
                  prefixIcon: const Icon(Icons.qr_code_2_rounded),
                  suffixIcon: ScanButton(title: 'امسح IMEI', onCode: (v) => setState(() => _imei.text = v)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'رمز / نمط القفل', prefixIcon: Icon(Icons.pattern_rounded)),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          const SectionTitle('العطل'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final s in _issues) ActionChip(label: Text(s), onPressed: () => _appendIssue(s)),
          ]),
          const SizedBox(height: 10),
          TextFormField(
            controller: _issue,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'وصف العطل *', prefixIcon: Icon(Icons.report_problem_rounded)),
            validator: (v) => (v ?? '').trim().isEmpty ? 'اكتب أو اختر العطل' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _condition,
            decoration: const InputDecoration(labelText: 'حالة الجهاز عند الاستلام (خدوش، كسر...)', prefixIcon: Icon(Icons.visibility_rounded)),
          ),
          const SizedBox(height: 12),
          Text('الملحقات المستلمة', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in _accessories)
              FilterChip(
                label: Text(a),
                selected: _acc.contains(a),
                onSelected: (v) => setState(() {
                  if (a == _accessories.first) {
                    _acc
                      ..clear()
                      ..addAll(v ? [a] : []);
                  } else {
                    _acc.remove(_accessories.first);
                    v ? _acc.add(a) : _acc.remove(a);
                  }
                }),
              ),
          ]),
          const SizedBox(height: 16),
          const SectionTitle('الكلفة'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: MoneyField(controller: _estimate, label: 'الكلفة التقديرية')),
            const SizedBox(width: 10),
            Expanded(child: MoneyField(controller: _deposit, label: 'العربون المستلم')),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                initialDate: _expected ?? DateTime.now().add(const Duration(days: 1)),
              );
              if (d != null) setState(() => _expected = d);
            },
            icon: const Icon(Icons.event_rounded),
            label: Text(_expected == null ? 'موعد التسليم المتوقع (اختياري)' : 'موعد التسليم: ${longDate(_expected!)}'),
          ),
        ]),
      ),
    );
  }
}
