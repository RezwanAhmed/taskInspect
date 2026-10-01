import 'package:flutter/material.dart';
import 'package:taskinspect/features/tasks/domain/entities/requirement.dart';

/// DROPDOWN: choose exactly one option. Shown as radio buttons, which are
/// easier to tap on a phone than a drop-down menu.
class SingleChoiceInput extends StatelessWidget {
  const SingleChoiceInput({required this.options, required this.selectedId, required this.onChanged, super.key});

  final List<RequirementOption> options;
  final String? selectedId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: RadioGroup<String>(
        groupValue: selectedId,
        onChanged: (id) {
          if (id != null) {
            onChanged(id);
          }
        },
        child: Column(
          children: [
            for (final option in options)
              RadioListTile<String>(key: Key('option-${option.id}'), value: option.id, title: Text(option.label)),
          ],
        ),
      ),
    );
  }
}
