import 'package:flutter/material.dart';

/// TEXT and COMMENT: free text over several lines.
class TextAnswerInput extends StatefulWidget {
  const TextAnswerInput({required this.value, required this.onChanged, this.hint = 'Your answer', super.key});

  final String? value;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<TextAnswerInput> createState() => _TextAnswerInputState();
}

class _TextAnswerInputState extends State<TextAnswerInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(TextAnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only take over outside changes, never overwrite what is being typed.
    if ((widget.value ?? '') != _controller.text && widget.value != oldWidget.value) {
      _controller.text = widget.value ?? '';
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
      key: const Key('text-input'),
      controller: _controller,
      minLines: 3,
      maxLines: 8,
      maxLength: 5000,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: widget.hint),
      onChanged: widget.onChanged,
    );
  }
}
