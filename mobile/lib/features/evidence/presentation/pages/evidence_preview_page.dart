import 'dart:io';

import 'package:flutter/material.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';

/// Full-screen view of one photo with zoom. Returns `true` when the worker
/// chose to remove it ([canRemove]: not while it stays as submitted during
/// a correction).
class EvidencePreviewPage extends StatelessWidget {
  const EvidencePreviewPage({required this.item, this.canRemove = true, super.key});

  final EvidenceItem item;
  final bool canRemove;

  static Future<bool> show(BuildContext context, EvidenceItem item, {bool canRemove = true}) async {
    final removed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EvidencePreviewPage(item: item, canRemove: canRemove),
        fullscreenDialog: true,
      ),
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
          // Also an uploaded photo: e.g. replaced during a correction (the
          // removal is sent to the server).
          if (canRemove)
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
