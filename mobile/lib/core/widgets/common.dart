import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_error.dart';
import '../l10n/strings.dart';
import '../theme.dart';

/// Renders loading / error (with retry) / empty / data for any AsyncValue.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry, this.isEmpty, this.empty});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final bool Function(T data)? isEmpty;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    // Keep showing data while refreshing (no flashing spinners on pull-to-refresh).
    if (value.hasValue) {
      final data = value.requireValue;
      if (isEmpty != null && isEmpty!(data) && empty != null) return empty!;
      return builder(data);
    }
    if (value.hasError) return ErrorView(error: value.error!, onRetry: onRetry);
    return const LoadingView();
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(label ?? S.loading, style: const TextStyle(color: AppColors.muted)),
        ]),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final e = ApiError.from(error);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(e.isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(e.message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text(S.retry)),
          ],
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action, this.onAction});
  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            ],
            if (action != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add), label: Text(action!)),
            ],
          ]),
        ),
      );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = AppColors.muted, this.icon});
  final String label;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );
}

Color shiftStatusColor(String s) => switch (s) {
      'OPEN' => AppColors.primary,
      'CLOSED' => AppColors.warning,
      'NEEDS_REVIEW' => AppColors.danger,
      'VERIFIED' => AppColors.verified,
      'REJECTED' => AppColors.danger,
      _ => AppColors.muted,
    };

Color taskStatusColor(String s) => switch (s) {
      'APPROVED' => AppColors.verified,
      'SUBMITTED' => AppColors.warning,
      'CHANGES_REQUESTED' || 'REJECTED' => AppColors.danger,
      'IN_PROGRESS' => AppColors.primary,
      _ => AppColors.muted,
    };

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ]),
      );
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});
  final String label;
  final String value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[Icon(icon, size: 20, color: AppColors.muted), const SizedBox(width: 10)],
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color, this.onTap});
  final String value;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color ?? Colors.black87)),
              const SizedBox(height: 2),
              Text(label, maxLines: 2, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ]),
          ),
        ),
      );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : null, duration: Duration(seconds: error ? 5 : 3)));
}

Future<bool> confirmDialog(BuildContext context, {required String title, String? body, String confirm = S.confirm, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text(S.cancel)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger, minimumSize: const Size(0, 44)) : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Prompts for a required reason / comment. Returns null when cancelled.
Future<String?> promptText(BuildContext context, {required String title, String? hint, bool required = true, String confirm = S.confirm, int minLength = 3}) async {
  final ctrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(hintText: hint),
          validator: (v) => required && (v == null || v.trim().length < minLength) ? S.required : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text(S.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () {
            if (formKey.currentState!.validate()) Navigator.pop(c, ctrl.text.trim());
          },
          child: Text(confirm),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}

/// Runs an async action with a blocking progress indicator and a specific error message.
Future<T?> runAction<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  var dialogOpen = true;
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
  ).whenComplete(() => dialogOpen = false));
  try {
    final r = await action();
    if (dialogOpen) nav.pop();
    if (success != null && context.mounted) showSnack(context, success);
    return r;
  } catch (e) {
    if (dialogOpen) nav.pop();
    if (context.mounted) showSnack(context, ApiError.from(e).message, error: true);
    return null;
  }
}
