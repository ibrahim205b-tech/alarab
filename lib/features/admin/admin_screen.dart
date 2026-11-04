import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/repos/reports_repo.dart';
import '../../data/repos/settings_repo.dart';
import '../../services/printer.dart';
import '../../services/telegram.dart';
import 'admin_pages.dart';
import 'catalog_page.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DataView<int>(
      load: TelegramService.instance.pendingCount,
      builder: (context, pending) {
        final s = SettingsRepo.instance;
        final printer = PrinterService.instance;
        final tiles = <(String, String, IconData, Color, Widget Function())>[
          ('الخطوط والخدمات', 'الشركات، أنواع الخطوط، الخدمات وأسعارها', Icons.sim_card_rounded, AppColors.asiacell, () => const CatalogPage()),
          ('المستخدمون', 'الموظفون والمدراء والرموز السرية', Icons.group_rounded, AppColors.info, () => const UsersPage()),
          ('معلومات المحل', s.shopName, Icons.storefront_rounded, AppColors.gold, () => const ShopInfoPage()),
          (
            'الطابعة',
            switch (printer.mode) {
              'bluetooth' => 'بلوتوث: ${printer.btName.isEmpty ? 'غير محددة' : printer.btName} • ${printer.paper} مم',
              'system' => 'طباعة النظام (واي فاي / USB)',
              _ => 'بدون طابعة — البرنامج يعمل طبيعياً',
            },
            Icons.print_rounded,
            AppColors.purple,
            () => const PrinterPage()
          ),
          (
            'بوت تليجرام',
            TelegramService.instance.enabled ? 'مفعّل${pending > 0 ? ' • $pending رسالة بالانتظار' : ''}' : 'غير مفعّل',
            Icons.send_rounded,
            const Color(0xFF229ED9),
            () => const TelegramPage()
          ),
          ('النسخ الاحتياطي', 'حفظ واستعادة كل البيانات', Icons.backup_rounded, AppColors.teal, () => const BackupPage()),
          ('أقسام المخزن', 'إضافة أقسام جديدة للمنتجات', Icons.category_rounded, const Color(0xFFEC4899), () => const CategoriesPage()),
          ('سجل العمليات', 'من أضاف، باع، عدّل أو حذف', Icons.history_rounded, const Color(0xFF64748B), () => const ActivityPage()),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
          children: [
            LayoutBuilder(builder: (c, cons) {
              final cols = cons.maxWidth > 900 ? 3 : (cons.maxWidth > 560 ? 2 : 1);
              final w = (cons.maxWidth - (cols - 1) * 12) / cols;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                for (var i = 0; i < tiles.length; i++)
                  SizedBox(
                    width: w,
                    child: AppCard(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => tiles[i].$5())),
                      child: Row(children: [
                        IconBadge(icon: tiles[i].$3, color: tiles[i].$4, size: 50),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tiles[i].$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(tiles[i].$2, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
                          ]),
                        ),
                        Icon(Icons.chevron_left_rounded, color: context.cs.onSurfaceVariant),
                      ]),
                    ).stagger(i),
                  ),
              ]);
            }),
            const SizedBox(height: 20),
            const _ResetCard(),
          ],
        );
      },
    );
  }
}

/// تصفير مبيعات الشهر
class _ResetCard extends StatelessWidget {
  const _ResetCard();
  @override
  Widget build(BuildContext context) {
    return DataView<Period>(
      load: ReportsRepo.currentPeriod,
      builder: (context, p) => AppCard(
        borderColor: AppColors.danger.withValues(alpha: .4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Row(children: [
            IconBadge(icon: Icons.restart_alt_rounded, color: AppColors.danger, size: 46),
            SizedBox(width: 12),
            Expanded(
              child: Text('تصفير مبيعات الشهر', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(
            'الفترة الحالية بدأت ${dateTimeMs(p.startedAt)}.\n'
            'التصفير يُرجع ترقيم الخطوط والفواتير إلى #1 ويحفظ ملخص الفترة في الأرشيف. '
            'لا تُحذف أي سجلات — تبقى كلها في التقارير والفواتير.',
            style: TextStyle(color: context.cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              if (!await confirm(context, 'تصفير مبيعات الشهر؟', 'سيبدأ الترقيم من #1 وتُفتح فترة جديدة', danger: true, ok: 'تصفير')) return;
              if (!context.mounted) return;
              await guard(context, ReportsRepo.closePeriod, success: 'تم التصفير وبدأت فترة جديدة');
            },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('تصفير الآن'),
          ),
        ]),
      ),
    );
  }
}
