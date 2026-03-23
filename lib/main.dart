import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/admin_central_app.dart';
import 'firebase_options.dart';

const _webRecaptchaSiteKey = '6LfIPn0sAAAAAFWocbrWw45vJK51l0006z_DEkf5';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await FirebaseAppCheck.instance
        .activate(providerWeb: ReCaptchaV3Provider(_webRecaptchaSiteKey))
        .timeout(const Duration(seconds: 12));
  } on TimeoutException {
    debugPrint('App Check timeout en inicialización web.');
  } catch (e) {
    debugPrint('App Check init error: $e');
  }

  runApp(const ProviderScope(child: AdminCentralApp()));
}
