import 'package:flutter/material.dart';

class ConfirmAdminActionDialog extends StatefulWidget {
  const ConfirmAdminActionDialog({
    super.key,
    required this.title,
    required this.description,
    required this.confirmationPhrase,
    required this.confirmButtonLabel,
  });

  final String title;
  final String description;
  final String confirmationPhrase;
  final String confirmButtonLabel;

  @override
  State<ConfirmAdminActionDialog> createState() =>
      _ConfirmAdminActionDialogState();
}

class _ConfirmAdminActionDialogState extends State<ConfirmAdminActionDialog> {
  final _confirmationController = TextEditingController();
  bool _canConfirm = false;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.description),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmationController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Type ${widget.confirmationPhrase} to confirm',
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(
              () => _canConfirm = value.trim() == widget.confirmationPhrase,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canConfirm
              ? () => Navigator.of(context).pop(true)
              : null,
          child: Text(widget.confirmButtonLabel),
        ),
      ],
    );
  }
}
