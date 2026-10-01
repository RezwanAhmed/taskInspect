import 'package:flutter/material.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/requirement_type_icon.dart';

/// One requirement on the execution screen: what to do, the [input] to
/// answer it and an optional [comment] field.
class RequirementCard extends StatelessWidget {
  const RequirementCard({required this.requirement, this.input, this.comment, super.key});

  final Requirement requirement;
  final Widget? input;
  final Widget? comment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(RequirementTypeLook.icon(requirement.type), color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(RequirementTypeLook.label(requirement.type), style: theme.textTheme.labelLarge),
              const Spacer(),
              Text(
                requirement.required ? 'Required' : 'Optional',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: requirement.required ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(requirement.title, style: theme.textTheme.headlineSmall),
          if (requirement.description != null) ...[
            const SizedBox(height: 8),
            Text(requirement.description!, style: theme.textTheme.bodyLarge),
          ],
          const SizedBox(height: 24),
          input ??
              Container(
                key: const Key('input-placeholder'),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Answer input', textAlign: TextAlign.center),
              ),
          if (comment != null) ...[const SizedBox(height: 16), comment!],
        ],
      ),
    );
  }
}
