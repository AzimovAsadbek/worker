import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/location/location_service.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/common.dart';
import '../../data/repository.dart';
import '../../models/models.dart';
import 'company_providers.dart';

class SitesScreen extends ConsumerWidget {
  const SitesScreen({super.key, this.onboarding = false});
  final bool onboarding;

  Future<void> _newProject(BuildContext context, WidgetRef ref) async {
    final name = await promptText(context, title: S.createProject, hint: S.projectName, confirm: S.save, minLength: 2);
    if (name == null || !context.mounted) return;
    await runAction(context, () => ref.read(repoProvider).createProject(cidFrom(ref), {'name': name}), success: 'Loyiha yaratildi');
    ref.invalidate(projectsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final sites = ref.watch(companySitesProvider);
    final isMgmt = ref.watch(activeMembershipProvider)?.isManagement ?? false;
    return Scaffold(
      appBar: AppBar(title: Text('${S.projects} va ${S.sites.toLowerCase()}')),
      floatingActionButton: isMgmt ? FloatingActionButton.extended(onPressed: () => _newProject(context, ref), icon: const Icon(Icons.add), label: const Text(S.createProject)) : null,
      body: AsyncBody(
        value: projects,
        onRetry: () => ref.invalidate(projectsProvider),
        isEmpty: (p) => p.isEmpty,
        empty: EmptyState(
          icon: Icons.apartment_outlined,
          title: onboarding ? 'Kompaniya yaratildi!' : S.noSites,
          body: 'Endi birinchi loyiha va obyektni yarating. Keyin prorab va ishchilarni qo\'shasiz.',
          action: isMgmt ? S.createProject : null,
          onAction: () => _newProject(context, ref),
        ),
        builder: (list) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companySitesProvider);
            ref.invalidate(projectsProvider);
            await ref.read(projectsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              for (final p in list) ...[
                SectionTitle(
                  p.name,
                  trailing: isMgmt
                      ? TextButton.icon(
                          onPressed: () async {
                            await context.push('/company/more/sites/new?projectId=${p.id}');
                            ref.invalidate(companySitesProvider);
                            ref.invalidate(projectsProvider);
                          },
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text(S.createSite),
                        )
                      : null,
                ),
                ...(sites.value ?? const <CompanySite>[]).where((s) => s.projectId == p.id).map(
                      (s) => Card(
                        child: ListTile(
                          leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                          title: Text(s.info.name),
                          subtitle: Text('${s.info.shiftStart}–${s.info.shiftEnd} · radius ${s.info.radiusMeters} m\n${s.workerCount} ishchi · ${s.foremanCount} prorab'),
                          isThreeLine: true,
                        ),
                      ),
                    ),
                if (!(sites.value ?? const <CompanySite>[]).any((s) => s.projectId == p.id))
                  const Padding(padding: EdgeInsets.all(8), child: Text("Bu loyihada obyekt yo'q", style: TextStyle(color: AppColors.muted))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Site creation: the admin stands on the site and captures the coordinates (no map SDK / API key needed).
class SiteFormScreen extends ConsumerStatefulWidget {
  const SiteFormScreen({super.key, required this.projectId});
  final String projectId;
  @override
  ConsumerState<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends ConsumerState<SiteFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _radius = TextEditingController(text: '200');
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 18, minute: 0);
  bool _locating = false;
  double? _accuracy;

  @override
  void dispose() {
    for (final c in [_name, _address, _lat, _lng, _radius]) {
      c.dispose();
    }
    super.dispose();
  }

  String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _locate() async {
    setState(() => _locating = true);
    final r = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() => _locating = false);
    if (r is LocationOk) {
      setState(() {
        _lat.text = r.latitude.toStringAsFixed(6);
        _lng.text = r.longitude.toStringAsFixed(6);
        _accuracy = r.accuracy;
      });
    } else if (r is LocationFailed) {
      showSnack(context, r.message, error: true);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ok = await runAction(context, () async {
      await ref.read(repoProvider).createSite(cidFrom(ref), {
        'projectId': widget.projectId,
        'name': _name.text.trim(),
        if (_address.text.trim().isNotEmpty) 'address': _address.text.trim(),
        'latitude': double.parse(_lat.text),
        'longitude': double.parse(_lng.text),
        'radiusMeters': int.parse(_radius.text),
        'shiftStart': _hhmm(_start),
        'shiftEnd': _hhmm(_end),
      });
      return true;
    }, success: 'Obyekt yaratildi');
    if (ok == true && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    String? coord(String? v, double max) {
      final d = double.tryParse(v ?? '');
      return d == null || d.abs() > max ? S.required : null;
    }

    return Scaffold(
      appBar: AppBar(title: const Text(S.createSite)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: S.siteName, hintText: 'Blok A'), validator: (v) => (v?.trim().length ?? 0) < 2 ? S.required : null),
            const SizedBox(height: 12),
            TextFormField(controller: _address, decoration: const InputDecoration(labelText: '${S.address} (${S.optional})')),
            const SectionTitle('Joylashuv (geofence)'),
            FilledButton.tonalIcon(
              onPressed: _locating ? null : _locate,
              icon: _locating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.my_location),
              label: const Text(S.useCurrentLocation),
            ),
            if (_accuracy != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Aniqlik: ±${_accuracy!.round()} m', style: const TextStyle(color: AppColors.muted))),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _lat, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: S.latitude), validator: (v) => coord(v, 90))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(controller: _lng, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: const InputDecoration(labelText: S.longitude), validator: (v) => coord(v, 180))),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: _radius,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: S.radius, helperText: '20–5000 m. Katta obyekt uchun kattaroq radius.'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 20 || n > 5000 ? '20–5000' : null;
              },
            ),
            const SectionTitle('Ish vaqti'),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _start);
                    if (t != null) setState(() => _start = t);
                  },
                  child: Text('${S.shiftStart}: ${_hhmm(_start)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: _end);
                    if (t != null) setState(() => _end = t);
                  },
                  child: Text('${S.shiftEnd}: ${_hhmm(_end)}'),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text(S.save)),
          ],
        ),
      ),
    );
  }
}
