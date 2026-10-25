import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/assistant_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../services/auth_service.dart';

/// Opens the AI assistant as a tall modal sheet, reachable from any tab via
/// the floating button in [MainAppFrame]. Same backend, same conversation
/// contract as the kiosk website's widget — just a different shell.
void showAssistantSheet(BuildContext context, {required String page}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AssistantSheet(page: page),
  );
}

class _AssistantSheet extends StatefulWidget {
  const _AssistantSheet({required this.page});

  final String page;

  @override
  State<_AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<_AssistantSheet> {
  final AssistantService _assistant = AssistantService.instance;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<ChatMessage> _messages = <ChatMessage>[];

  bool _streaming = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final String text = _input.text.trim();
    if (text.isEmpty || _streaming) return;
    _input.clear();

    setState(() {
      _error = null;
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _messages.add(ChatMessage(role: ChatRole.assistant, content: ''));
      _streaming = true;
    });
    _scrollToEnd();

    final List<ChatMessage> history = _messages.sublist(0, _messages.length - 1);

    try {
      await _assistant.ask(
        history,
        page: widget.page,
        onChunk: (chunk) {
          if (!mounted) return;
          setState(() {
            final ChatMessage last = _messages.last;
            _messages[_messages.length - 1] = last.copyWithContent(last.content + chunk);
          });
          _scrollToEnd();
        },
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        if (_messages.isNotEmpty && _messages.last.content.isEmpty) _messages.removeLast();
      });
    } finally {
      if (mounted) setState(() => _streaming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool signedIn = AuthService.instance.isSignedIn;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        // Theme background, not the brand-green panel: follows light/dark.
        color: palette.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: palette.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppStrings.get('assistant_label'),
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_messages.isNotEmpty)
                    IconButton(
                      onPressed: _streaming ? null : () => setState(() => _messages.clear()),
                      tooltip: AppStrings.get('assistant_new_chat'),
                      icon: Icon(Icons.refresh_rounded, color: palette.inkMuted),
                    ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: palette.ink),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_messages.isEmpty)
                    _Bubble(
                      text: AppStrings.get('assistant_greeting'),
                      isUser: false,
                      palette: palette,
                    ),
                  for (int i = 0; i < _messages.length; i++)
                    _Bubble(
                      text: _messages[i].content.isEmpty && _streaming && i == _messages.length - 1
                          ? AppStrings.get('assistant_thinking')
                          : _messages[i].content,
                      isUser: _messages[i].role == ChatRole.user,
                      palette: palette,
                    ),
                  if (!signedIn)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        AppStrings.get('assistant_signin_hint'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.inkMuted, fontSize: 12),
                      ),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      enabled: !_streaming,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      style: TextStyle(color: palette.ink),
                      decoration: InputDecoration(
                        hintText: AppStrings.get('assistant_placeholder'),
                        hintStyle: TextStyle(color: palette.inkMuted),
                        filled: true,
                        fillColor: palette.card,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: palette.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 46,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _streaming ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.accent,
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                      ),
                      child: _streaming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isUser, required this.palette});

  final String text;
  final bool isUser;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? palette.accent : palette.card,
          borderRadius: BorderRadius.circular(16),
          // The bot's bubble is close to the page colour in light mode.
          border: isUser ? null : Border.all(color: palette.border),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : palette.ink,
            fontSize: 14,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}
