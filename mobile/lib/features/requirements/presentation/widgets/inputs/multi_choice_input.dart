import 'package:flutter/material.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';

/// MULTIPLE_SELECTION: choose any number of options (at least one to
/// answer).
class MultiChoiceInput extends StatelessWidget {
  const MultiChoiceInput({required this.options, required this.selectedIds, required this.onToggled, super.key});

  final List<RequirementOption> options;
  final List<String> selectedIds;

  /// Called when an option is ticked or unticked.
  final void Function(String optionId, bool checked) onToggled;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (final option in options)
            CheckboxListTile(
              key: Key('option-${option.id}'),
              value: selectedIds.contains(option.id),
              title: Text(option.label),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (checked) => onToggled(option.id, checked ?? false),
            ),
        ],
      ),
    );
  }
}
