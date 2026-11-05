import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/widgets.dart';
import 'data/db.dart';
import 'data/repos/settings_repo.dart';
import 'data/repos/users_repo.dart';
import 'services/backup.dart';
import 'services/license.dart';
import 'services/telegram.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  Object? startupError;
  try {
    await AppDb.instance.open();
    await SettingsRepo.instance.load();
    AdminGate.verifier = (pin) async => await UsersRepo.verifyAnyAdmin(pin) != null;
    await LicenseService.instance.init();
    TelegramService.instance.startAutoRetry();
    unawaited(TelegramService.instance.flush());
    unawaited(BackupService.autoBackup());
  } catch (e) {
    startupError = e;
  }
  runApp(AlarabApp(startupError: startupError));
}
