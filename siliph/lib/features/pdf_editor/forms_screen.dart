/// Forms screen (section 12).
///
/// Support: text field, checkbox, radio button, dropdown, signature field.
/// Add field, move field, resize field, edit field, delete field.
/// For existing forms, allow users to fill them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../app/theme/siliph_typography.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../domain/services/native_bridge.dart';
import '../../generated/siliph_bridge.g.dart';

enum _FormFieldType { text, checkbox, radio, dropdown, signature }
enum _FormPhase { adding, editing, filling, selected }

/// Form field model
class _FormFieldModel {
  final _FormFieldType type;
  final String id;
  final String label;
  final String hint;
  final bool isRequired;
  bool isVisible;
  // Text field specific
  String initialValue;
  // Checkbox specific
  bool isChecked;
  // Radio button specific
  String? selectedValue;
  // Dropdown specific
  final List<String> options;
  // Signature specific
  bool hasSignature;
  bool isSelected;
  // Position and size
  final Rect bounds;

  _FormFieldModel({
    required this.type,
    required this.id,
    required this.label,
    required this.hint,
    this.isRequired = false,
    this.isVisible = true,
    this.initialValue = '',
    this.isChecked = false,
    this.selectedValue,
    List<String>? options,
this.hasSignature = false,
      this.isSelected = false,
      required this.bounds,
  }) : options = options ?? [];

  _FormFieldModel copyWith({
    _FormFieldType? type,
    String? id,
    String? label,
    String? hint,
    bool? isRequired,
    bool? isVisible,
    String? initialValue,
    bool? isChecked,
    String? selectedValue,
    List<String>? options,
    bool? hasSignature,
    bool? isSelected,
    Rect? bounds,
  }) {
    return _FormFieldModel(
      type: type ?? this.type,
      id: id ?? this.id,
      label: label ?? this.label,
      hint: hint ?? this.hint,
      isRequired: isRequired ?? this.isRequired,
      isVisible: isVisible ?? this.isVisible,
      initialValue: initialValue ?? this.initialValue,
      isChecked: isChecked ?? this.isChecked,
      selectedValue: selectedValue ?? this.selectedValue,
      options: options ?? this.options,
      hasSignature: hasSignature ?? this.hasSignature,
      isSelected: isSelected ?? this.isSelected,
      bounds: bounds ?? this.bounds,
    );
  }
}

/// Forms screen
class FormsScreen extends ConsumerStatefulWidget {
  const FormsScreen({
    super.key,
    required this.file,
    required this.pageNumber,
  });

  final FileItem file;
  final int pageNumber;

  @override
  ConsumerState<FormsScreen> createState() => _FormsScreenState();
}

class _FormsScreenState extends ConsumerState<FormsScreen> {
  _FormPhase _phase = _FormPhase.adding;
  _FormFieldType _fieldType = _FormFieldType.text;
  _FormFieldModel _field = _FormFieldModel(
    type: _FormFieldType.text,
    id: '_form_1',
    label: 'Field',
    hint: 'Enter text',
    bounds: const Rect.fromLTRB(0, 0, 200, 40),
  );
  bool _isDirty = false;
  String? _error;
  bool _keyboardVisible = false;
  bool _isMoving = false;
  void onSelected(bool selected) {
    // Handle option chip selection
  }

// Existing fields list
  final List<_FormFieldModel> _fields = [];

  // Currently selected field
  _FormFieldModel? _selectedField;

  // Editing field state
  TextEditingController? _editController;
  FocusNode? _editFocusNode;

  // Filled values for existing fields
  final Map<String, String> _filledValues = {};

  @override
  void initState() {
    super.initState();
    // TODO: Load existing form fields from PDF
    // _fields.addAll(await ref.read(pdfGatewayProvider).getFormFields(widget.file));
  }

  @override
  void dispose() {
    _editController?.dispose();
    _editFocusNode?.dispose();
    super.dispose();
  }

  // Set field type
  void _setFieldType(_FormFieldType type) {
    setState(() {
      _fieldType = type;
      _field = _field.copyWith(type: type);
    });
  }

  // Add new field
  void _addField() {
    setState(() {
      _fields.add(_field);
      _phase = _FormPhase.selected;
      _isDirty = false;
    });
  }

  // Cancel adding
  void _cancelAdd() {
    setState(() {
      _phase = _FormPhase.adding;
      _isDirty = false;
    });
  }

  // Start editing existing field
  void _startEditing(_FormFieldModel field) {
    setState(() {
      _selectedField = field;
      _phase = _FormPhase.editing;
    });
    // Initialize controller based on field type
    _editController = TextEditingController(text: field.initialValue);
    _editFocusNode = FocusNode();
  }

  // Save edited field
  void _saveField() {
    if (_selectedField != null) {
      setState(() {
        // Update the field in the list
        final index = _fields.indexOf(_selectedField!);
        if (index != -1) {
          _fields[index] = _field.copyWith(isSelected: false);
        }
        _phase = _FormPhase.selected;
      });
    }
    _editController?.dispose();
    _editFocusNode?.dispose();
  }

  // Delete field
  void _deleteField() {
    if (_selectedField != null) {
      setState(() {
        _fields.remove(_selectedField!);
        _selectedField = null;
        _phase = _FormPhase.adding;
      });
    }
  }

  // Toggle checkbox
  void _toggleCheckbox() {
    if (_selectedField != null && _selectedField!.type == _FormFieldType.checkbox) {
      setState(() {
        _selectedField = _selectedField!.copyWith(isChecked: !_selectedField!.isChecked);
      });
    }
  }

  // Fill form field
  void _fillField(String value) {
    if (_selectedField != null) {
      setState(() {
        _filledValues[_selectedField!.id] = value;
        // Hide keyboard
        FocusScope.of(context).unfocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forms'),
        actions: [
          // Add field button (when in adding phase)
          if (_phase == _FormPhase.adding)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Field',
              onPressed: () {},
            ),
          // Done/cancel
          if (_phase == _FormPhase.adding || _phase == _FormPhase.editing)
            TextButton(
              onPressed: _phase == _FormPhase.adding ? _addField : _saveField,
              child: Text(_phase == _FormPhase.adding ? 'Add' : 'Done'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phase indicator
            _buildPhaseIndicator(),

            // Field type selector
            _buildFieldTypeSelector(),

            // Field properties
            _buildFieldProperties(),

            // Existing fields list (when in selected phase)
            if (_phase == _FormPhase.selected || _phase == _FormPhase.filling)
              _buildExistingFields(),

            // Canvas area
            Expanded(
              child: _buildCanvas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Row(
        children: [
          _PhaseChip(
            phase: _FormPhase.adding,
            label: 'Add',
            active: _phase == _FormPhase.adding,
            onSelected: (selected) => setState(() => _phase = _FormPhase.adding),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _FormPhase.editing,
            label: 'Edit',
            active: _phase == _FormPhase.editing,
            onSelected: (selected) => setState(() => _phase = _FormPhase.editing),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _FormPhase.filling,
            label: 'Fill',
            active: _phase == _FormPhase.filling,
            onSelected: (selected) => setState(() => _phase = _FormPhase.filling),
          ),
          const SizedBox(width: SiliphSpacing.sm),
          _PhaseChip(
            phase: _FormPhase.selected,
            label: 'Selected',
            active: _phase == _FormPhase.selected,
            onSelected: (selected) => setState(() => _phase = _FormPhase.selected),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Wrap(
        spacing: SiliphSpacing.xs,
        children: _FormFieldType.values.map((_FormFieldType type) {
          return _FieldTypeChip(
            fieldType: type,
            isSelected: _fieldType == type,
            onSelected: _setFieldType,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFieldProperties() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          TextField(
            decoration: const InputDecoration(
              labelText: 'Label',
              border: OutlineInputBorder(),
            ),
            onChanged: (label) {
              setState(() {
                _field = _field.copyWith(label: label);
              });
            },
          ),
          const SizedBox(height: SiliphSpacing.md),

          // Hint
          TextField(
            decoration: const InputDecoration(
              labelText: 'Hint',
              border: OutlineInputBorder(),
            ),
            onChanged: (hint) {
              setState(() {
                _field = _field.copyWith(hint: hint);
              });
            },
          ),
          const SizedBox(height: SiliphSpacing.md),

          // Required toggle
          Row(
            children: [
              const Text('Required:'),
              Switch(
                value: _field.isRequired,
                onChanged: (value) {
                  setState(() {
                    _field = _field.copyWith(isRequired: value);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: SiliphSpacing.md),

          // Initial value (for text fields)
          if (_fieldType == _FormFieldType.text || _fieldType == _FormFieldType.dropdown)...[
            const Text('Initial Value:', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              onChanged: (value) {
                setState(() {
                  _field = _field.copyWith(initialValue: value);
                });
              },
            ),
            const SizedBox(height: SiliphSpacing.md),
          ],

          // Options (for dropdown)
          if (_fieldType == _FormFieldType.dropdown)...[
            const Text('Options:', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(
              spacing: SiliphSpacing.xs,
              children: [
                _OptionChip(
                  label: 'Option 1',
                  isSelected: false,
                  onSelected: (_) => onSelected(true),
                ),
                _OptionChip(
                  label: 'Option 2',
                  isSelected: false,
                  onSelected: (_) => onSelected(true),
                ),
                _OptionChip(
                  label: 'Option 3',
                  isSelected: false,
                  onSelected: (_) => onSelected(true),
                ),
              ],
            ),
            const SizedBox(height: SiliphSpacing.md),
          ],

          // Initial checked (for checkbox)
          if (_fieldType == _FormFieldType.checkbox)...[
            const Text('Checked by default:', style: TextStyle(fontWeight: FontWeight.bold)),
            Switch(
              value: _field.isChecked,
              onChanged: (value) {
                setState(() {
                  _field = _field.copyWith(isChecked: value);
                });
              },
            ),
            const SizedBox(height: SiliphSpacing.md),
          ],

          // Selected value (for radio)
          if (_fieldType == _FormFieldType.radio)...[
            const Text('Selected Value:', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              onChanged: (value) {
                setState(() {
                  _field = _field.copyWith(selectedValue: value);
                });
              },
            ),
            const SizedBox(height: SiliphSpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingFields() {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      color: SiliphColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Existing Fields:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: SiliphSpacing.sm),
          _FieldListTile(
            field: _FormFieldModel(
              type: _FormFieldType.text,
              id: '_form_1',
              label: 'Name',
              hint: 'Enter your name',
              bounds: const Rect.fromLTRB(50, 100, 250, 40),
              isRequired: true,
            ),
            onEdit: _startEditing,
            onDelete: _deleteField,
          ),
          _FieldListTile(
            field: _FormFieldModel(
              type: _FormFieldType.checkbox,
              id: '_form_2',
              label: 'Agree',
              hint: 'I agree',
              bounds: const Rect.fromLTRB(50, 160, 250, 40),
            ),
            onEdit: _startEditing,
            onDelete: _deleteField,
          ),
          _FieldListTile(
            field: _FormFieldModel(
              type: _FormFieldType.dropdown,
              id: '_form_3',
              label: 'Selection',
              hint: 'Choose an option',
              bounds: const Rect.fromLTRB(50, 220, 250, 40),
              options: ['Option A', 'Option B', 'Option C'],
            ),
            onEdit: _startEditing,
            onDelete: _deleteField,
          ),
        ],
      ),
    );
  }

  Widget _buildCanvas() {
    return GestureDetector(
      onPanStart: (details) {
        if (_phase == _FormPhase.adding) {
          // Start creating new field
          _startCreateField(details.localPosition);
        } else if (_phase == _FormPhase.selected && _selectedField != null) {
          // Start moving selected field
          _startMoveField(details.localPosition);
        }
      },
      onPanUpdate: (details) {
        if (_phase == _FormPhase.adding && _selectedField == null) {
          _updateCreateField(details.localPosition);
        } else if (_phase == _FormPhase.selected && _selectedField != null && _isMoving) {
          _updateMoveField(details.localPosition);
        }
      },
      onPanEnd: (_) {
        if (_phase == _FormPhase.adding) {
          _finishCreateField();
        }
      },
      child: Stack(
        children: [
          // PDF page area
          const Center(
            child: Icon(
              Icons.picture_as_pdf_outlined,
              size: 100,
              color: SiliphColors.outline,
            ),
          ),

          // New field preview
          if (_phase == _FormPhase.adding && _selectedField == null)
            _fieldPreview(field: _field),

          // Selected field
          if (_selectedField != null) ...[
            _fieldPreview(field: _selectedField!),
          ],

          // Existing fields
          ..._buildFieldPreviews(),
        ],
      ),
    );
  }

  Widget _startCreateField(Offset position) {
    // Just a placeholder - actual implementation would track
    return const SizedBox.shrink();
  }

  Widget _updateCreateField(Offset position) {
    return const SizedBox.shrink();
  }

  Widget _finishCreateField() {
    return const SizedBox.shrink();
  }

  Widget _startMoveField(Offset position) {
    setState(() {
      _isMoving = true;
    });
    return const SizedBox.shrink();
  }

  Widget _updateMoveField(Offset position) {
    return const SizedBox.shrink();
  }

  // Build field preview widget
  // Build field preview widget
  Widget _fieldPreview({required _FormFieldModel field}) {
    final color = switch (field.type) {
      _FormFieldType.text => SiliphColors.primary.withValues(alpha: 0.1),
      _FormFieldType.checkbox => SiliphColors.secondary.withValues(alpha: 0.1),
      _FormFieldType.radio => SiliphColors.tertiary.withValues(alpha: 0.1),
      _FormFieldType.dropdown => SiliphColors.info.withValues(alpha: 0.1),
      _FormFieldType.signature => SiliphColors.primary.withValues(alpha: 0.1),
    };

    return Positioned(
      left: field.bounds.left,
      top: field.bounds.top,
      child: Container(
        width: field.bounds.width,
        height: field.bounds.height,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: SiliphColors.primary, width: 1),
          borderRadius: BorderRadius.circular(SiliphRadii.sm),
        ),
        child: _buildFieldContent(field),
      ),
    );
  }

  Widget _buildFieldContent(_FormFieldModel field) {
    switch (field.type) {
      case _FormFieldType.text:
        return TextField(
          decoration: InputDecoration(
            hintText: field.hint,
            border: InputBorder.none,
          ),
          style: const TextStyle(color: SiliphColors.onSurface),
        );
      case _FormFieldType.checkbox:
        return Row(
          children: [
            Checkbox(
              value: field.isChecked,
              onChanged: (_) =>
                  setState(() => _field = _field.copyWith(isChecked: !_field.isChecked)),
            ),
            Text(field.hint),
          ],
        );
      case _FormFieldType.dropdown:
        return DropdownButton<String>(
          value: field.initialValue.isNotEmpty ? field.initialValue : null,
          items: field.options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (value) {},
        );
      case _FormFieldType.signature:
        return const Icon(Icons.gesture, size: 20, color: SiliphColors.primary);
      default:
        return const Text('Field');
    }
  }

  // Build existing field previews
  List<Widget> _buildFieldPreviews() {
    return _fields.map((field) => _fieldPreview(field: field)).toList();
  }
}

// Field type chip
class _FieldTypeChip extends StatelessWidget {
  final _FormFieldType fieldType;
  final bool isSelected;
  final ValueChanged<_FormFieldType> onSelected;

  const _FieldTypeChip({
    required this.fieldType,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(_fieldTypeLabel(fieldType)),
      selected: isSelected,
      onSelected: (_) => onSelected(fieldType),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }

  String _fieldTypeLabel(_FormFieldType type) {
    switch (type) {
      case _FormFieldType.text:
        return 'Text';
      case _FormFieldType.checkbox:
        return 'Checkbox';
      case _FormFieldType.radio:
        return 'Radio';
      case _FormFieldType.dropdown:
        return 'Dropdown';
      case _FormFieldType.signature:
        return 'Signature';
    }
  }
}

// Field list tile
class _FieldListTile extends StatelessWidget {
  final _FormFieldModel field;
  final void Function(_FormFieldModel) onEdit;
  final VoidCallback onDelete;

  const _FieldListTile({
    required this.field,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(field.label),
      subtitle: Text(field.hint),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => onEdit(field),
              tooltip: 'Edit',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outlined),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

// Option chip
class _OptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const _OptionChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(true),
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}

// Phase chip
class _PhaseChip extends StatelessWidget {
  final _FormPhase phase;
  final String label;
  final bool active;
  final ValueChanged<bool> onSelected;

  const _PhaseChip({
    required this.phase,
    required this.label,
    required this.active,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: onSelected,
      selectedColor: SiliphColors.primary.withValues(alpha: 0.15),
      backgroundColor: Colors.transparent,
    );
  }
}