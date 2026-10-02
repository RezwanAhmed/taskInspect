import 'package:flutter/material.dart';
import 'package:taskinspect/features/evidence/domain/evidence_item.dart';

/// DOCUMENT: choose PDF documents from the device's files. At least one
/// document answers the requirement.
class DocumentInput extends StatelessWidget {
  const DocumentInput({
    required this.documents,
    required this.onChoose,
    required this.onOpen,
    required this.onRemove,
    this.readOnly = false,
    super.key,
  });

  final List<EvidenceItem> documents;
  final VoidCallback onChoose;
  final ValueChanged<EvidenceItem> onOpen;
  final ValueChanged<EvidenceItem> onRemove;

  /// Documents can be opened but not added or removed (e.g. not marked for
  /// correction). Otherwise any document can be removed, also an uploaded
  /// one (the removal is sent to the server).
  final bool readOnly;

  static String sizeLabel(int bytes) =>
      bytes < 1024 * 1024 ? '${(bytes / 1024).ceil()} KB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, document) in documents.indexed)
          Card(
            key: Key('document-$index'),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(document.fileName ?? 'Document', maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(sizeLabel(document.sizeBytes)),
              onTap: () => onOpen(document),
              trailing: readOnly
                  ? null
                  : IconButton(
                      key: Key('remove-document-$index'),
                      tooltip: 'Remove document',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onRemove(document),
                    ),
            ),
          ),
        if (!readOnly) ...[
          if (documents.isNotEmpty) const SizedBox(height: 4),
          OutlinedButton.icon(
            key: const Key('choose-document'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: onChoose,
            icon: const Icon(Icons.upload_file),
            label: Text(documents.isEmpty ? 'Choose PDF' : 'Add another PDF'),
          ),
          const SizedBox(height: 4),
          Text('PDF only, up to 20 MB', style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
