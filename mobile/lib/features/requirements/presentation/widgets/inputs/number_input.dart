import 'package:flutter/material.dart';

/// NUMBER: a number with an optional unit (e.g. °C). A decimal comma is
/// accepted as well as a point.
class NumberInput extends StatefulWidget {
  const NumberInput({required this.value, required this.onChanged, this.unit, super.key});

  final num? value;
  final String? unit;

  /// Called with the number, or `null` when the field is empty or invalid.
  final ValueChanged<num?> onChanged;

  /// Parses user input like `3.5`, `3,5` or `-2`; `null` if it isn't a number.
  static num? parse(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    final number = num.tryParse(normalized);
    return number == null || number.isNaN || number.isInfinite ? null : number;
  }

  @override
  State<NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<NumberInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.value?.toString());
  bool _invalid = false;

  @override
  void didUpdateWidget(NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != NumberInput.parse(_controller.text)) {
      _controller.text = widget.value?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('number-input'),
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(
        hintText: 'Enter a value',
        suffixText: widget.unit,
        errorText: _invalid ? 'Enter a number' : null,
      ),
      onChanged: (text) {
        final number = NumberInput.parse(text);
        setState(() => _invalid = text.trim().isNotEmpty && number == null);
        widget.onChanged(number);
      },
    );
  }
}
