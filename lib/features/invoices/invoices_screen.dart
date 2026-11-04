import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/sales_repo.dart';
import '../../services/session.dart';
import 'receipt_actions.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  InvoiceType? _type;
  String _q = '';
  DateTimeRange? _range;

  @override
  Widget build(BuildContext context) {
    return DataView<List<Invoice>>(
      reloadKey: '$_type-$_q-$_range',
      load: () => SalesRepo.list(
        type: _type,
        query: _q,
        from: _range?.start,
        to: _range?.end.add(const Duration(days: 1)),
      ),
      builder: (context, list) {
        final total = list.where((i) => !i.isVoid && i.type != InvoiceType.debtPay).fold<int>(0, (s, i) => s + i.total);
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: SearchField(hint: 'رقم الفاتورة، الزبون، المادة...', onChanged: (v) => setState(() => _q = v))),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                    tooltip: 'الفترة',
                    onPressed: () async {
                      final r = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                        initialDateRange: _range,
                      );
                      setState(() => _range = r);
                    },
                    icon: Icon(_range == null ? Icons.date_range_rounded : Icons.event_available_rounded),
                  ),
                ]),
                if (_range != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InputChip(
                      label: Text('${dateStr(_range!.start)} ← ${dateStr(_range!.end)}'),
                      onDeleted: () => setState(() => _range = null),
                    ),
                  ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ChoiceChip(label: const Text('الكل'), selected: _type == null, onSelected: (_) => setState(() => _type = null)),
                    for (final t in InvoiceType.values) ...[
                      const SizedBox(width: 8),
                      ChoiceChip(
                        avatar: Icon(t.icon, size: 18, color: t.color),
                        label: Text(t.label),
                        selected: _type == t,
                        selectedColor: t.color.withValues(alpha: .22),
                        onSelected: (_) => setState(() => _type = t),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 10),
                Text('${list.length} فاتورة • مجموع المبيعات ${money(total)}',
                    style: TextStyle(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          if (list.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.receipt_long_outlined, title: 'لا توجد فواتير'))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (c, i) => InvoiceTile(invoice: list[i]).stagger(i),
              ),
            ),
        ]);
      },
    );
  }
}

class InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  const InvoiceTile({super.key, required this.invoice});
  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    return Opacity(
      opacity: inv.isVoid ? .55 : 1,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => showInvoiceDetails(context, inv.id),
        child: Row(children: [
          IconBadge(icon: inv.type.icon, color: inv.type.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(inv.code, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Flexible(child: Text(inv.type.label, overflow: TextOverflow.ellipsis, style: TextStyle(color: inv.type.color, fontSize: 12, fontWeight: FontWeight.w700))),
                if (inv.isVoid) ...[const SizedBox(width: 6), const Pill('ملغاة', color: AppColors.danger)],
                if (inv.payment == 'credit') ...[const SizedBox(width: 6), const Pill('آجل', color: Color(0xFFEC4899))],
              ]),
              Text(
                [if (inv.customerName.isNotEmpty) inv.customerName, dateTimeMs(inv.createdAt), inv.userName].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant),
              ),
            ]),
          ),
          Text(money(inv.total),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: context.cs.primary,
                decoration: inv.isVoid ? TextDecoration.lineThrough : null,
              )),
        ]),
      ),
    );
  }
}

Future<void> showInvoiceDetails(BuildContext context, int id) => showAppSheet(context, _InvoiceDetails(id: id));

class _InvoiceDetails extends StatelessWidget {
  final int id;
  const _InvoiceDetails({required this.id});
  @override
  Widget build(BuildContext context) {
    return DataView<Invoice?>(
      load: () => SalesRepo.get(id),
      builder: (context, inv) {
        if (inv == null) return const EmptyState(icon: Icons.delete_outline, title: 'الفاتورة غير موجودة');
        final admin = Session.instance.isAdmin;
        return SheetScaffold(
          title: '${inv.type.label} ${inv.code}',
          icon: inv.type.icon,
          footer: ReceiptButtons(doc: invoicePdf(inv), name: inv.code),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (inv.isVoid)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
                child: Text('فاتورة ملغاة${inv.note.isNotEmpty ? ' — ${inv.note}' : ''}',
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
              ),
            for (final it in inv.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      if (it.detail.isNotEmpty) Text(it.detail, style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
                      Text('${it.qty} × ${money(it.price)}', style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
                    ]),
                  ),
                  Text(money(it.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
            const Divider(height: 24),
            if (inv.discount > 0) ...[
              InfoRow('المجموع', money(inv.subtotal)),
              InfoRow('الخصم', money(inv.discount)),
            ],
            InfoRow('الإجمالي', money(inv.total), bold: true, color: context.cs.primary),
            if (inv.payment == 'credit') ...[
              InfoRow('المدفوع', money(inv.paid)),
              InfoRow('المتبقي (دين)', money(inv.remaining), color: const Color(0xFFEC4899)),
            ],
            if (admin && inv.cost > 0) InfoRow('الربح', money(inv.profit), color: AppColors.success),
            if (inv.customerName.isNotEmpty) InfoRow('الزبون', inv.customerName, icon: Icons.person_rounded),
            if (inv.customerPhone.isNotEmpty) InfoRow('الهاتف', inv.customerPhone, icon: Icons.phone_rounded),
            InfoRow('التاريخ', dateTimeMs(inv.createdAt), icon: Icons.schedule_rounded),
            InfoRow('الموظف', inv.userName, icon: Icons.badge_rounded),
            if (!inv.isVoid && inv.note.isNotEmpty) InfoRow('ملاحظة', inv.note, icon: Icons.notes_rounded),
            if (!inv.isVoid) ...[
              const SizedBox(height: 16),
              Row(children: [
                if (inv.type == InvoiceType.sale)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _edit(context, inv),
                      icon: Icon(admin ? Icons.edit_rounded : Icons.lock_rounded),
                      label: const Text('تعديل'),
                    ),
                  ),
                if (inv.type == InvoiceType.sale) const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => _void(context, inv),
                    icon: Icon(admin ? Icons.block_rounded : Icons.lock_rounded),
                    label: const Text('إلغاء الفاتورة'),
                  ),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }

  Future<void> _void(BuildContext context, Invoice inv) async {
    if (!await AdminGate.require(context, reason: 'إلغاء/حذف المبيعات للمدير فقط')) return;
    if (!context.mounted) return;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 40),
        title: Text('إلغاء ${inv.code}؟'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(inv.type == InvoiceType.sale ? 'ستُرجع المواد إلى المخزن ويُخصم المبلغ من المبيعات' : 'سيُخصم المبلغ من المبيعات'),
          const SizedBox(height: 12),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'سبب الإلغاء')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('تراجع')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('إلغاء الفاتورة'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await guard(context, () => SalesRepo.voidInvoice(inv, reason.text.trim().isEmpty ? 'إلغاء من المدير' : reason.text.trim()), success: 'تم إلغاء الفاتورة');
    }
  }

  Future<void> _edit(BuildContext context, Invoice inv) async {
    if (!await AdminGate.require(context, reason: 'تعديل المبيعات للمدير فقط')) return;
    if (!context.mounted) return;
    final name = TextEditingController(text: inv.customerName);
    final phone = TextEditingController(text: inv.customerPhone);
    final disc = TextEditingController(text: inv.discount == 0 ? '' : numFmt(inv.discount));
    final note = TextEditingController(text: inv.note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('تعديل ${inv.code}'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم الزبون')),
              const SizedBox(height: 10),
              TextField(controller: phone, decoration: const InputDecoration(labelText: 'الهاتف')),
              const SizedBox(height: 10),
              MoneyField(controller: disc, label: 'الخصم'),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'ملاحظة')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await guard(
        context,
        () => SalesRepo.edit(inv, customerName: name.text.trim(), customerPhone: phone.text.trim(), discount: parseMoney(disc.text), note: note.text.trim()),
        success: 'تم تعديل الفاتورة',
      );
    }
  }
}
