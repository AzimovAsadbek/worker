import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/api/api_error.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('uz');
  runApp(
    ProviderScope(
      // Retry only transient failures (no network / 5xx); never hammer the API on 4xx.
      retry: (count, error) {
        if (count >= 4) return null;
        final e = ApiError.from(error);
        return e.isTransient ? Duration(seconds: 2 << count) : null;
      },
      child: const WorkerOsApp(),
    ),
  );
}
