import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:taskinspect/core/di/injection.dart';
import 'package:taskinspect/features/evidence/presentation/pages/evidence_preview_page.dart';
import 'package:taskinspect/features/requirements/presentation/cubit/execution_cubit.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/comment_field.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/document_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/inputs/photo_input.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/requirement_card.dart';
import 'package:taskinspect/features/requirements/presentation/widgets/requirement_input.dart';
import 'package:taskinspect/features/tasks/domain/entities/task_enums.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/requirement_type_icon.dart';

/// Requirement-by-requirement execution of a task (spec: "Task Execution").
class ExecutionPage extends StatelessWidget {
  const ExecutionPage({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExecutionCubit(getIt(), getIt(), getIt(), getIt(), getIt(), taskId),
      child: const _ExecutionView(),
    );
  }
}

class _ExecutionView extends StatefulWidget {
  const _ExecutionView();

  @override
  State<_ExecutionView> createState() => _ExecutionViewState();
}

class _ExecutionViewState extends State<_ExecutionView> {
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<bool> _confirmRemoveDocument(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this document?'),
        content: const Text('It will be deleted from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showChecklist(BuildContext context, ExecutionState state) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final (i, requirement) in state.requirements.indexed)
              ListTile(
                leading: Icon(RequirementTypeLook.icon(requirement.type)),
                title: Text(requirement.title),
                trailing: state.isComplete(requirement)
                    ? const Icon(Icons.check_circle, color: Colors.green, semanticLabel: 'Answered')
                    : null,
                selected: i == state.index,
                onTap: () => Navigator.pop(sheetContext, i),
              ),
          ],
        ),
      ),
    );
    if (chosen != null && context.mounted) {
      context.read<ExecutionCubit>().goTo(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExecutionCubit, ExecutionState>(
      listenWhen: (previous, current) =>
          previous.index != current.index ||
          (current.evidenceError != null && previous.evidenceError != current.evidenceError),
      listener: (context, state) {
        if (state.evidenceError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.evidenceError!)));
        }
        if (_pages.hasClients && _pages.page?.round() != state.index) {
          _pages.animateToPage(state.index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      },
      builder: (context, state) {
        final cubit = context.read<ExecutionCubit>();
        final total = state.requirements.length;
        return Scaffold(
          appBar: AppBar(
            title: Text(state.task?.title ?? 'Task', overflow: TextOverflow.ellipsis),
            actions: [
              if (total > 0)
                IconButton(
                  tooltip: 'All requirements',
                  icon: const Icon(Icons.checklist),
                  onPressed: () => _showChecklist(context, state),
                ),
            ],
            bottom: total == 0
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(28),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Requirement ${state.index + 1} of $total · ${state.completedCount} answered'),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: (state.index + 1) / total),
                        ],
                      ),
                    ),
                  ),
          ),
          body: switch ((state.isLoading, total)) {
            (true, _) => const Center(child: CircularProgressIndicator()),
            (false, 0) => const Center(child: Text('This task has no requirements.')),
            _ => PageView.builder(
                controller: _pages,
                itemCount: total,
                onPageChanged: cubit.goTo,
                itemBuilder: (context, index) {
                  final requirement = state.requirements[index];
                  final answer = state.answerFor(requirement);
                  return RequirementCard(
                    requirement: requirement,
                    // A COMMENT requirement's answer already is a comment.
                    comment: requirement.type == RequirementType.comment
                        ? null
                        : CommentField(
                            key: ValueKey('comment-${requirement.id}'),
                            value: answer.comment,
                            onChanged: (text) => cubit.answer(requirement, (a) => a.copyWith(comment: () => text)),
                          ),
                    input: switch (requirement.type) {
                      RequirementType.photo => PhotoInput(
                          photoPaths: [for (final photo in state.evidenceFor(requirement)) photo.localPath],
                          onTakePhoto: () => cubit.addPhoto(requirement, fromCamera: true),
                          onChoosePhoto: () => cubit.addPhoto(requirement, fromCamera: false),
                          onOpenPhoto: (photoIndex) async {
                            final photo = state.evidenceFor(requirement)[photoIndex];
                            if (await EvidencePreviewPage.show(context, photo)) {
                              await cubit.removeEvidence(photo);
                            }
                          },
                        ),
                      RequirementType.document => DocumentInput(
                          documents: state.evidenceFor(requirement),
                          onChoose: () => cubit.addDocument(requirement),
                          onOpen: cubit.openDocument,
                          onRemove: (document) async {
                            if (await _confirmRemoveDocument(context)) {
                              await cubit.removeEvidence(document);
                            }
                          },
                        ),
                      _ => requirementInput(
                          requirement: requirement,
                          answer: answer,
                          onChanged: (update) => cubit.answer(requirement, update),
                        ),
                    },
                  );
                },
              ),
          },
          bottomNavigationBar: total == 0
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: state.isFirst ? null : cubit.previous,
                          icon: const Icon(Icons.chevron_left),
                          label: const Text('Previous'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
                          onPressed: state.isLast ? null : cubit.next,
                          icon: const Icon(Icons.chevron_right),
                          label: const Text('Next'),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
