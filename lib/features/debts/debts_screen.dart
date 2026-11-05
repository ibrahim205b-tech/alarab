import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/debts_repo.dart';
import '../../data/repos/settings_repo.dart';
import '../../services/contact.dart';
import '../../services/session.dart';
import '../invoices/receipt_actions.dart';
import 'debt_sheet.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});
  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  bool? _open = true;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return DataView<(List<Debt>, (int, int))>(
      reloadKey: '$_open-$_q',
      load: () async => (await DebtsRepo.list(open: _open, query: _q), await DebtsRepo.openSummary()),
      builder: (context, d) {
        final (debts, (openCount, openTotal)) = d;
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF9D174D)]),
                  ),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('إجمالي الديون المستحقة', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                        CountUp(openTotal, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    Column(children: [
                      Text('$openCount', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                      const Text('مفتوح', style: TextStyle(color: Colors.white70)),
                    ]),
                  ]),
                ).animate().fadeIn().slideY(begin: -.1, end: 0),
                const SizedBox(height: 12),
                SearchField(hint: 'بحث بالاسم أو الرقم...', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: 10),
                SegmentedButton<bool?>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('المفتوحة')),
                    ButtonSegment(value: false, label: Text('المسددة')),
                    ButtonSegment(value: null, label: Text('الكل')),
                  ],
                  selected: {_open},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _open = s.first),
                ),
              ]),
            ),
          ),
          if (debts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.menu_book_outlined,
                title: _open == true ? 'لا توجد ديون مفتوحة' : 'لا توجد سجلات',
                action: FilledButton.icon(onPressed: () => showDebtSheet(context), icon: const Icon(Icons.add), label: const Text('إضافة دين')),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 560, mainAxisExtent: 150, crossAxisSpacing: 12, mainAxisSpacing: 12),
                delegate: SliverChildBuilderDelegate(
                  (c, i) => _DebtCard(debt: debts[i]).stagger(i),
                  childCount: debts.length,
                ),
              ),
            ),
        ]);
      },
    );
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  const _DebtCard({required this.debt});

  @override
  Widget build(BuildContext context) {
    final closed = debt.isClosed;
    final color = closed ? AppColors.success : const Color(0xFFEC4899);
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => showDebtDetails(context, debt),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .18),
            child: Text(debt.customerName.characters.first, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(debt.customerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text('${debt.debtType} • ${dateMs(debt.createdAt)}', style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12)),
            ]),
          ),
          Pill(closed ? 'مسدد' : 'مفتوح', color: color),
        ]),
        const Spacer(),
        Row(children: [
          Text('المتبقي ', style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
          Text(money(debt.remaining), style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 17)),
          const Spacer(),
          Text('من ${money(debt.amount)}', style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: debt.progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (c, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 8,
              color: AppColors.success,
              backgroundColor: color.withValues(alpha: .15),
            ),
          ),
        ),
      ]),
    );
  }
}

Future<void> showDebtDetails(BuildContext context, Debt debt) async {
  await showAppSheet(context, _DebtDetails(debtId: debt.id));
}

class _DebtDetails extends StatelessWidget {
  final int debtId;
  const _DebtDetails({required this.debtId});

  @override
  Widget build(BuildContext context) {
    return DataView<(Debt?, List<DebtPayment>)>(
      load: () async => (await DebtsRepo.get(debtId), await DebtsRepo.payments(debtId)),
      builder: (context, d) {
        final (debt, payments) = d;
        if (debt == null) return const EmptyState(icon: Icons.delete_outline, title: 'تم حذف السجل');
        return SheetScaffold(
          title: debt.customerName,
          icon: Icons.menu_book_rounded,
          footer: debt.isClosed
              ? null
              : FilledButton.icon(
                  onPressed: () => _pay(context, debt),
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('تسجيل دفعة / تسديد'),
                ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InfoRow('الهاتف', debt.customerPhone, icon: Icons.phone_rounded),
            if (Contact.valid(debt.customerPhone))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  if (!debt.isClosed)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF25D366)),
                        onPressed: () => Contact.whatsapp(
                          debt.customerPhone,
                          'مرحباً ${debt.customerName} 🌹\n'
                          'نود تذكيرك بالمبلغ المتبقي: ${money(debt.remaining)}\n'
                          '(${debt.debtType} بتاريخ ${dateMs(debt.createdAt)})\n'
                          '${SettingsRepo.instance.shopName}',
                        ),
                        icon: const Icon(Icons.chat_rounded),
                        label: const Text('تذكير واتساب'),
                      ),
                    ),
                  if (!debt.isClosed) const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Contact.call(debt.customerPhone),
                      icon: const Icon(Icons.call_rounded),
                      label: const Text('اتصال'),
                    ),
                  ),
                ]),
              ),
            InfoRow('النوع', debt.debtType, icon: Icons.category_rounded),
            InfoRow('المبلغ الكلي', money(debt.amount), icon: Icons.request_quote_rounded),
            InfoRow('المدفوع', money(debt.paid), icon: Icons.check_circle_outline_rounded, color: AppColors.success),
            InfoRow('المتبقي', money(debt.remaining), icon: Icons.hourglass_bottom_rounded, bold: true, color: const Color(0xFFEC4899)),
            if (debt.note.isNotEmpty) InfoRow('ملاحظة', debt.note, icon: Icons.notes_rounded),
            InfoRow('التاريخ', dateTimeMs(debt.createdAt), icon: Icons.schedule_rounded),
            InfoRow('سجّله', debt.userName, icon: Icons.badge_rounded),
            const SizedBox(height: 14),
            if (payments.isNotEmpty) ...[
              const SectionTitle('الدفعات'),
              for (final p in payments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const IconBadge(icon: Icons.south_west_rounded, color: AppColors.success, size: 38),
                  title: Text(money(p.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${dateTimeMs(p.createdAt)} • ${p.userName}'),
                ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (!await AdminGate.require(context, reason: 'تعديل الديون للمدير فقط')) return;
                    if (context.mounted) await showDebtSheet(context, edit: debt);
                  },
                  icon: Icon(Session.instance.isAdmin ? Icons.edit_rounded : Icons.lock_rounded),
                  label: const Text('تعديل'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    if (!await AdminGate.require(context, reason: 'حذف الديون للمدير فقط')) return;
                    if (!context.mounted) return;
                    if (!await confirm(context, 'حذف الدين؟', 'سيتم حذف دين ${debt.customerName} نهائياً', danger: true, ok: 'حذف')) return;
                    await DebtsRepo.delete(debt);
                    if (context.mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_rounded),
                  label: const Text('حذف'),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  Future<void> _pay(BuildContext context, Debt debt) async {
    final c = TextEditingController(text: numFmt(debt.remaining));
    final amount = await showDialog<int>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('تسجيل دفعة'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('المتبقي على ${debt.customerName}: ${money(debt.remaining)}'),
          const SizedBox(height: 12),
          MoneyField(controller: c, label: 'المبلغ المستلم', autofocus: true, quick: [debt.remaining, if (debt.remaining > 10000) debt.remaining ~/ 2]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(d, parseMoney(c.text)), child: const Text('تأكيد')),
        ],
      ),
    );
    if (amount == null || !context.mounted) return;
    final inv = await guard(context, () => DebtsRepo.pay(debt, amount));
    if (inv != null && context.mounted) {
      await showInvoiceSuccess(context, inv, subtitle: 'المتبقي ${money(debt.remaining - amount)}');
    }
  }
}
