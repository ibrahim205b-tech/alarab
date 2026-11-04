import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/expenses_repo.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _month = true;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'exp-fab',
        onPressed: () => showExpenseSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مصروف جديد'),
      ).animate().scaleXY(begin: 0, end: 1, delay: 200.ms, curve: Curves.easeOutBack),
      body: DataView<List<Expense>>(
        reloadKey: _month,
        load: () => ExpensesRepo.list(from: _month ? DateTime(now.year, now.month) : startOfDay(now)),
        builder: (context, list) {
          final total = list.fold<int>(0, (s, e) => s + e.amount);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('اليوم')),
                  ButtonSegment(value: true, label: Text('هذا الشهر')),
                ],
                selected: {_month},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _month = s.first),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Row(children: [
                  const IconBadge(icon: Icons.account_balance_wallet_rounded, color: Color(0xFFF97316), size: 50),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_month ? 'مصروفات ${monthName(now.month)}' : 'مصروفات اليوم', style: TextStyle(color: context.cs.onSurfaceVariant)),
                      CountUp(total, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty) const EmptyState(icon: Icons.receipt_outlined, title: 'لا توجد مصروفات', message: 'سجل الإيجار والكهرباء والرواتب لحساب صافي الربح'),
              for (var i = 0; i < list.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    onLongPress: () async {
                      if (!await AdminGate.require(context)) return;
                      if (!context.mounted) return;
                      if (await confirm(context, 'حذف المصروف؟', '${list[i].category} — ${money(list[i].amount)}', danger: true, ok: 'حذف')) {
                        await ExpensesRepo.delete(list[i]);
                      }
                    },
                    child: Row(children: [
                      const IconBadge(icon: Icons.south_east_rounded, color: AppColors.danger, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list[i].category, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text([if (list[i].note.isNotEmpty) list[i].note, dateTimeMs(list[i].createdAt), list[i].userName].join(' • '),
                              style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
                        ]),
                      ),
                      Text(money(list[i].amount), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
                    ]),
                  ).stagger(i),
                ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> showExpenseSheet(BuildContext context) => showAppSheet(context, const _ExpenseSheet(), maxWidth: 520);

class _ExpenseSheet extends StatefulWidget {
  const _ExpenseSheet();
  @override
  State<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends State<_ExpenseSheet> {
  String _cat = expenseCategories.first;
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'مصروف جديد',
      icon: Icons.account_balance_wallet_rounded,
      footer: FilledButton.icon(
        onPressed: () async {
          final ok = await guard(context, () async {
            await ExpensesRepo.add(_cat, parseMoney(_amount.text), _note.text);
            return true;
          });
          if (ok == true && context.mounted) {
            Navigator.pop(context);
            toast(context, 'تم تسجيل المصروف');
          }
        },
        icon: const Icon(Icons.save_rounded),
        label: const Text('حفظ'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in expenseCategories) ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
        ]),
        const SizedBox(height: 14),
        MoneyField(controller: _amount, label: 'المبلغ', autofocus: true),
        const SizedBox(height: 12),
        TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة', prefixIcon: Icon(Icons.notes_rounded))),
      ]),
    );
  }
}
