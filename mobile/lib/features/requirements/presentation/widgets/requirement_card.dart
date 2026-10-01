import 'package:flutter/material.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';
import 'package:taskinspect/features/tasks/presentation/widgets/requirement_type_icon.dart';

/// One requirement on the execution screen: what to do, and the input to
/// answer it ([input]; the inputs per type come in tasks 5.9–5.11).
class RequirementCard extends StatelessWidget {
  const RequirementCard({required this.requirement, this.input, super.key});

  final Requirement requirement;
  final Widget? input;

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
        ],
      ),
    );
  }
}
