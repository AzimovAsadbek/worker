import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/strings.dart';
import 'core/theme.dart';
import 'router.dart';

class WorkerOsApp extends ConsumerWidget {
  const WorkerOsApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: S.appName,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('uz'),
      supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      // Large system fonts are respected but capped so layouts stay usable.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.4)), child: child!);
      },
    );
  }
}
