import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/brand.dart';
import '../../core/format.dart';
import '../../core/version.dart';
import '../../services/license.dart';
import '../../core/license_crypto.dart';
import '../../data/repos/base.dart' as base;
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/repos/products_repo.dart';
import '../../data/repos/reports_repo.dart';
import '../../data/repos/settings_repo.dart';
import '../../data/repos/users_repo.dart';
import '../../services/backup.dart';
import '../../services/printer.dart';
import '../../services/session.dart';
import '../../services/telegram.dart';

SettingsRepo get _s => SettingsRepo.instance;

class _Page extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? fab;
  const _Page({required this.title, required this.children, this.fab});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        floatingActionButton: fab,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: children),
          ),
        ),
      );
}

// =====================================================================
// المستخدمون
// =====================================================================

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _userDialog(context),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('مستخدم جديد'),
      ),
      body: DataView<List<AppUser>>(
        load: UsersRepo.all,
        builder: (context, users) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            Text('الموظف يستطيع الإضافة فقط (بيع، خط، صيانة، منتج، دين). التعديل والحذف للمدير فقط، '
                'ويمكن للمدير الموافقة على أي عملية من جهاز الموظف بإدخال رمزه.',
                style: TextStyle(color: context.cs.onSurfaceVariant)),
            const SizedBox(height: 14),
            for (var i = 0; i < users.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _userDialog(context, users[i]),
                  child: Opacity(
                    opacity: users[i].active ? 1 : .5,
                    child: Row(children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: (users[i].isAdmin ? AppColors.gold : AppColors.teal).withValues(alpha: .2),
                        child: Text(users[i].name.characters.first,
                            style: TextStyle(fontWeight: FontWeight.w800, color: users[i].isAdmin ? AppColors.gold : AppColors.teal)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(users[i].name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          Text(users[i].active ? users[i].roleLabel : 'موقوف', style: TextStyle(color: context.cs.onSurfaceVariant)),
                        ]),
                      ),
                      if (users[i].id == Session.instance.user?.id) const Pill('أنت', color: AppColors.gold),
                      const Icon(Icons.chevron_left_rounded),
                    ]),
                  ),
                ).stagger(i),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _userDialog(BuildContext context, [AppUser? u]) async {
    final name = TextEditingController(text: u?.name);
    final pin = TextEditingController();
    var role = u?.role ?? 'employee';
    var active = u?.active ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(u == null ? 'مستخدم جديد' : 'تعديل ${u.name}'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم', prefixIcon: Icon(Icons.person_rounded))),
              const SizedBox(height: 12),
              TextField(
                controller: pin,
                maxLength: 4,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: u == null ? 'الرمز السري (4 أرقام)' : 'رمز جديد (اتركه فارغاً بدون تغيير)',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'employee', label: Text('موظف'), icon: Icon(Icons.badge_rounded)),
                  ButtonSegment(value: 'admin', label: Text('مدير'), icon: Icon(Icons.verified_user_rounded)),
                ],
                selected: {role},
                onSelectionChanged: (s) => set(() => role = s.first),
              ),
              if (u != null)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الحساب فعّال'),
                  value: active,
                  onChanged: (v) => set(() => active = v),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    if (name.text.trim().isEmpty) return;
    if ((u == null || pin.text.isNotEmpty) && !RegExp(r'^\d{4}$').hasMatch(pin.text)) {
      toast(context, 'الرمز يجب أن يكون 4 أرقام', error: true);
      return;
    }
    await guard(context, () async {
      if (u == null) {
        await UsersRepo.create(name.text, pin.text, role);
      } else {
        await UsersRepo.update(u.id, name: name.text, pin: pin.text, role: role, active: active);
      }
    }, success: 'تم الحفظ');
  }
}

// =====================================================================
// معلومات المحل
// =====================================================================

class ShopInfoPage extends StatefulWidget {
  const ShopInfoPage({super.key});
  @override
  State<ShopInfoPage> createState() => _ShopInfoPageState();
}

class _ShopInfoPageState extends State<ShopInfoPage> {
  final _name = TextEditingController(text: _s.shopName);
  final _phone = TextEditingController(text: _s.get('shop_phone'));
  final _address = TextEditingController(text: _s.get('shop_address'));
  final _footer = TextEditingController(text: _s.get('receipt_footer'));
  final _terms = TextEditingController(text: _s.get('repair_terms'));

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'معلومات المحل',
      fab: FloatingActionButton.extended(
        onPressed: () async {
          await _s.setMany({
            'shop_name': _name.text.trim(),
            'shop_phone': _phone.text.trim(),
            'shop_address': _address.text.trim(),
            'receipt_footer': _footer.text.trim(),
            'repair_terms': _terms.text.trim(),
          });
          if (context.mounted) {
            toast(context, 'تم الحفظ');
            Navigator.pop(context);
          }
        },
        icon: const Icon(Icons.save_rounded),
        label: const Text('حفظ'),
      ),
      children: [
        Text('تظهر هذه المعلومات في رأس وذيل كل فاتورة مطبوعة.', style: TextStyle(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 14),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'اسم المحل', prefixIcon: Icon(Icons.storefront_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.call_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _address, decoration: const InputDecoration(labelText: 'العنوان', prefixIcon: Icon(Icons.location_on_rounded))),
        const SizedBox(height: 12),
        TextField(controller: _footer, decoration: const InputDecoration(labelText: 'رسالة أسفل الفاتورة', prefixIcon: Icon(Icons.favorite_rounded))),
        const SizedBox(height: 12),
        TextField(
          controller: _terms,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'شروط وصل استلام الصيانة', prefixIcon: Icon(Icons.gavel_rounded)),
        ),
      ],
    );
  }
}

// =====================================================================
// الطابعة
// =====================================================================

class PrinterPage extends StatefulWidget {
  const PrinterPage({super.key});
  @override
  State<PrinterPage> createState() => _PrinterPageState();
}

class _PrinterPageState extends State<PrinterPage> {
  List<BtDevice> _devices = [];
  String? _err;
  bool _scanning = false;

  PrinterService get p => PrinterService.instance;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    final (list, err) = await p.pairedDevices();
    if (!mounted) return;
    setState(() {
      _devices = list;
      _err = err;
      _scanning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([]),
      builder: (context, _) => _Page(title: 'الطابعة', children: [
        Text('الطابعة اختيارية: إذا لم تتوفر يعمل البرنامج بشكل كامل ويمكنك مشاركة الفواتير PDF.',
            style: TextStyle(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'none', label: Text('بدون'), icon: Icon(Icons.print_disabled_rounded)),
            ButtonSegment(value: 'bluetooth', label: Text('بلوتوث حرارية'), icon: Icon(Icons.bluetooth_rounded)),
            ButtonSegment(value: 'system', label: Text('واي فاي / النظام'), icon: Icon(Icons.wifi_rounded)),
          ],
          selected: {p.mode},
          onSelectionChanged: (s) async {
            await _s.set('printer_mode', s.first);
            setState(() {});
            if (s.first == 'bluetooth') _scan();
          },
        ),
        const SizedBox(height: 16),
        if (p.mode != 'none') ...[
          const Text('عرض ورق الطابعة', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [ButtonSegment(value: 58, label: Text('58 مم')), ButtonSegment(value: 80, label: Text('80 مم'))],
            selected: {p.paper},
            onSelectionChanged: (s) async {
              await _s.set('paper_width', '${s.first}');
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('طباعة تلقائية بعد كل عملية بيع'),
            value: _s.flag('auto_print'),
            onChanged: (v) async {
              await _s.set('auto_print', v ? '1' : '0');
              setState(() {});
            },
          ),
        ],
        if (p.mode == 'bluetooth') ...[
          const SizedBox(height: 8),
          SectionTitle('طابعات البلوتوث المقترنة',
              subtitle: 'اقرن الطابعة أولاً من إعدادات البلوتوث في الجهاز',
              trailing: IconButton(onPressed: _scanning ? null : _scan, icon: const Icon(Icons.refresh_rounded))),
          if (_scanning) const LinearProgressIndicator(),
          if (_err != null) Text(_err!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          if (!_scanning && _devices.isEmpty && _err == null)
            OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.bluetooth_searching_rounded), label: const Text('عرض الأجهزة المقترنة')),
          for (final d in _devices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const IconBadge(icon: Icons.print_rounded, color: AppColors.purple, size: 40),
              title: Text(d.name.isEmpty ? 'جهاز بدون اسم' : d.name, style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(d.mac, textDirection: TextDirection.ltr, textAlign: TextAlign.start),
              trailing: _s.get('bt_mac') == d.mac
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.success)
                  : const Icon(Icons.radio_button_unchecked_rounded),
              onTap: () async {
                await _s.setMany({'bt_mac': d.mac, 'bt_name': d.name});
                setState(() {});
              },
            ),
          if (_s.get('bt_mac').isNotEmpty && !_devices.any((d) => d.mac == _s.get('bt_mac')))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle_rounded, color: AppColors.success),
              title: Text('الطابعة المختارة: ${_s.get('bt_name')}'),
            ),
        ],
        if (p.mode != 'none') ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () async {
              final err = await p.testPrint();
              if (context.mounted) toast(context, err ?? 'تم إرسال صفحة الاختبار', error: err != null);
            },
            icon: const Icon(Icons.print_rounded),
            label: const Text('طباعة صفحة اختبار'),
          ),
        ],
      ]),
    );
  }
}

// =====================================================================
// تليجرام
// =====================================================================

class TelegramPage extends StatefulWidget {
  const TelegramPage({super.key});
  @override
  State<TelegramPage> createState() => _TelegramPageState();
}

class _TelegramPageState extends State<TelegramPage> {
  final _token = TextEditingController(text: _s.get('tg_token'));
  final _chat = TextEditingController(text: _s.get('tg_chat'));
  bool _busy = false;

  static const _events = [
    ('tg_ev_sale', 'بيع المنتجات', Icons.shopping_bag_rounded),
    ('tg_ev_line', 'بيع الخطوط والخدمات', Icons.sim_card_rounded),
    ('tg_ev_repair', 'استلام وتسليم الصيانة', Icons.build_circle_rounded),
    ('tg_ev_debt', 'الديون والتسديدات', Icons.menu_book_rounded),
    ('tg_ev_expense', 'المصروفات', Icons.account_balance_wallet_rounded),
  ];

  Future<void> _save() => _s.setMany({'tg_token': _token.text.trim(), 'tg_chat': _chat.text.trim()});

  @override
  Widget build(BuildContext context) {
    return _Page(title: 'بوت تليجرام', children: [
      AppCard(
        color: const Color(0xFF229ED9).withValues(alpha: .1),
        borderColor: const Color(0xFF229ED9).withValues(alpha: .4),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('طريقة الربط (مرة واحدة فقط)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          SizedBox(height: 8),
          Text('1. افتح تليجرام وابحث عن @BotFather ثم أرسل /newbot واتبع الخطوات.\n'
              '2. انسخ "رمز البوت" (Token) الذي يعطيك إياه والصقه بالأسفل.\n'
              '3. افتح البوت الجديد وأرسل له أي رسالة (مثلاً: مرحبا).\n'
              '4. اضغط "جلب المعرّف تلقائياً" ثم "إرسال رسالة تجربة".\n'
              'لإرسال الإشعارات لمجموعة: أضف البوت للمجموعة وأرسل فيها رسالة ثم اجلب المعرّف.'),
        ]),
      ),
      const SizedBox(height: 14),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('تفعيل الإشعارات', style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: const Text('يصلك إشعار بنوع البيع وسعره عند كل عملية مؤكدة'),
        value: _s.flag('tg_enabled'),
        onChanged: (v) async {
          await _save();
          await _s.set('tg_enabled', v ? '1' : '0');
          setState(() {});
        },
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _token,
        textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'رمز البوت (Bot Token)', prefixIcon: Icon(Icons.key_rounded)),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _chat,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'معرّف المحادثة (Chat ID)', prefixIcon: Icon(Icons.chat_rounded)),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  final (id, err) = await TelegramService.instance.detectChatId(_token.text);
                  if (!mounted) return;
                  setState(() => _busy = false);
                  if (id != null) {
                    _chat.text = id;
                    await _save();
                    if (context.mounted) toast(context, 'تم جلب المعرّف');
                  } else if (context.mounted) {
                    toast(context, err ?? 'خطأ', error: true);
                  }
                },
          child: const Text('جلب المعرّف\nتلقائياً', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _busy
            ? null
            : () async {
                setState(() => _busy = true);
                await _save();
                final err = await TelegramService.instance.test(_token.text, _chat.text);
                if (!mounted) return;
                setState(() => _busy = false);
                if (context.mounted) toast(context, err == null ? 'وصلت الرسالة إلى تليجرام ✅' : 'فشل: $err', error: err != null);
              },
        icon: const Icon(Icons.send_rounded),
        label: const Text('حفظ وإرسال رسالة تجربة'),
      ),
      const SizedBox(height: 20),
      const SectionTitle('الإشعارات المرسلة'),
      for (final e in _events)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Icon(e.$3),
          title: Text(e.$2),
          value: _s.flag(e.$1),
          onChanged: (v) async {
            await _s.set(e.$1, v ? '1' : '0');
            setState(() {});
          },
        ),
      const SizedBox(height: 8),
      FutureBuilder<int>(
        future: TelegramService.instance.pendingCount(),
        builder: (c, s) => (s.data ?? 0) == 0
            ? const SizedBox()
            : AppCard(
                child: Row(children: [
                  const Icon(Icons.schedule_send_rounded, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${s.data} رسالة بانتظار الإنترنت — تُرسل تلقائياً عند توفر الاتصال')),
                  TextButton(
                    onPressed: () async {
                      await TelegramService.instance.flush();
                      setState(() {});
                    },
                    child: const Text('أرسل الآن'),
                  ),
                ]),
              ),
      ),
    ]);
  }
}

// =====================================================================
// النسخ الاحتياطي
// =====================================================================

class BackupPage extends StatelessWidget {
  const BackupPage({super.key});
  @override
  Widget build(BuildContext context) {
    return _Page(title: 'النسخ الاحتياطي', children: [
      Text('كل بيانات المحل محفوظة على هذا الجهاز. احفظ نسخة احتياطية بانتظام حتى لا تضيع البيانات إذا تلف الجهاز أو حُذف البرنامج. '
          'البرنامج يحفظ أيضاً نسخة تلقائية يومية داخلية (آخر 7 أيام).',
          style: TextStyle(color: context.cs.onSurfaceVariant)),
      const SizedBox(height: 16),
      _BackupAction(
        icon: Icons.ios_share_rounded,
        color: AppColors.teal,
        title: 'حفظ / مشاركة نسخة احتياطية',
        subtitle: 'احفظها في الملفات أو Google Drive أو أرسلها بالواتساب',
        onTap: () => guard(context, BackupService.share),
      ),
      _BackupAction(
        icon: Icons.send_rounded,
        color: const Color(0xFF229ED9),
        title: 'إرسال نسخة إلى تليجرام',
        subtitle: 'تُرسل كملف إلى نفس محادثة البوت',
        onTap: () async {
          toast(context, 'جاري الإرسال...', icon: Icons.cloud_upload_rounded);
          final err = await BackupService.sendToTelegram();
          if (context.mounted) toast(context, err ?? 'تم إرسال النسخة إلى تليجرام', error: err != null);
        },
      ),
      _BackupAction(
        icon: Icons.settings_backup_restore_rounded,
        color: AppColors.danger,
        title: 'استعادة من ملف',
        subtitle: 'تحذير: تستبدل كل البيانات الحالية بمحتوى الملف',
        onTap: () async {
          if (!await confirm(context, 'استعادة نسخة احتياطية؟', 'ستُستبدل كل البيانات الحالية. يُنصح بحفظ نسخة من الوضع الحالي أولاً.', danger: true, ok: 'اختيار الملف')) {
            return;
          }
          final bytes = await BackupService.pickFile();
          if (bytes == null || !context.mounted) return;
          final ok = await guard(context, () async {
            await BackupService.restore(bytes);
            return true;
          });
          if (ok == true && context.mounted) {
            toast(context, 'تمت الاستعادة — سجّل الدخول مجدداً');
            Navigator.of(context).popUntil((r) => r.isFirst);
            Session.instance.logout();
          }
        },
      ),
      const SizedBox(height: 10),
      FutureBuilder(
        future: BackupService.autoBackups(),
        builder: (c, s) {
          final files = s.data ?? const [];
          if (files.isEmpty) return const SizedBox();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('النسخ التلقائية'),
            for (final f in files)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_rounded),
                title: Text(f.uri.pathSegments.last, textDirection: TextDirection.ltr, textAlign: TextAlign.start),
                trailing: TextButton(
                  onPressed: () async {
                    if (!await confirm(context, 'استعادة هذه النسخة؟', 'ستُستبدل كل البيانات الحالية', danger: true, ok: 'استعادة')) return;
                    final bytes = await f.readAsBytes();
                    if (!context.mounted) return;
                    final ok = await guard(context, () async {
                      await BackupService.restore(bytes);
                      return true;
                    });
                    if (ok == true && context.mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      Session.instance.logout();
                    }
                  },
                  child: const Text('استعادة'),
                ),
              ),
          ]);
        },
      ),
    ]);
  }
}

class _BackupAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  const _BackupAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AppCard(
          onTap: onTap,
          child: Row(children: [
            IconBadge(icon: icon, color: color, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(subtitle, style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
      );
}

// =====================================================================
// أقسام المخزن
// =====================================================================

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أقسام المخزن')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('قسم جديد'),
      ),
      body: DataView<List<Category>>(
        load: ProductsRepo.categories,
        builder: (context, cats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (var i = 0; i < cats.length; i++)
              ListTile(
                leading: IconBadge(icon: categoryIcon(cats[i].icon), color: cats[i].c, size: 42),
                title: Text(cats[i].name, style: const TextStyle(fontWeight: FontWeight.w800)),
              ).stagger(i),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    var icon = 'box';
    var color = palette.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('قسم جديد'),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'اسم القسم')),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in categoryIconKeys)
                  ChoiceChip(label: Icon(categoryIcon(k), size: 20), selected: icon == k, onSelected: (_) => set(() => icon = k)),
              ]),
              const SizedBox(height: 14),
              ColorPicker(value: color, onChanged: (v) => set(() => color = v)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('إضافة')),
          ],
        ),
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty) await ProductsRepo.addCategory(name.text, icon, color);
  }
}

// =====================================================================
// سجل العمليات
// =====================================================================

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل العمليات')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SearchField(hint: 'بحث بالعملية أو الموظف...', onChanged: (v) => setState(() => _q = v)),
        ),
        Expanded(
          child: DataView<List<ActivityEntry>>(
            reloadKey: _q,
            load: () => ReportsRepo.activity(query: _q),
            builder: (context, list) => list.isEmpty
                ? const EmptyState(icon: Icons.history_rounded, title: 'لا توجد عمليات')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (c, i) {
                      final a = list[i];
                      final danger = a.action.contains('حذف') || a.action.contains('إلغاء');
                      final edit = a.action.contains('تعديل') || a.action.contains('تصفير');
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: IconBadge(
                          icon: danger ? Icons.delete_rounded : (edit ? Icons.edit_rounded : Icons.add_rounded),
                          color: danger ? AppColors.danger : (edit ? AppColors.warning : AppColors.success),
                          size: 38,
                        ),
                        title: Text(a.action, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${a.details}\n${a.userName} • ${dateTimeMs(a.createdAt)}'),
                        isThreeLine: true,
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// تغيير الرمز السري للمستخدم الحالي
// =====================================================================

Future<void> changeOwnPin(BuildContext context) async {
  final user = Session.instance.user;
  if (user == null) return;
  final old = TextEditingController();
  final pin = TextEditingController();
  final pin2 = TextEditingController();
  final form = GlobalKey<FormState>();
  InputDecoration deco(String l) => InputDecoration(labelText: l, counterText: '', prefixIcon: const Icon(Icons.lock_rounded));
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('تغيير الرمز السري'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: old, obscureText: true, maxLength: 4, keyboardType: TextInputType.number, decoration: deco('الرمز الحالي')),
            const SizedBox(height: 10),
            TextFormField(
              controller: pin,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: deco('الرمز الجديد (4 أرقام)'),
              validator: (v) => RegExp(r'^\d{4}$').hasMatch(v ?? '') ? null : '4 أرقام',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: pin2,
              obscureText: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: deco('تأكيد الرمز الجديد'),
              validator: (v) => v == pin.text ? null : 'غير متطابق',
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () => Navigator.pop(d, form.currentState!.validate()), child: const Text('حفظ')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  if (!await UsersRepo.verify(user.id, old.text)) {
    if (context.mounted) toast(context, 'الرمز الحالي غير صحيح', error: true);
    return;
  }
  if (context.mounted) await guard(context, () => UsersRepo.update(user.id, pin: pin.text), success: 'تم تغيير الرمز السري');
}

// =====================================================================
// حول البرنامج
// =====================================================================

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    return _Page(title: 'حول البرنامج', children: [
      const SizedBox(height: 12),
      const Center(child: BrandMark(size: 96)),
      const SizedBox(height: 16),
      Center(child: Text(_s.shopName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
      const SizedBox(height: 4),
      Center(child: Text('نظام مبيعات متكامل لمحلات الهواتف', style: TextStyle(color: context.cs.onSurfaceVariant))),
      const SizedBox(height: 6),
      Center(child: Pill('الإصدار $appVersion', color: AppColors.gold, icon: Icons.verified_rounded)),
      const SizedBox(height: 24),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionTitle('التطوير'),
          InfoRow('تطوير وبرمجة', developerName, icon: Icons.code_rounded, bold: true),
          InfoRow('المنصة', 'أندرويد — موبايل وتابلت', icon: Icons.android_rounded),
          InfoRow('قاعدة البيانات', 'محلية على الجهاز (تعمل بدون إنترنت)', icon: Icons.storage_rounded),
        ]),
      ),
      const SizedBox(height: 14),
      DataView<List<int>>(
        load: () async {
          final r = await Future.wait([
            for (final t in ['products', 'invoices', 'line_sales', 'repairs', 'debts', 'users'])
              base.db.rawQuery('SELECT COUNT(*) c FROM $t').then((x) => (x.first['c'] as num).toInt()),
          ]);
          return r;
        },
        builder: (context, c) => AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('البيانات المسجلة'),
            InfoRow('المنتجات', '${c[0]}', icon: Icons.inventory_2_rounded),
            InfoRow('الفواتير', '${c[1]}', icon: Icons.receipt_long_rounded),
            InfoRow('الخطوط المباعة', '${c[2]}', icon: Icons.sim_card_rounded),
            InfoRow('أجهزة الصيانة', '${c[3]}', icon: Icons.build_circle_rounded),
            InfoRow('الديون', '${c[4]}', icon: Icons.menu_book_rounded),
            InfoRow('المستخدمون', '${c[5]}', icon: Icons.group_rounded),
          ]),
        ),
      ),
    ]);
  }
}

// =====================================================================
// الاشتراك (للمدير/المزوّد)
// =====================================================================

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});
  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final _code = TextEditingController();
  late final _contact = TextEditingController(text: _s.get('provider_contact', defaultProviderContact));
  bool _busy = false;

  LicenseService get lic => LicenseService.instance;

  Future<void> _renew() async {
    setState(() => _busy = true);
    final ok = await lic.activate(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _code.clear();
      toast(context, 'تم تمديد الاشتراك حتى ${dateMs(lic.expiryMs)}');
    } else {
      toast(context, 'الكود غير صحيح أو لا يخص هذا الجهاز', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: lic,
      builder: (context, _) {
        final (label, color) = switch (lic.status) {
          LicenseStatus.active => ('مفعّل', AppColors.success),
          LicenseStatus.expired => ('منتهٍ', AppColors.danger),
          LicenseStatus.notActivated => ('غير مفعّل', AppColors.warning),
        };
        return _Page(title: 'الاشتراك', children: [
          AppCard(
            borderColor: color.withValues(alpha: .4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                IconBadge(icon: Icons.workspace_premium_rounded, color: color, size: 50),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('حالة الاشتراك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
                  ]),
                ),
                if (lic.status == LicenseStatus.active) Pill('باقي ${lic.daysLeft} يوم', color: color),
              ]),
              const Divider(height: 24),
              InfoRow('رمز الجهاز', lic.deviceIdShown, icon: Icons.fingerprint_rounded, bold: true),
              if (lic.expiryDate != null) InfoRow('ينتهي بتاريخ', dateMs(lic.expiryMs), icon: Icons.event_busy_rounded),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: lic.deviceIdShown));
                  toast(context, 'تم نسخ رمز الجهاز');
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ رمز الجهاز'),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('تجديد / تمديد الاشتراك', subtitle: 'أدخل كود التفعيل الذي زوّدك به المطوّر'),
              TextField(
                controller: _code,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2),
                inputFormatters: [_SubCodeFormatter()],
                decoration: const InputDecoration(hintText: 'XXXXX-XXXXX', hintTextDirection: TextDirection.ltr, prefixIcon: Icon(Icons.vpn_key_rounded)),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _renew,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('تفعيل الكود'),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('رقم المزوّد', subtitle: 'يظهر في شاشة التفعيل ليتواصل معك صاحب المحل'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _contact,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف / واتساب', prefixIcon: Icon(Icons.call_rounded)),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () async {
                    await _s.set('provider_contact', _contact.text.trim());
                    if (context.mounted) toast(context, 'تم الحفظ');
                  },
                  child: const Text('حفظ'),
                ),
              ]),
            ]),
          ),
        ]);
      },
    );
  }
}

class _SubCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final clean = normalizeCode(newValue.text);
    final limited = clean.length > 10 ? clean.substring(0, 10) : clean;
    final text = limited.length > 5 ? '${limited.substring(0, 5)}-${limited.substring(5)}' : limited;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
