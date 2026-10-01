import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/core/error/result.dart';
import 'package:taskinspect/features/review/domain/submission.dart';
import 'package:taskinspect/features/review/presentation/answer_text.dart';
import 'package:taskinspect/features/review/presentation/cubit/review_cubit.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/requirement_type_icon.dart';

/// What the worker submitted, for the reviewer (spec "Review": task
/// information, every requirement, submitted responses, evidence and
/// comments). Needs a connection: the answers and files come from the
/// server.
class ReviewPage extends StatelessWidget {
  const ReviewPage({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReviewCubit(getIt(), getIt(), getIt(), taskId),
      child: BlocConsumer<ReviewCubit, ReviewState>(
        listenWhen: (previous, current) => current.message != null && previous.message != current.message,
        listener: (context, state) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
          context.read<ReviewCubit>().clearMessage();
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Review')),
            body: switch (state) {
              ReviewState(isLoading: true) => const Center(child: CircularProgressIndicator()),
              ReviewState(error: final error?) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(state.canRetry ? Icons.cloud_off : Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text(error, key: const Key('review-error'), textAlign: TextAlign.center),
                        if (state.canRetry) ...[
                          const SizedBox(height: 12),
                          FilledButton(onPressed: context.read<ReviewCubit>().load, child: const Text('Retry')),
                        ],
                      ],
                    ),
                  ),
                ),
              _ => _Submission(state: state),
            },
          );
        },
      ),
    );
  }
}

class _Submission extends StatelessWidget {
  const _Submission({required this.state});

  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submission = state.submission ?? const Submission();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.task != null) ...[
          Text(state.task!.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Submitted by ${state.task!.assignee?.name ?? 'the worker'}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],
        for (final requirement in state.requirements)
          _RequirementResult(
            requirement: requirement,
            answer: describeAnswer(requirement, submission.answers[requirement.id]),
            comment: submission.answers[requirement.id]?.comment,
            files: submission.files[requirement.id] ?? const [],
          ),
      ],
    );
  }
}

class _RequirementResult extends StatelessWidget {
  const _RequirementResult({required this.requirement, required this.answer, this.comment, required this.files});

  final Requirement requirement;
  final String answer;
  final String? comment;
  final List<SubmittedFile> files;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photos = files.where((f) => f.isPhoto).toList();
    final documents = files.where((f) => !f.isPhoto).toList();
    return Card(
      key: Key('result-${requirement.id}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(RequirementTypeLook.icon(requirement.type), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(requirement.title, style: theme.textTheme.titleMedium)),
              ],
            ),
            if (answer.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(answer, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
            if (requirement.type.isEvidence && files.isEmpty) ...[
              const SizedBox(height: 8),
              const Text('No file'),
            ],
            if (photos.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final photo in photos) _RemotePhoto(photo)]),
            ],
            for (final document in documents)
              ListTile(
                key: Key('document-${document.id}'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(document.fileName),
                trailing: context.select((ReviewCubit cubit) => cubit.state.opening.contains(document.id))
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.open_in_new),
                onTap: () => context.read<ReviewCubit>().openFile(document),
              ),
            if (comment != null && comment!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Comment: ${comment!.trim()}', style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

/// A submitted photo, loaded from its signed URL; tap to see it large.
class _RemotePhoto extends StatelessWidget {
  const _RemotePhoto(this.file);

  final SubmittedFile file;

  @override
  Widget build(BuildContext context) {
    const size = 96.0;
    return FutureBuilder<Result<String>>(
      key: Key('photo-${file.id}'),
      future: context.read<ReviewCubit>().photoUrl(file),
      builder: (context, snapshot) {
        final url = switch (snapshot.data) {
          Ok(:final value) => value,
          _ => null,
        };
        final cubit = context.read<ReviewCubit>();
        final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
        final Widget image = switch ((snapshot.connectionState, url)) {
          (ConnectionState.done, final String url) => Image.network(
              url,
              fit: BoxFit.cover,
              // Decoded at the thumbnail's size, not the photo's full size.
              cacheWidth: pixels,
              errorBuilder: (context, error, stack) {
                // e.g. the URL expired: a new one next time.
                cubit.forgetPhotoUrl(file);
                return const Icon(Icons.broken_image_outlined);
              },
            ),
          (ConnectionState.done, null) => const Icon(Icons.broken_image_outlined),
          _ => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        };
        return InkWell(
          onTap: url == null
              ? null
              : () async {
                  // A fresh URL if the cached one is about to expire.
                  final fresh = await cubit.photoUrl(file);
                  if (fresh case Ok(:final value) when context.mounted) {
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => Dialog(
                        child: Stack(
                          children: [
                            InteractiveViewer(child: Image.network(value, fit: BoxFit.contain)),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: IconButton.filledTonal(
                                tooltip: 'Close',
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.pop(dialogContext),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox.square(
              dimension: size,
              child: Semantics(label: file.fileName, hint: 'Opens the photo larger', button: true, child: image),
            ),
          ),
        );
      },
    );
  }
}
