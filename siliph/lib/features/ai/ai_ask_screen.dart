/// On-device AI Document Chat screen (sections 41, 42).
///
/// Ask questions about document text with instant, local keyword/TF-IDF
/// page citation matching and key prompt action chips.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/siliph_colors.dart';
import '../../app/theme/siliph_spacing.dart';
import '../../domain/models/file_item.dart';
import '../../domain/providers.dart';
import '../../generated/siliph_bridge.g.dart';
import 'ai_nlp_engine.dart';

class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.pageCitation,
  });

  final String text;
  final bool isUser;
  final int? pageCitation;
}

class AiAskScreen extends ConsumerStatefulWidget {
  const AiAskScreen({super.key});

  @override
  ConsumerState<AiAskScreen> createState() => _AiAskScreenState();
}

class _AiAskScreenState extends ConsumerState<AiAskScreen> {
  FileItem? _selectedFile;
  bool _isLoadingDoc = false;
  List<PageText> _documentPages = [];
  final List<ChatMessage> _messages = [];
  final TextEditingController _queryController = TextEditingController();

  Future<void> _pickDocument() async {
    final fileAccess = ref.read(fileGatewayProvider);
    final files = await fileAccess.openDocuments(
      ['application/pdf', 'text/plain'],
    );

    if (files.isNotEmpty && mounted) {
      final file = files.first;
      setState(() {
        _selectedFile = file;
        _isLoadingDoc = true;
        _messages.clear();
      });

      try {
        final pdfGateway = ref.read(pdfGatewayProvider);
        final handle = pdfGateway.extractText(input: file);
        await handle.done;
        final pages = (await handle.pageTexts) ?? [];

        if (mounted) {
          setState(() {
            _documentPages = pages;
            _isLoadingDoc = false;
            _messages.add(
              ChatMessage(
                text:
                    'Loaded "${file.displayName}" (${pages.length} pages). Ask any question or use quick chips below.',
                isUser: false,
              ),
            );
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingDoc = false;
            _messages.add(
              ChatMessage(
                text: 'Error loading document text: ${e.toString()}',
                isUser: false,
              ),
            );
          });
        }
      }
    }
  }

  void _sendQuery(String queryText) {
    if (queryText.trim().isEmpty || _documentPages.isEmpty) return;

    final userQuery = queryText.trim();
    _queryController.clear();

    setState(() {
      _messages.add(ChatMessage(text: userQuery, isUser: true));
    });

    final answer = AiNlpEngine.answerQuestion(userQuery, _documentPages);

    setState(() {
      _messages.add(
        ChatMessage(
          text: answer.answerText,
          isUser: false,
          pageCitation: answer.relevanceScore > 0 ? answer.pageNumber : null,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Document Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_outlined),
            tooltip: 'Change document',
            onPressed: _isLoadingDoc ? null : _pickDocument,
          ),
        ],
      ),
      body: Column(
        children: [
          // Document Header Bar
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(
              horizontal: SiliphSpacing.md,
              vertical: SiliphSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.description_outlined, color: SiliphColors.primary),
                const SizedBox(width: SiliphSpacing.sm),
                Expanded(
                  child: Text(
                    _selectedFile?.displayName ?? 'No document selected',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: _isLoadingDoc ? null : _pickDocument,
                  child: Text(_selectedFile == null ? 'Select PDF' : 'Change'),
                ),
              ],
            ),
          ),
          if (_isLoadingDoc) const LinearProgressIndicator(),

          // Chat Messages View
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(SiliphSpacing.md),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: SiliphSpacing.sm),
                    padding: const EdgeInsets.all(SiliphSpacing.md),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? SiliphColors.primary
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(SiliphRadii.md),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          msg.text,
                          style: TextStyle(
                            color: msg.isUser
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (msg.pageCitation != null) ...[
                          const SizedBox(height: SiliphSpacing.xs),
                          Chip(
                            avatar: const Icon(Icons.bookmark, size: 14),
                            label: Text('Page ${msg.pageCitation}'),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick Action Chips
          if (_selectedFile != null && !_isLoadingDoc)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: SiliphSpacing.md),
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.summarize_outlined, size: 16),
                    label: const Text('Summarize Page 1'),
                    onPressed: () => _sendQuery('Summarize main topics'),
                  ),
                  const SizedBox(width: SiliphSpacing.xs),
                  ActionChip(
                    avatar: const Icon(Icons.event_outlined, size: 16),
                    label: const Text('Find Deadlines'),
                    onPressed: () => _sendQuery('What dates or deadlines are mentioned?'),
                  ),
                  const SizedBox(width: SiliphSpacing.xs),
                  ActionChip(
                    avatar: const Icon(Icons.contact_mail_outlined, size: 16),
                    label: const Text('Find Contacts'),
                    onPressed: () => _sendQuery('What contact details or emails are in the text?'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: SiliphSpacing.xs),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(SiliphSpacing.sm),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: const InputDecoration(
                      hintText: 'Ask a question about document...',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: _sendQuery,
                    enabled: _selectedFile != null && !_isLoadingDoc,
                  ),
                ),
                const SizedBox(width: SiliphSpacing.xs),
                IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: _selectedFile != null && !_isLoadingDoc
                      ? () => _sendQuery(_queryController.text)
                      : null,
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'AI processes locally. AI can make mistakes — check the source document.',
              style: TextStyle(fontSize: 11, color: SiliphColors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
