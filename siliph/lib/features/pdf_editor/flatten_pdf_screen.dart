/// Flatten PDF screen (section 24).
///
/// Flattening converts editable annotations and form elements into fixed PDF content.
/// Options: flatten annotations, flatten forms, flatten everything.
/// Button: Flatten PDF
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

/// Flatten PDF screen
class FlattenPdfScreen extends ConsumerStatefulWidget {
  const FlattenPdfScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<FlattenPdfScreen> createState() => _FlattenPdfScreenState;
}

class _FlattenPdfScreenState extends ConsumerState<FlattenPdfScreen> {
  bool _flattenAnnotations = true;
  bool _flattenForms = true;
  bool _flattenEverything = false;
  bool _isDirty = false;
  String? _error;

  // Flatten PDF
  Future<void> _flattenPdf() async {
    setState(() => _isDirty = true);

    try {
      // TODO: Flatten PDF
      // final result = await ref.read(pdfGatewayProvider).flattenPdf(
      //   input: widget.file,
      //   flattenAnnotations: _flattenAnnotations,
      //   flattenForms: _flattenForms,
      //   flattenEverything: _flattenEverything,
      // );
      
      if (!mounted) return;
      setState(() {
        _isDirty = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to flatten PDF: ${e.toString()}');
        _isDirty = false;
      }
    }
  }

  // Show confirmation before flattening
  Future<bool?> _showFlattenConfirmation() {
    if (!mounted) return null;
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flatten PDF?'),
        content: const Text(
          'Flattening converts editable annotations and form elements into '
          'fixed PDF content. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Flatten'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flatten PDF'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SiliphSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info text
              const Text(
                'Flattening converts editable annotations and form elements into '
                'fixed PDF content. This action cannot be undone.',
                style: TextStyle(fontSize: 12, color: SiliphColors.onSurfaceVariant),
              ),
              const SizedBox(height: SiliphSpacing.lg),

              // Option buttons
              _OptionTile(
                title: 'Flatten annotations',
                value: _flattenAnnotations,
                onChanged: (value) =>
                    setState(() => _flattenAnnotations = value),
              ),
              _OptionTile(
                title: 'Flatten forms',
                value: _flattenForms,
                onChanged: (value) =>
                    setState(() => _flattenForms = value),
              ),
              _OptionTile(
                title: 'Flatten everything',
                value: _flattenEverything,
                onChanged: (value) =>
                    setState(() => _flattenEverything = value),
              ),
              const SizedBox(height: SiliphSpacing.lg),

              // Flatten button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showFlattenConfirmation().then((value) =>
                      value == true ? _flattenPdf() : null),
                  child: const Text('Flatten PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Option tile widget
class _OptionTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}