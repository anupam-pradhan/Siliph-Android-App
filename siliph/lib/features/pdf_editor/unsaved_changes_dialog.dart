/// Unsaved changes confirmation dialog (section 28).
///
/// Creates confirmation dialog:
/// **You have unsaved changes**
///
/// Options: Save, Discard, Cancel
/// Also create the state when the user attempts to leave the editor.
library;

import 'package:flutter/material.dart';

/// Shows the unsaved changes confirmation dialog.
/// Returns true if user wants to save, false if discard, null if cancel.
Future<bool?> showUnsavedChangesDialog(BuildContext context,
    {required VoidCallback onSave,
    required VoidCallback onDiscard,
    required VoidCallback onCancel}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _UnsavedChangesDialog(
      onSave: onSave,
      onDiscard: onDiscard,
      onCancel: onCancel,
    ),
  );
  return result;
}

/// Unsaved changes dialog widget
class _UnsavedChangesDialog extends StatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final VoidCallback onCancel;

  const _UnsavedChangesDialog({
    required this.onSave,
    required this.onDiscard,
    required this.onCancel,
  });

  @override
  State<_UnsavedChangesDialog> createState() =>
      _UnsavedChangesDialogState();
}

class _UnsavedChangesDialogState extends State<_UnsavedChangesDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('You have unsaved changes'),
      content: const Text(
        'Do you want to save the changes before leaving the editor?',
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(null);
            widget.onCancel();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(false);
            widget.onDiscard();
          },
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(true); // Save
            widget.onSave();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}