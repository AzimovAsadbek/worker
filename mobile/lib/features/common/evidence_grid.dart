import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../models/models.dart';

/// Evidence thumbnails. Files are private: they are streamed by the API with the user's token.
class EvidenceGrid extends ConsumerWidget {
  const EvidenceGrid({super.key, required this.evidence});
  final List<EvidenceRef> evidence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (evidence.isEmpty) return const Text("Hali rasm yo'q", style: TextStyle(color: AppColors.muted));
    final repo = ref.read(repoProvider);
    final headers = ref.read(apiProvider).authHeaders;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final e in evidence)
          GestureDetector(
            onTap: e.isImage
                ? () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        insetPadding: const EdgeInsets.all(8),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          InteractiveViewer(child: Image.network(repo.evidenceUrl(e.id), headers: headers)),
                          Padding(padding: const EdgeInsets.all(8), child: Text([e.comment, fmtDateTime(e.createdAt)].whereType<String>().join(' · '))),
                        ]),
                      ),
                    )
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: e.isImage
                  ? Image.network(
                      repo.evidenceUrl(e.id),
                      headers: headers,
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE3E8EF), child: Icon(Icons.broken_image_outlined)),
                      loadingBuilder: (c, child, p) => p == null ? child : const ColoredBox(color: Color(0xFFE3E8EF)),
                    )
                  : const ColoredBox(color: Color(0xFFE3E8EF), child: Icon(Icons.picture_as_pdf_outlined, size: 36)),
            ),
          ),
      ],
    );
  }
}
