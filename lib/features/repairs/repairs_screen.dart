import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/repairs_repo.dart';
import '../../services/session.dart';
import '../invoices/receipt_actions.dart';
import 'repair_form.dart';

class RepairsScreen extends StatefulWidget {
  const RepairsScreen({super.key});
  @override
  State<RepairsScreen> createState() => _RepairsScreenState();
}

/// فلاتر: الأجهزة الموجودة بالمحل / كل حالة / المسلّمة
enum _Filter { inShop, received, inProgress, waitingParts, ready, unfixable, delivered, all }

extension on _Filter {
  String get label => switch (this) {
        _Filter.inShop => 'بالمحل',
        _Filter.received => RepairStatus.received.label,
        _Filter.inProgress => RepairStatus.inProgress.label,
        _Filter.waitingParts => RepairStatus.waitingParts.label,
        _Filter.ready => RepairStatus.ready.label,
        _Filter.unfixable => RepairStatus.unfixable.label,
        _Filter.delivered => RepairStatus.delivered.label,
        _Filter.all => 'الكل',
      };
  Set<RepairStatus>? get statuses => switch (this) {
        _Filter.inShop => RepairStatus.values.where((s) => s.isOpen).toSet(),
        _Filter.received => {RepairStatus.received},
        _Filter.inProgress => {RepairStatus.inProgress},
        _Filter.waitingParts => {RepairStatus.waitingParts},
        _Filter.ready => {RepairStatus.ready},
        _Filter.unfixable => {RepairStatus.unfixable},
        _Filter.delivered => {RepairStatus.delivered},
        _Filter.all => null,
      };
  RepairStatus? get status => switch (this) {
        _Filter.received => RepairStatus.received,
        _Filter.inProgress => RepairStatus.inProgress,
        _Filter.waitingParts => RepairStatus.waitingParts,
        _Filter.ready => RepairStatus.ready,
        _Filter.unfixable => RepairStatus.unfixable,
        _Filter.delivered => RepairStatus.delivered,
        _ => null,
      };
}

class _RepairsScreenState extends State<RepairsScreen> {
  _Filter _filter = _Filter.inShop;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'repair-fab',
        onPressed: () => showRepairForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('استلام جهاز'),
      ).animate().scaleXY(begin: 0, end: 1, delay: 200.ms, curve: Curves.easeOutBack),
      body: DataView<(List<Repair>, Map<RepairStatus, int>)>(
        reloadKey: '$_filter-$_q',
        load: () async => (await RepairsRepo.list(statuses: _filter.statuses, query: _q), await RepairsRepo.counts()),
        builder: (context, d) {
          final (repairs, counts) = d;
          final inShop = counts.entries.where((e) => e.key.isOpen).fold<int>(0, (s, e) => s + e.value);
          int countOf(_Filter f) => switch (f) {
                _Filter.inShop => inShop,
                _Filter.all => counts.values.fold(0, (s, v) => s + v),
                _ => counts[f.status] ?? 0,
              };
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    for (final s in [RepairStatus.received, RepairStatus.inProgress, RepairStatus.ready]) ...[
                      Expanded(
                        child: _StatusStat(status: s, count: counts[s] ?? 0, onTap: () => setState(() => _filter = _Filter.values.firstWhere((f) => f.status == s))),
                      ),
                      if (s != RepairStatus.ready) const SizedBox(width: 10),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  SearchField(hint: 'بحث بالاسم، الهاتف، الموديل، IMEI أو رقم الوصل...', onChanged: (v) => setState(() => _q = v)),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final f in _Filter.values) ...[
                        ChoiceChip(
                          label: Text('${f.label} (${countOf(f)})'),
                          selected: _filter == f,
                          selectedColor: (f.status?.color ?? AppColors.gold).withValues(alpha: .25),
                          avatar: f.status == null ? null : Icon(f.status!.icon, size: 18, color: f.status!.color),
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ]),
                  ),
                ]),
              ),
            ),
            if (repairs.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.phonelink_setup_rounded,
                  title: _filter == _Filter.inShop ? 'لا توجد أجهزة بالصيانة حالياً' : 'لا توجد أجهزة',
                  message: 'كل جهاز تستلمه من الزبائن يظهر هنا مع حالته',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 560, mainAxisExtent: 158, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  delegate: SliverChildBuilderDelegate((c, i) => _RepairCard(repair: repairs[i]).stagger(i), childCount: repairs.length),
                ),
              ),
          ]);
        },
      ),
    );
  }
}

class _StatusStat extends StatelessWidget {
  final RepairStatus status;
  final int count;
  final VoidCallback onTap;
  const _StatusStat({required this.status, required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          IconBadge(icon: status.icon, color: status.color, size: 38),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CountUp(count, asMoney: false, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              Text(status.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: context.cs.onSurfaceVariant)),
            ]),
          ),
        ]),
      );
}

class _RepairCard extends StatelessWidget {
  final Repair repair;
  const _RepairCard({required this.repair});

  @override
  Widget build(BuildContext context) {
    final r = repair;
    final s = r.status;
    final late = r.expectedAt != null && s.isOpen && s != RepairStatus.ready && DateTime.now().millisecondsSinceEpoch > r.expectedAt! + 86400000;
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: () => showRepairDetails(context, r.id),
      child: Row(children: [
        Container(width: 6, decoration: BoxDecoration(color: s.color, borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(20)))),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text(r.code, textDirection: TextDirection.ltr, style: TextStyle(fontWeight: FontWeight.w800, color: context.cs.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text(r.device, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Pill(s.label, color: s.color, icon: s.icon),
              ]),
              const SizedBox(height: 6),
              Text(r.issue, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.cs.onSurfaceVariant)),
              const Spacer(),
              Row(children: [
                Icon(Icons.person_rounded, size: 16, color: context.cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(child: Text('${r.customerName} ${r.customerPhone}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (late) const Pill('متأخر', color: AppColors.danger, icon: Icons.alarm_rounded),
                const SizedBox(width: 6),
                Text(ago(r.receivedAt), style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
              ]),
              if (r.estimatedCost > 0 || r.finalCost > 0)
                Text(
                  s == RepairStatus.delivered ? 'سُلّم بمبلغ ${money(r.finalCost)}' : 'تقديري ${money(r.estimatedCost)}${r.deposit > 0 ? ' • عربون ${money(r.deposit)}' : ''}',
                  style: TextStyle(fontSize: 12, color: context.cs.primary, fontWeight: FontWeight.w700),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}

Future<void> showRepairDetails(BuildContext context, int id) => showAppSheet(context, _RepairDetails(id: id), maxWidth: 720);

class _RepairDetails extends StatelessWidget {
  final int id;
  const _RepairDetails({required this.id});

  @override
  Widget build(BuildContext context) {
    return DataView<(Repair?, List<RepairLogEntry>)>(
      load: () async => (await RepairsRepo.get(id), await RepairsRepo.history(id)),
      builder: (context, d) {
        final (r, log) = d;
        if (r == null) return const EmptyState(icon: Icons.delete_outline, title: 'تم حذف السجل');
        final open = r.status.isOpen;
        return SheetScaffold(
          title: '${r.code} • ${r.device}',
          icon: r.status.icon,
          footer: open
              ? Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _deliver(context, r),
                      icon: const Icon(Icons.handshake_rounded),
                      label: const Text('تسليم للزبون'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    tooltip: 'طباعة وصل الاستلام',
                    onPressed: () => printDoc(context, repairPdf(r), r.code),
                    icon: const Icon(Icons.print_rounded),
                    style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'مشاركة الوصل',
                    onPressed: () => shareDoc(context, repairPdf(r), r.code),
                    icon: const Icon(Icons.share_rounded),
                    style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
                  ),
                ])
              : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (open) ...[
              const Text('تحديث الحالة', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in RepairStatus.values.where((s) => s != RepairStatus.delivered))
                  ChoiceChip(
                    avatar: Icon(s.icon, size: 18, color: s.color),
                    label: Text(s.label),
                    selected: r.status == s,
                    selectedColor: s.color.withValues(alpha: .25),
                    onSelected: (_) async {
                      if (r.status == s) return;
                      await guard(context, () => RepairsRepo.setStatus(r, s), success: 'الحالة: ${s.label}');
                    },
                  ),
              ]),
              const SizedBox(height: 14),
            ],
            InfoRow('الزبون', r.customerName, icon: Icons.person_rounded),
            InfoRow('الهاتف', r.customerPhone, icon: Icons.phone_rounded),
            InfoRow('العطل', r.issue, icon: Icons.report_problem_rounded),
            if (r.imei.isNotEmpty) InfoRow('IMEI', r.imei, icon: Icons.qr_code_2_rounded),
            if (r.devicePassword.isNotEmpty) InfoRow('رمز القفل', r.devicePassword, icon: Icons.pattern_rounded),
            if (r.accessories.isNotEmpty) InfoRow('الملحقات', r.accessories, icon: Icons.cable_rounded),
            if (r.conditionNotes.isNotEmpty) InfoRow('حالة الجهاز', r.conditionNotes, icon: Icons.visibility_rounded),
            InfoRow('الكلفة التقديرية', money(r.estimatedCost), icon: Icons.request_quote_rounded),
            if (r.deposit > 0) InfoRow('العربون', money(r.deposit), icon: Icons.savings_rounded),
            if (r.status == RepairStatus.delivered) ...[
              InfoRow('المبلغ النهائي', money(r.finalCost), icon: Icons.payments_rounded, bold: true),
              if (Session.instance.isAdmin) InfoRow('كلفة القطع', money(r.partsCost), icon: Icons.memory_rounded),
              if (r.deliveredAt != null) InfoRow('تاريخ التسليم', dateTimeMs(r.deliveredAt!), icon: Icons.event_available_rounded),
            ],
            InfoRow('تاريخ الاستلام', dateTimeMs(r.receivedAt), icon: Icons.schedule_rounded),
            if (r.expectedAt != null) InfoRow('الموعد المتوقع', dateMs(r.expectedAt!), icon: Icons.event_rounded),
            InfoRow('استلمه', r.userName, icon: Icons.badge_rounded),
            if (r.techNotes.isNotEmpty) InfoRow('ملاحظات الفني', r.techNotes, icon: Icons.engineering_rounded),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => _addNote(context, r),
                icon: const Icon(Icons.note_add_rounded),
                label: const Text('ملاحظة فني'),
              ),
              if (r.customerPhone.isNotEmpty && r.status == RepairStatus.ready)
                OutlinedButton.icon(
                  onPressed: () => toast(context, 'اتصل بالزبون على ${r.customerPhone} لإبلاغه بجاهزية الجهاز', icon: Icons.phone_in_talk_rounded),
                  icon: const Icon(Icons.phone_in_talk_rounded),
                  label: const Text('إبلاغ الزبون'),
                ),
              OutlinedButton.icon(
                onPressed: () async {
                  if (!await AdminGate.require(context, reason: 'تعديل سجلات الصيانة للمدير فقط')) return;
                  if (context.mounted) await showRepairForm(context, edit: r);
                },
                icon: Icon(Session.instance.isAdmin ? Icons.edit_rounded : Icons.lock_rounded),
                label: const Text('تعديل'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  if (!await AdminGate.require(context, reason: 'حذف سجلات الصيانة للمدير فقط')) return;
                  if (!context.mounted) return;
                  if (!await confirm(context, 'حذف ${r.code}؟', 'سيتم حذف سجل الجهاز نهائياً', danger: true, ok: 'حذف')) return;
                  await RepairsRepo.delete(r);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_rounded),
                label: const Text('حذف'),
              ),
            ]),
            const SizedBox(height: 16),
            const SectionTitle('مراحل الصيانة'),
            for (var i = 0; i < log.length; i++) _TimelineItem(entry: log[i], last: i == log.length - 1),
          ]),
        );
      },
    );
  }

  Future<void> _addNote(BuildContext context, Repair r) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('ملاحظة الفني'),
        content: TextField(controller: c, autofocus: true, maxLines: 3, decoration: const InputDecoration(hintText: 'مثلاً: تم طلب شاشة أصلية')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إضافة')),
        ],
      ),
    );
    if (ok == true && context.mounted) await guard(context, () => RepairsRepo.addNote(r, c.text));
  }

  Future<void> _deliver(BuildContext context, Repair r) async {
    final finalC = TextEditingController(text: r.estimatedCost > 0 ? numFmt(r.estimatedCost) : '');
    final partsC = TextEditingController();
    final res = await showDialog<(int, int)>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('تسليم ${r.code}'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (r.status == RepairStatus.unfixable)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text('الجهاز "تعذر إصلاحه" — يمكنك وضع المبلغ 0 أو أجور الفحص'),
              ),
            MoneyField(controller: finalC, label: 'المبلغ النهائي للصيانة', autofocus: true),
            const SizedBox(height: 10),
            MoneyField(controller: partsC, label: 'كلفة القطع (لحساب الربح)'),
            if (r.deposit > 0) ...[
              const SizedBox(height: 10),
              Text('العربون المستلم مسبقاً: ${money(r.deposit)} — يُخصم من المبلغ عند الاستلام',
                  style: TextStyle(color: d.cs.onSurfaceVariant)),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, (parseMoney(finalC.text), parseMoney(partsC.text))), child: const Text('تسليم وإصدار فاتورة')),
        ],
      ),
    );
    if (res == null || !context.mounted) return;
    final inv = await guard(context, () => RepairsRepo.deliver(r, finalCost: res.$1, partsCost: res.$2));
    if (inv != null && context.mounted) {
      await showInvoiceSuccess(context, inv,
          subtitle: r.deposit > 0 ? 'المطلوب من الزبون الآن ${money((res.$1 - r.deposit).clamp(0, res.$1))}' : r.device);
    }
  }
}

class _TimelineItem extends StatelessWidget {
  final RepairLogEntry entry;
  final bool last;
  const _TimelineItem({required this.entry, required this.last});
  @override
  Widget build(BuildContext context) {
    final c = entry.status.color;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .18), border: Border.all(color: c)),
            child: Icon(entry.status.icon, size: 16, color: c),
          ),
          if (!last) Expanded(child: Container(width: 2, color: context.cs.outline)),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14, top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.note.isEmpty ? entry.status.label : entry.note, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${entry.status.label} • ${dateTimeMs(entry.createdAt)} • ${entry.userName}',
                  style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
            ]),
          ),
        ),
      ]),
    );
  }
}
