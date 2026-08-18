/// PDF Metadata screen (section 21).
///
/// Fields: title, author, subject, keywords, creator.
/// Actions: Save Metadata
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

/// Metadata screen
class MetadataScreen extends ConsumerStatefulWidget {
  const MetadataScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<MetadataScreen> createState() => _MetadataScreenState;
}

class _MetadataScreenState extends ConsumerState<MetadataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _subjectController = TextEditingController();
  final _keywordsController = TextEditingController();
  final _creatorController = TextEditingController();
  bool _isDirty = false;
  String? _error;

  // Load existing metadata
  @override
  void initState() {
    super.initState();
    _loadExistingMetadata();
  }

  void _loadExistingMetadata() {
    // TODO: Load metadata from PDF
    // final meta = await ref.read(pdfGatewayProvider).getMetadata(widget.file);
    // _titleController.text = meta.title ?? '';
    // _authorController.text = meta.author ?? '';
    // _subjectController.text = meta.subject ?? '';
    // _keywordsController.text = meta.keywords ?? '';
    // _creatorController.text = meta.creator ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _subjectController.dispose();
    _keywordsController.dispose();
    _creatorController.dispose();
    super.dispose();
  }

  // Save metadata
  Future<void> _saveMetadata() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isDirty = true);

    try {
      // TODO: Save metadata to PDF
      // await ref.read(pdfGatewayProvider).setMetadata(
      //   input: widget.file,
      //   title: _titleController.text,
      //   author: _authorController.text,
      //   subject: _subjectController.text,
      //   keywords: _keywordsController.text,
      //   creator: _creatorController.text,
      // );
      
      if (!mounted) return;
      setState(() {
        _isDirty = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to save metadata: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Metadata'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _saveMetadata,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SiliphSpacing.md),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  _buildTextField(
                    controller: _titleController,
                    label: 'Title',
                    hint: 'Document title',
                  ),
                  const SizedBox(height: SiliphSpacing.md),

                  // Author
                  _buildTextField(
                    controller: _authorController,
                    label: 'Author',
                    hint: 'Author name',
                  ),
                  const SizedBox(height: SiliphSpacing.md),

                  // Subject
                  _buildTextField(
                    controller: _subjectController,
                    label: 'Subject',
                    hint: 'Document subject',
                  ),
                  const SizedBox(height: SiliphSpacing.md),

                  // Keywords
                  _buildTextField(
                    controller: _keywordsController,
                    label: 'Keywords',
                    hint: 'Comma-separated keywords',
                  ),
                  const SizedBox(height: SiliphSpacing.md),

                  // Creator
                  _buildTextField(
                    controller: _creatorController,
                    label: 'Creator',
                    hint: 'Document creator',
                  ),
                  const SizedBox(height: SiliphSpacing.lg),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveMetadata,
                      child: const Text('Save Metadata'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }
}