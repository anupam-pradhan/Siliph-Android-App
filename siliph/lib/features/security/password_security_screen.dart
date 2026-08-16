/// Protect / Unlock PDF workflow (section 14, section 50 tool-screen
/// standard).
///
/// Honesty rules from the master prompt: unlock always asks for the
/// password and reports wrong passwords plainly — Siliph never claims to
/// strip a password without one.
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
import '../../domain/services/pdf_plans.dart';

enum SecurityMode { protect, unlock }

enum _Phase { pick, configure, running, done }

class PasswordSecurityScreen extends ConsumerStatefulWidget {
  const PasswordSecurityScreen({super.key, required this.mode});

  final SecurityMode mode;

  @override
  ConsumerState<PasswordSecurityScreen> createState() =>
      _PasswordSecurityScreenState();
}

class _PasswordSecurityScreenState
    extends ConsumerState<PasswordSecurityScreen> {
  _Phase _phase = _Phase.pick;
  FileItem? _input;
  bool _picking = false;
  bool _inspectFailed = false;
  double _progress = 0;
  String? _error;
  FileItem? _output;
  StreamSubscription<double>? _progressSub;

  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool get _isProtect => widget.mode == SecurityMode.protect;

  @override
  void dispose() {
    final sub = _progressSub;
    _progressSub = null;
    if (sub != null) unawaited(sub.cancel());
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? get _passwordProblem {
    final password = _passwordController.text;
    if (password.isEmpty) return 'Enter a password.';
    if (_isProtect) {
      if (password.length < 4) return 'Use at least 4 characters.';
      if (password != _confirmController.text) {
        return 'The passwords do not match.';
      }
    }
    return null;
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref
          .read(fileGatewayProvider)
          .openDocuments(const ['application/pdf']);
      if (!mounted) return;
      if (picked.isEmpty) {
        setState(() => _picking = false);
        return;
      }
      final file = picked.first;
      // Unlock only makes sense for encrypted files; verify honestly.
      if (!_isProtect) {
        final info = await ref.read(pdfGatewayProvider).inspect(file);
        if (!mounted) return;
        if (!info.encrypted) {
          setState(() {
            _picking = false;
            _input = file;
            _inspectFailed = true;
            _phase = _Phase.configure;
          });
          return;
        }
      }
      setState(() {
        _picking = false;
        _inspectFailed = false;
        _input = file;
        _output = null;
        _phase = _Phase.configure;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = 'Could not open that PDF.';
      });
    }
  }

  Future<void> _run() async {
    final input = _input;
    if (input == null || _passwordProblem != null) return;
    final suffix = _isProtect ? '-protected' : '-unlocked';
    final output = await ref.read(fileGatewayProvider).createDocument(
          mimeType: 'application/pdf',
          displayName: '${stripPdfExtension(input.displayName)}$suffix.pdf',
        );
    if (!mounted) return;
    if (output == null) return;

    final gateway = ref.read(pdfGatewayProvider);
    final handle = _isProtect
        ? gateway.protect(
            input: input,
            password: _passwordController.text,
            output: output,
          )
        : gateway.unlock(
            input: input,
            password: _passwordController.text,
            output: output,
          );
    _progressSub = handle.progress.listen((value) {
      if (mounted) setState(() => _progress = value);
    });
    setState(() {
      _phase = _Phase.running;
      _progress = 0;
      _error = null;
    });
    try {
      await handle.done;
      if (!mounted) return;
      ref.read(importedFilesProvider.notifier).addAll([output]);
      setState(() {
        _output = output;
        _phase = _Phase.done;
      });
    } catch (e) {
      if (!mounted) return;
      if (e is BridgeException && e.isCancelled) return;
      setState(() {
        _phase = _Phase.configure;
        _error = e is BridgeException ? e.userMessage : 'The task failed.';
      });
    } finally {
      final sub = _progressSub;
      _progressSub = null;
      if (sub != null) unawaited(sub.cancel());
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isProtect ? 'Protect PDF' : 'Unlock PDF';
    final input = _input;
    final output = _output;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (_phase) {
                _Phase.pick =>
                  _PickView(picking: _picking, onPick: _pick, title: title),
                _Phase.configure => _ConfigureView(
                    file: input!,
                    isProtect: _isProtect,
                    notEncrypted: _inspectFailed,
                    passwordController: _passwordController,
                    confirmController: _confirmController,
                    problem: _passwordProblem,
                    onChanged: (_) => setState(() {}),
                    onRun: _run,
                  ),
                _Phase.running => _ProgressView(
                    progress: _progress, isProtect: _isProtect),
                _Phase.done => _DoneView(
                    output: output!,
                    isProtect: _isProtect,
                    onRestart: () => setState(() {
                          _phase = _Phase.pick;
                          _input = null;
                          _output = null;
                          _passwordController.clear();
                          _confirmController.clear();
                        }),
                  ),
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(SiliphSpacing.md),
                child: _ErrorBanner(message: _error!),
              ),
          ],
        ),
      ),
    );
  }
}

class _PickView extends StatelessWidget {
  const _PickView({
    required this.picking,
    required this.onPick,
    required this.title,
  });

  final bool picking;
  final VoidCallback onPick;
  final String title;

  @override
  Widget build(BuildContext context) {
    final protect = title == 'Protect PDF';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              protect ? Icons.lock_outline : Icons.lock_open_outlined,
              size: 64,
              color: SiliphColors.primary,
            ),
            const SizedBox(height: SiliphSpacing.md),
            Text(title, style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              protect
                  ? 'Encrypt a PDF copy with a password.'
                  : 'Save an unencrypted copy using the file\'s password.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            FilledButton.icon(
              onPressed: picking ? null : onPick,
              icon: picking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(picking ? 'Opening…' : 'Choose PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigureView extends StatelessWidget {
  const _ConfigureView({
    required this.file,
    required this.isProtect,
    required this.notEncrypted,
    required this.passwordController,
    required this.confirmController,
    required this.problem,
    required this.onChanged,
    required this.onRun,
  });

  final FileItem file;
  final bool isProtect;
  final bool notEncrypted;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final String? problem;
  final ValueChanged<String> onChanged;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SiliphSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_outlined,
                      color: SiliphColors.primary),
                  const SizedBox(width: SiliphSpacing.sm),
                  Expanded(
                    child: Text(file.displayName,
                        style: Theme.of(context).textTheme.titleMediumStyle),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SiliphSpacing.md),
          if (notEncrypted)
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: SiliphColors.primary),
                const SizedBox(width: SiliphSpacing.xs),
                Expanded(
                  child: Text(
                    'This PDF is not encrypted, so there is nothing to '
                    'unlock.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              controller: passwordController,
              onChanged: onChanged,
              obscureText: true,
              decoration: InputDecoration(
                labelText: isProtect ? 'Password' : 'PDF password',
                border: const OutlineInputBorder(),
              ),
            ),
            if (isProtect) ...[
              const SizedBox(height: SiliphSpacing.sm),
              TextField(
                controller: confirmController,
                onChanged: onChanged,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: notEncrypted || problem != null ? null : onRun,
              icon: Icon(isProtect ? Icons.lock_outline : Icons.lock_open),
              label: Text(
                notEncrypted
                    ? 'Nothing to unlock'
                    : problem ??
                        (isProtect
                            ? 'Save protected copy'
                            : 'Save unlocked copy'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress, required this.isProtect});

  final double progress;
  final bool isProtect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isProtect
                  ? 'Encrypting… ${(progress * 100).toInt()}%'
                  : 'Decrypting… ${(progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.titleMediumStyle,
            ),
            const SizedBox(height: SiliphSpacing.md),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({
    required this.output,
    required this.isProtect,
    required this.onRestart,
  });

  final FileItem output;
  final bool isProtect;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SiliphSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: SiliphColors.success),
            const SizedBox(height: SiliphSpacing.md),
            Text(isProtect ? 'Protected' : 'Unlocked',
                style: Theme.of(context).textTheme.headlineSmallStyle),
            const SizedBox(height: SiliphSpacing.xs),
            Text(
              isProtect
                  ? 'The copy "${output.displayName}" now requires the '
                      'password to open. The original is unchanged.'
                  : 'Saved as "${output.displayName}". The original file '
                      'still needs its password.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SiliphSpacing.lg),
            OutlinedButton(onPressed: onRestart, child: const Text('Done')),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(SiliphSpacing.sm),
      decoration: BoxDecoration(
        color: SiliphColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(SiliphRadii.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: SiliphColors.error, size: 20),
          const SizedBox(width: SiliphSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
