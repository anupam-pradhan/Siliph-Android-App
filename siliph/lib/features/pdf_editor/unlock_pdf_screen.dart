/// Unlock PDF screen (section 23).
///
/// Password input, show password, unlock.
/// Success state: PDF unlocked successfully
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

/// Unlock PDF screen
class UnlockPdfScreen extends ConsumerStatefulWidget {
  const UnlockPdfScreen({
    super.key,
    required this.file,
  });

  final FileItem file;

  @override
  ConsumerState<UnlockPdfScreen> createState() => _UnlockPdfScreenState;
}

class _UnlockPdfScreenState extends ConsumerState<UnlockPdfScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _isDirty = false;
  String? _error;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  // Toggle password visibility
  void _togglePasswordVisibility() {
    setState(() => _showPassword = !_showPassword);
  }

  // Unlock PDF
  Future<void> _unlockPdf() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isDirty = true);

    final password = _passwordController.text;

    if (password.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Please enter a password';
        _isDirty = false;
      });
      return;
    }

    try {
      // TODO: Unlock PDF
      // final result = await ref.read(pdfGatewayProvider).unlockPdf(
      //   input: widget.file,
      //   password: password,
      // );
      
      if (!mounted) return;
      setState(() {
        _unlocked = true;
        _isDirty = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to unlock PDF: ${e.toString()}';
          _isDirty = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unlock PDF'),
        actions: [
          IconButton(
            icon: Icon(
              _showPassword ? Icons.remove_red_eye : Icons.lock
            ),
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
                      hintText: 'Enter PDF password',
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
                  const SizedBox(height: SiliphSpacing.md),

                  // Unlock button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _unlockPdf,
                      child: const Text('Unlock'),
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