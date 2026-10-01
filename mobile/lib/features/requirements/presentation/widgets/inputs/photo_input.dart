import 'dart:io';

import 'package:flutter/material.dart';

/// PHOTO: take a photo with the camera or choose one from the gallery.
/// At least one photo answers the requirement.
class PhotoInput extends StatelessWidget {
  const PhotoInput({
    required this.photoPaths,
    required this.onTakePhoto,
    required this.onChoosePhoto,
    this.onOpenPhoto,
    this.readOnly = false,
    super.key,
  });

  final List<String> photoPaths;
  final VoidCallback onTakePhoto;
  final VoidCallback onChoosePhoto;

  /// Opens the photo at this index full screen (preview / remove).
  final ValueChanged<int>? onOpenPhoto;

  /// Photos can be viewed but not added (e.g. not marked for correction).
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photoPaths.isNotEmpty) ...[
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photoPaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => InkWell(
                key: Key('photo-$index'),
                onTap: onOpenPhoto == null ? null : () => onOpenPhoto!(index),
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(photoPaths[index]),
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  cacheWidth: 192,
                  errorBuilder: (context, error, stack) => Container(
                    width: 96,
                    height: 96,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!readOnly)
          Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('take-photo'),
                onPressed: onTakePhoto,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Take photo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('choose-photo'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: onChoosePhoto,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Gallery'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
