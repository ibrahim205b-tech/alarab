import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/reports_repo.dart';

/// تصفير الوردية: يعرض ملخص الفترة الحالية ثم يبدأ فترة جديدة من صفر دينار.
/// السجلات القديمة لا تُحذف — تبقى في الفواتير والتقارير والأرشيف.
Future<void> confirmShiftReset(BuildContext context) async {
  if (!await AdminGate.require(context, reason: 'تصفير الوردية للمدير فقط')) return;
  if (!context.mounted) return;
  final start = await ReportsRepo.shiftStart();
  final s = await ReportsRepo.shiftSummary();
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      icon: const Icon(Icons.restart_alt_rounded, color: AppColors.danger, size: 44),
      title: const Text('تصفير الوردية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('ملخص الوردية من ${dateTimeStr(start)}', textAlign: TextAlign.center, style: TextStyle(color: d.cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            InfoRow('عدد العمليات', '${s.count}', icon: Icons.receipt_long_rounded),
            InfoRow('مبيعات المنتجات', money(s.byType[InvoiceType.sale]?.total ?? 0), icon: Icons.shopping_bag_rounded),
            InfoRow('الخطوط (${s.byType[InvoiceType.line]?.count ?? 0})', money(s.byType[InvoiceType.line]?.total ?? 0), icon: Icons.sim_card_rounded),
            InfoRow('الصيانة', money(s.byType[InvoiceType.repair]?.total ?? 0), icon: Icons.build_circle_rounded),
            InfoRow('إجمالي المبيعات', money(s.revenue), icon: Icons.payments_rounded, bold: true),
            const Divider(height: 20),
            InfoRow('تسديد ديون', money(s.collectedDebts), icon: Icons.south_west_rounded),
            InfoRow('المستلم', money(s.received), icon: Icons.account_balance_wallet_rounded, color: AppColors.success),
            InfoRow('المصروفات', money(s.expenses), icon: Icons.north_east_rounded, color: AppColors.danger),
            InfoRow('الصافي بالصندوق', money(s.cash), icon: Icons.savings_rounded, bold: true, color: d.cs.primary),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)),
              child: const Text(
                'بعد التصفير تبدأ وردية جديدة: المبيعات والمستلم والمصروفات ترجع إلى 0 د.ع، والترقيم يبدأ من #1.\n'
                'لا يُحذف أي سجل — كل الفواتير تبقى في الأرشيف والتقارير، والديون المتبقية على الزبائن لا تتأثر.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ]),
        ),
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(d, true),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('تصفير الآن'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  await guard(context, ReportsRepo.closePeriod, success: 'تم التصفير — بدأت وردية جديدة من 0 د.ع');
}
