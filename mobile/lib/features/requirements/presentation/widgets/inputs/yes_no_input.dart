import 'package:flutter/material.dart';

/// YES_NO: two large buttons; nothing is selected until the worker answers.
class YesNoInput extends StatelessWidget {
  const YesNoInput({required this.value, required this.onChanged, super.key});

  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      key: const Key('yes-no-input'),
      emptySelectionAllowed: true,
      segments: const [
        ButtonSegment(value: true, label: Text('Yes'), icon: Icon(Icons.check)),
        ButtonSegment(value: false, label: Text('No'), icon: Icon(Icons.close)),
      ],
      selected: {?value},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          onChanged(selection.first);
        }
      },
      style: SegmentedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
    );
  }
}
