/// Save PDF screen (section 29).
///
/// Save options: Save, Save as, Replace original, Create copy.
/// File name editor: Project Proposal_edited.pdf
/// Show: Saving, Saved successfully, Save failed
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

/// Save screen
class SaveScreen extends ConsumerStatefulWidget {
  const SaveScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<SaveScreen> createState() => _SaveScreenState();
}

class _SaveScreenState extends ConsumerState<SaveScreen> {
  String _fileName = '';
  bool _isSaving = false;
  bool _isDirty = false;
  String? _error;
  String? _successMessage;

  // Save option state - use a single selected value
  String _selectedSaveOption = 'save'; // 'save', 'saveAs', 'replaceOriginal', 'createCopy'

  @override
  void initState() {
    super.initState();
    _fileName = widget.file.displayName;
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Save as new file
  Future<void> _saveAs() async {
    setState(() {
      _isSaving = true;
      _isDirty = false;
    });

    try {
      // TODO: Save as new file
      // final output = await ref.read(fileGatewayProvider).createDocument(
      //   mimeType: 'application/pdf',
      //   displayName: _fileName,
      // );
      // await ref.read(pdfGatewayProvider).saveCopy(
      //   input: widget.file,
      //   output: output,
      // );
      
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _successMessage = 'Saved successfully';
        _isDirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Save failed: ${e.toString()}';
        _isDirty = false;
      });
    }
  }

  // Replace original file
  Future<void> _replaceOriginal() async {
    setState(() {
      _isSaving = true;
      _isDirty = false;
    });

    try {
      // TODO: Replace original
      // final output = await ref.read(fileGatewayProvider).createDocument(
      //   mimeType: 'application/pdf',
      //   displayName: widget.file.displayName,
      // );
      // await ref.read(pdfGatewayProvider).saveCopy(
      //   input: widget.file,
      //   output: output,
      //   replaceOriginal: true,
      // );
      
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _successMessage = 'Saved successfully';
        _isDirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Save failed: ${e.toString()}';
        _isDirty = false;
      });
    }
  }

  // Create copy
  Future<void> _createCopy() async {
    setState(() {
      _isSaving = true;
      _isDirty = false;
    });

    try {
      // TODO: Create copy
      // final output = await ref.read(fileGatewayProvider).createDocument(
      //   mimeType: 'application/pdf',
      //   displayName: '${_baseName(widget.file)}-copy.pdf',
      // );
      // await ref.read(pdfGatewayProvider).saveCopy(
      //   input: widget.file,
      //   output: output,
      // );
      
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _successMessage = 'Saved successfully';
        _isDirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Save failed: ${e.toString()}';
        _isDirty = false;
      });
    }
  }

  // Cancel save
  void _cancelSave() {
    setState(() {
      _selectedSaveOption = 'save';
    });
  }

  String _baseName(FileItem file) {
    final dot = file.displayName.lastIndexOf('.');
    if (dot <= 0 || dot == file.displayName.length - 1) return file.displayName;
    return file.displayName.substring(0, dot);
  }

  // Determine which action to take based on selected option
  VoidCallback _determineSaveAction() {
    switch (_selectedSaveOption) {
      case 'saveAs':
        return _saveAs;
      case 'replaceOriginal':
        return _replaceOriginal;
      case 'createCopy':
        return _createCopy;
      case 'save':
      default:
        return _saveAs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Save PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Cancel',
            onPressed: _cancelSave,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SiliphSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Save option buttons using Radio
              _SaveOptionRadio(
                title: 'Save',
                subtitle: 'Save to original location',
                value: 'save',
                groupValue: _selectedSaveOption,
                onChanged: (value) {
                  setState(() => _selectedSaveOption = value!);
                },
              ),
              _SaveOptionRadio(
                title: 'Save as',
                subtitle: 'Save as a new file',
                value: 'saveAs',
                groupValue: _selectedSaveOption,
                onChanged: (value) {
                  setState(() => _selectedSaveOption = value!);
                },
              ),
              _SaveOptionRadio(
                title: 'Create copy',
                subtitle: 'Create a copy with a new name',
                value: 'createCopy',
                groupValue: _selectedSaveOption,
                onChanged: (value) {
                  setState(() => _selectedSaveOption = value!);
                },
              ),
              const SizedBox(height: SiliphSpacing.md),

              // File name field
              TextFormField(
                onChanged: (value) {
                  setState(() => _fileName = value);
                },
                initialValue: _fileName,
                decoration: const InputDecoration(
                  labelText: 'File name',
                  hintText: 'Enter file name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a file name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: SiliphSpacing.md),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _determineSaveAction,
                  child: _isSaving
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text('Save'),
                ),
              ),
              const SizedBox(height: SiliphSpacing.sm),

              // Status messages
              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: SiliphSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.all(SiliphSpacing.sm),
                    color: SiliphColors.success.withValues(alpha: 0.1),
                    child: Text(
                      _successMessage!,
                      style: const TextStyle(color: SiliphColors.success),
                    ),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: SiliphSpacing.sm),
                  child: Container(
                    padding: const EdgeInsets.all(SiliphSpacing.sm),
                    color: SiliphColors.error.withValues(alpha: 0.1),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: SiliphColors.error),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Save option radio widget - uses correct RadioListTile types
class _SaveOptionRadio extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _SaveOptionRadio({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<String>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
    );
  }
}