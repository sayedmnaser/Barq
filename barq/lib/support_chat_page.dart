import 'package:flutter/material.dart';

import 'services/support_ai_service.dart';
import 'settings.dart';

class SupportChatPage extends StatefulWidget {
  const SupportChatPage({super.key, required this.language});

  final AppLanguage language;

  @override
  State<SupportChatPage> createState() => _SupportChatPageState();
}

class _SupportChatPageState extends State<SupportChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SupportAiService _supportAiService = SupportAiService.instance;

  final List<_ChatMessage> _messages = <_ChatMessage>[];
  bool _isReplying = false;

  bool get _isArabic => widget.language == AppLanguage.ar;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        role: _ChatRole.assistant,
        text: _isArabic
            ? 'مرحبًا، أنا مساعد الدعم. كيف أقدر أساعدك اليوم؟'
            : 'Hi, I am your support assistant. How can I help you today?',
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isReplying) {
      return;
    }

    final history = _messages
        .map(
          (item) => <String, String>{
            'role': item.role == _ChatRole.user ? 'user' : 'assistant',
            'text': item.text,
          },
        )
        .toList(growable: false);

    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.user, text: text));
      _messageController.clear();
      _isReplying = true;
    });
    _scrollToBottom();

    final reply = await _supportAiService.generateReply(
      userMessage: text,
      history: history,
      isArabic: _isArabic,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          role: _ChatRole.assistant,
          text: reply.text,
          qaId: reply.qaId,
        ),
      );
      _isReplying = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _voteMessage(_ChatMessage message, int vote) async {
    final qaId = message.qaId;
    if (qaId == null || qaId.isEmpty || message.vote != 0) return;
    setState(() {
      message.vote = vote;
    });
    await _supportAiService.markHelpful(qaId: qaId, vote: vote);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vote > 0
              ? (_isArabic ? 'شكرًا، سيستفيد منها العملاء الآخرون.' : 'Thanks — saved as a helpful answer.')
              : (_isArabic ? 'تم تسجيل الملاحظة. سنحسن الإجابات.' : 'Noted — we will improve future answers.'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userBubbleColor = theme.colorScheme.primary;
    final userTextColor = theme.colorScheme.onPrimary;
    final assistantBubbleColor = theme.cardColor;
    final assistantTextColor = theme.textTheme.bodyMedium?.color ??
        (isDark ? Colors.white : const Color(0xFF111827));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isArabic ? 'دردشة الدعم' : 'Support Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isUser = message.role == _ChatRole.user;
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        constraints: const BoxConstraints(maxWidth: 320),
                        decoration: BoxDecoration(
                          color:
                              isUser ? userBubbleColor : assistantBubbleColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isUser
                                ? userBubbleColor.withValues(alpha: 0.4)
                                : theme.dividerColor,
                          ),
                        ),
                        child: Text(
                          message.text,
                          style: TextStyle(
                            color: isUser ? userTextColor : assistantTextColor,
                          ),
                        ),
                      ),
                      if (!isUser &&
                          message.qaId != null &&
                          message.qaId!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _voteIcon(
                                icon: Icons.thumb_up_alt_outlined,
                                activeIcon: Icons.thumb_up,
                                active: message.vote == 1,
                                disabled: message.vote != 0,
                                onTap: () => _voteMessage(message, 1),
                              ),
                              const SizedBox(width: 12),
                              _voteIcon(
                                icon: Icons.thumb_down_alt_outlined,
                                activeIcon: Icons.thumb_down,
                                active: message.vote == -1,
                                disabled: message.vote != 0,
                                onTap: () => _voteMessage(message, -1),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isArabic
                                    ? 'هل كانت هذه الإجابة مفيدة؟'
                                    : 'Was this helpful?',
                                style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                              ),
                            ],
                          ),
                        )
                      else
                        const SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isReplying)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: LinearProgressIndicator(minHeight: 3),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _isArabic
                            ? 'اكتب رسالتك...'
                            : 'Type your message...',
                        filled: true,
                        fillColor: theme.cardColor,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _sendMessage,
                    child: Text(_isArabic ? 'إرسال' : 'Send'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _voteIcon({
    required IconData icon,
    required IconData activeIcon,
    required bool active,
    required bool disabled,
    required VoidCallback onTap,
  }) {
    final color = active
        ? (Theme.of(context).colorScheme.primary)
        : Theme.of(context).hintColor;
    return InkResponse(
      onTap: disabled ? null : onTap,
      radius: 18,
      child: Icon(active ? activeIcon : icon, size: 16, color: color),
    );
  }
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  _ChatMessage({
    required this.role,
    required this.text,
    this.qaId,
  });

  final _ChatRole role;
  final String text;
  final String? qaId;
  int vote = 0;
}
