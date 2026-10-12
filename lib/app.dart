import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Di web/desktop Flutter tidak menggeser list dengan drag mouse secara default,
/// sehingga list (dan baris chip horizontal) terasa macet di Chrome. Izinkan semua perangkat.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

class MposApp extends ConsumerWidget {
  const MposApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'mPOS Distributor',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

/// Ditampilkan bila firebase_options.dart masih placeholder.
class FirebaseSetupApp extends StatelessWidget {
  const FirebaseSetupApp({super.key, this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  const Icon(Icons.cloud_off, size: 48),
                  Text('Firebase belum dikonfigurasi', style: Theme.of(context).textTheme.titleLarge),
                  const SelectableText(
                    'Jalankan di folder project:\n\n'
                    'npm install -g firebase-tools\n'
                    'firebase login\n'
                    'dart pub global activate flutterfire_cli\n'
                    'flutterfire configure --project=mpos-da4b9\n\n'
                    'Lalu jalankan ulang aplikasi.',
                  ),
                  if (error != null) Text('Detail: $error', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
