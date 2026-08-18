/// Protect PDF screen (section 22).
///
/// Options: set password, confirm password, encryption,
/// allow printing, allow copying, allow editing.
/// Button: Protect PDF
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

/// Protect PDF screen
class ProtectPdfScreen extends ConsumerStatefulWidget {
  const ProtectPdfScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<ProtectPdfScreen> createState() => _ProtectPdfScreenState;
}

class _ProtectPdfScreenState extends ConsumerState<ProtectPdfScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _allowPrinting = true;
  bool _allowCopying = true;
  bool _allowEditing = true;
  bool _isDirty = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() => _showPassword = !_showPassword);
  }

  // Toggle confirm password visibility
  void _toggleConfirmPasswordVisibility() {
    setState(() => _showConfirmPassword = !_showConfirmPassword);
  }

  // Validate and protect PDF
  Future<void> _protectPdf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isDirty = true);

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      if (!mounted) return;
      setState(() {
        _error = 'Passwords do not match';
        _isDirty = false;
      });
      return;
    }

    if (password.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Please enter a password';
        _isDirty = false;
      });
      return;
    }

    try {
      // TODO: Protect PDF
      // await ref.read(pdfGatewayProvider).protectPdf(
      //   input: widget.file,
      //   password: password,
      //   allowPrinting: _allowPrinting,
      //   allowCopying: _allowCopying,
      //   allowEditing: _allowEditing,
      // );
      
      if (!mounted) return;
      setState(() {
        _isDirty = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to protect PDF: ${e.toString()}';
          _isDirty = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Protect PDF'),
        actions: [
          IconButton(
            icon: const Icon(Icons.remove_red_eye),
            tooltip: _showPassword ? 'Show password' : 'Hide password',
            onPressed: _togglePasswordVisibility,
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
                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter password',
                      border: const OutlineInputBorder(),
                      suffixIcon: _showPassword
                          ? const Icon(Icons.remove)
                          : const Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: SiliphSpacing.sm),

                  // Confirm password
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: !_showConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      hintText: 'Re-enter password',
                      border: const OutlineInputBorder(),
                      suffixIcon: _showConfirmPassword
                          ? const Icon(Icons.remove)
                          : const Icon(Icons.lock),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm the password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: SiliphSpacing.md),

                  // Permission options
                  const Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: SiliphSpacing.sm),
                  _PermissionToggle(
                    title: 'Allow printing',
                    value: _allowPrinting,
                    onChanged: (value) =>
                        setState(() => _allowPrinting = value),
                  ),
                  _PermissionToggle(
                    title: 'Allow copying',
                    value: _allowCopying,
                    onChanged: (value) =>
                        setState(() => _allowCopying = value),
                  ),
                  _PermissionToggle(
                    title: 'Allow editing',
                    value: _allowEditing,
                    onChanged: (value) => setState(() => _allowEditing = value),
                  ),
                  const SizedBox(height: SiliphSpacing.lg),

                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _protectPdf,
                      child: const Text('Protect PDF'),
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
}

// Permission toggle widget
class _PermissionToggle extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionToggle({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}