import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/brand.dart';
import '../../core/license_crypto.dart';
import '../../core/theme.dart';
import '../../core/version.dart';
import '../../core/widgets.dart';
import '../../services/contact.dart';
import '../../services/license.dart';

/// شاشة قفل الاشتراك: تظهر عند عدم التفعيل أو انتهاء المدة.
/// البيانات تبقى محفوظة — يكفي إدخال كود التفعيل للمتابعة.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  LicenseService get lic => LicenseService.instance;

  Future<void> _activate() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await lic.activate(_code.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      HapticFeedback.heavyImpact();
      toast(context, 'تم تفعيل الاشتراك ✓ شكراً لك');
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _error = 'الكود غير صحيح أو لا يخص هذا الجهاز');
    }
  }

  @override
  Widget build(BuildContext context) {
    final expired = lic.status == LicenseStatus.expired;
    final trialEnded = lic.trialEnded;
    const contact = defaultProviderContact;
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(children: [
                  const BrandMark(size: 88),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: (expired ? AppColors.danger : AppColors.warning).withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: (expired ? AppColors.danger : AppColors.warning).withValues(alpha: .5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(expired ? Icons.lock_clock_rounded : Icons.lock_rounded,
                          color: expired ? AppColors.danger : AppColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Text(trialEnded ? 'انتهت النسخة التجريبية' : expired ? 'انتهت فترة الاشتراك' : 'البرنامج غير مفعّل',
                          style: TextStyle(fontWeight: FontWeight.w800, color: expired ? AppColors.danger : AppColors.warning)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text(
                        trialEnded
                            ? 'انتهى اليوم المجاني التجريبي. بياناتك محفوظة بالكامل ولم تُحذف. للاشتراك والمتابعة أدخل كود التفعيل.'
                            : expired
                                ? 'انتهت مدة الاشتراك. بياناتك محفوظة بالكامل ولم تُحذف. للتجديد والمتابعة أدخل كود التفعيل.'
                                : 'لتشغيل البرنامج أدخل كود التفعيل. أرسل رمز الجهاز أدناه إلى المزوّد ليعطيك الكود.',
                        style: TextStyle(color: context.cs.onSurfaceVariant, height: 1.5),
                      ),
                      const SizedBox(height: 18),
                      Text('رمز الجهاز', style: TextStyle(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      Pressable(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: lic.deviceIdShown));
                          toast(context, 'تم نسخ رمز الجهاز');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: context.cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.cs.outline),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Text(lic.deviceIdShown,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                            ),
                            Icon(Icons.copy_rounded, size: 20, color: context.cs.onSurfaceVariant),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _code,
                        textAlign: TextAlign.center,
                        textCapitalization: TextCapitalization.characters,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2),
                        inputFormatters: [_CodeFormatter()],
                        onSubmitted: (_) => _activate(),
                        decoration: InputDecoration(
                          hintText: 'XXXXX-XXXXX',
                          hintTextDirection: TextDirection.ltr,
                          labelText: 'كود التفعيل',
                          prefixIcon: const Icon(Icons.vpn_key_rounded),
                          errorText: _error,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ? null : _activate,
                        icon: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : const Icon(Icons.lock_open_rounded),
                        label: const Text('تفعيل'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  if (contact.isNotEmpty)
                    AppCard(
                      onTap: Contact.valid(contact) ? () => Contact.whatsapp(contact, 'السلام عليكم، أريد كود تفعيل.\nرمز الجهاز: ${lic.deviceIdShown}') : null,
                      child: Row(children: [
                        const IconBadge(icon: Icons.support_agent_rounded, color: AppColors.gold, size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('للتفعيل والتجديد تواصل مع المزوّد', style: TextStyle(fontWeight: FontWeight.w800)),
                            Text(contact, textDirection: TextDirection.ltr, style: TextStyle(color: context.cs.primary, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        if (Contact.valid(contact)) const Icon(Icons.chat_rounded, color: Color(0xFF25D366)),
                      ]),
                    ),
                  const SizedBox(height: 20),
                  Text(developerName, style: TextStyle(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                  Text('الإصدار $appVersion', style: TextStyle(color: context.cs.onSurfaceVariant.withValues(alpha: .7), fontSize: 12)),
                ]).animate().fadeIn(duration: 450.ms).slideY(begin: .06, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// تنسيق كود التفعيل أثناء الكتابة: حروف كبيرة وفاصلة بعد 5 رموز
class _CodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final clean = normalizeCode(newValue.text);
    final limited = clean.length > 10 ? clean.substring(0, 10) : clean;
    final text = limited.length > 5 ? '${limited.substring(0, 5)}-${limited.substring(5)}' : limited;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
