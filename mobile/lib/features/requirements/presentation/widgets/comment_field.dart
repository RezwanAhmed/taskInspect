import 'package:flutter/material.dart';

/// An optional comment on a requirement (spec: "Optional comment"). Hidden
/// behind a button until used, so it doesn't distract from the answer.
class CommentField extends StatefulWidget {
  const CommentField({required this.value, required this.onChanged, super.key});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<CommentField> createState() => _CommentFieldState();
}

class _CommentFieldState extends State<CommentField> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  late bool _open = (widget.value ?? '').isNotEmpty;

  @override
  void didUpdateWidget(CommentField oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('add-comment'),
          onPressed: () => setState(() => _open = true),
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Add a comment'),
        ),
      );
    }
    return TextField(
      key: const Key('comment-input'),
      controller: _controller,
      autofocus: (widget.value ?? '').isEmpty,
      minLines: 1,
      maxLines: 4,
      maxLength: 2000,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(labelText: 'Comment (optional)', prefixIcon: Icon(Icons.comment_outlined)),
      onChanged: (text) => widget.onChanged(text.trim().isEmpty ? null : text),
    );
  }
}
