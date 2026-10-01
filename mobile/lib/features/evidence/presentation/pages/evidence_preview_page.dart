import 'dart:io';

import 'package:flutter/material.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';

/// Full-screen view of one photo with zoom. Returns `true` when the worker
/// chose to remove it.
class EvidencePreviewPage extends StatelessWidget {
  const EvidencePreviewPage({required this.item, super.key});

  final EvidenceItem item;

  static Future<bool> show(BuildContext context, EvidenceItem item) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EvidencePreviewPage(item: item), fullscreenDialog: true),
    );
    return removed ?? false;
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this photo?'),
        content: const Text('It will be deleted from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    if ((confirmed ?? false) && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kilobytes = (item.sizeBytes / 1024).ceil();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Photo · $kilobytes KB'),
        actions: [
          if (!item.uploaded)
            IconButton(
              key: const Key('remove-evidence'),
              tooltip: 'Remove photo',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmRemove(context),
            ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(
            File(item.localPath),
            errorBuilder: (context, error, stack) =>
                const Icon(Icons.broken_image_outlined, color: Colors.white, size: 64),
          ),
        ),
      ),
    );
  }
}
