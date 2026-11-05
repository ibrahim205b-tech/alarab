import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';
import 'core/widgets.dart';
import 'data/db.dart';
import 'data/repos/settings_repo.dart';
import 'data/repos/users_repo.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/setup_screen.dart';
import 'features/license/lock_screen.dart';
import 'features/shell/shell.dart';
import 'services/license.dart';
import 'services/session.dart';
import 'services/telegram.dart';

class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();
  ThemeMode get mode => SettingsRepo.instance.get('theme', 'dark') == 'light' ? ThemeMode.light : ThemeMode.dark;
  Future<void> toggle() async {
    await SettingsRepo.instance.set('theme', mode == ThemeMode.dark ? 'light' : 'dark');
    notifyListeners();
  }
}

class AlarabApp extends StatelessWidget {
  final Object? startupError;
  const AlarabApp({super.key, this.startupError});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        title: 'مبيعات علي العراب',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: startupError != null ? ThemeMode.dark : ThemeController.instance.mode,
        locale: const Locale('ar', 'IQ'),
        supportedLocales: const [Locale('ar', 'IQ'), Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          // منع تكبير الخط المبالغ فيه من إعدادات الجهاز حتى لا تنكسر الواجهة
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
          ),
          child: child!,
        ),
        home: startupError != null
            ? Scaffold(
                body: EmptyState(
                  icon: Icons.storage_rounded,
                  title: 'تعذر فتح قاعدة البيانات',
                  message: startupError.toString(),
                ),
              )
            : const LicenseGate(child: AuthGate()),
      ),
    );
  }
}

/// بوابة الاشتراك: تعرض شاشة القفل إذا لم يكن مفعّلاً أو انتهت المدة،
/// وإلا تعرض البرنامج. تُعيد الفحص عند عودة التطبيق للمقدمة.
class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});
  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LicenseService.instance.touch();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LicenseService.instance,
      builder: (context, _) {
        final locked = !LicenseService.instance.unlocked;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          switchInCurve: Curves.easeOutCubic,
          child: locked ? const LockScreen(key: ValueKey('lock')) : KeyedSubtree(key: const ValueKey('app'), child: widget.child),
        );
      },
    );
  }
}

/// يحدد الشاشة: إعداد أول مرة ← تسجيل الدخول ← البرنامج
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool? _hasAdmin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Session.instance.addListener(_onSession);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Session.instance.removeListener(_onSession);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) TelegramService.instance.flush();
  }

  void _onSession() {
    _check();
  }

  Future<void> _check() async {
    if (!AppDb.instance.isOpen) return;
    final has = await UsersRepo.hasAdmin();
    if (mounted) setState(() => _hasAdmin = has);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_hasAdmin == null) {
      child = const Scaffold(key: ValueKey('loading'), body: Center(child: CircularProgressIndicator()));
    } else if (!_hasAdmin!) {
      child = SetupScreen(key: const ValueKey('setup'), onDone: _check);
    } else if (!Session.instance.loggedIn) {
      child = const LoginScreen(key: ValueKey('login'));
    } else {
      child = HomeShell(key: ValueKey('shell-${Session.instance.user!.id}'));
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (c, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: c),
      ),
      child: child,
    );
  }
}
