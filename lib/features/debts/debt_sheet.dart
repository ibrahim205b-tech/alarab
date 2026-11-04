import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/debts_repo.dart';

/// نافذة إضافة دين / طلب (متاحة للجميع من الزر العلوي)
/// عند تمرير [edit] تعمل كنافذة تعديل (للمدير فقط)
Future<void> showDebtSheet(BuildContext context, {Debt? edit}) =>
    showAppSheet(context, _DebtSheet(edit: edit), maxWidth: 560);

class _DebtSheet extends StatefulWidget {
  final Debt? edit;
  const _DebtSheet({this.edit});
  @override
  State<_DebtSheet> createState() => _DebtSheetState();
}

class _DebtSheetState extends State<_DebtSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.edit?.customerName);
  late final _phone = TextEditingController(text: widget.edit?.customerPhone);
  late final _amount = TextEditingController(text: widget.edit == null ? '' : numFmt(widget.edit!.amount));
  late final _note = TextEditingController(text: widget.edit?.note);
  late String _type = widget.edit?.debtType ?? debtTypes.first;
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await guard(context, () async {
      if (widget.edit != null) {
        await DebtsRepo.update(widget.edit!,
            name: _name.text.trim(), phone: _phone.text.trim(), type: _type, amount: parseMoney(_amount.text), note: _note.text.trim());
      } else {
        await DebtsRepo.add(
            name: _name.text, phone: _phone.text, type: _type, amount: parseMoney(_amount.text), note: _note.text);
      }
      return true;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok == true) {
      Navigator.pop(context);
      toast(context, widget.edit != null ? 'تم تعديل الدين' : 'تم تسجيل الدين — لا يُعدّل إلا من المدير');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.edit != null ? 'تعديل الدين' : 'إضافة دين / طلب',
      icon: Icons.menu_book_rounded,
      footer: FilledButton.icon(
        onPressed: _busy ? null : _save,
        icon: const Icon(Icons.save_rounded),
        label: Text(widget.edit != null ? 'حفظ التعديل' : 'تسجيل الدين'),
      ),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _name,
            autofocus: widget.edit == null,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'اسم الشخص', prefixIcon: Icon(Icons.person_rounded)),
            validator: (v) => (v ?? '').trim().isEmpty ? 'الاسم مطلوب' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_rounded)),
          ),
          const SizedBox(height: 16),
          const Text('نوع الدين', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in debtTypes)
              ChoiceChip(label: Text(t), selected: _type == t, onSelected: (_) => setState(() => _type = t)),
          ]),
          const SizedBox(height: 16),
          MoneyField(
            controller: _amount,
            label: 'المبلغ المطلوب من الزبون',
            validator: (v) => v <= 0 ? 'أدخل المبلغ' : null,
            quick: const [5000, 10000, 25000, 50000, 100000],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', prefixIcon: Icon(Icons.notes_rounded)),
          ),
          if (widget.edit == null) ...[
            const SizedBox(height: 12),
            Row(children: [
              Icon(Icons.lock_rounded, size: 16, color: context.cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text('بعد التسجيل لا يمكن تعديل الدين أو حذفه إلا من المدير',
                    style: TextStyle(fontSize: 12.5, color: context.cs.onSurfaceVariant)),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}
