import 'package:flutter/material.dart';

/// CHECKBOX: the worker ticks the item off.
class CheckboxInput extends StatelessWidget {
  const CheckboxInput({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: CheckboxListTile(
        key: const Key('checkbox-input'),
        value: value,
        onChanged: (checked) => onChanged(checked ?? false),
        title: const Text('Done'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
