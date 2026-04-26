import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/tap_scale.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _inputCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loading = false;

  final List<ChatMessage> _messages = [
    ChatMessage(
      text: "Hi! I'm Plately. Tell me what ingredients you have and I'll suggest high-protein recipes. Or ask me anything about cooking and nutrition.",
      isUser: false,
      timestamp: DateTime(2025),
    ),
  ];

  static const _quickPrompts = [
    'High protein breakfast ideas',
    'What can I make with eggs?',
    'Cheap meals under 500 cal',
    'Meal prep for the week',
  ];

  static const _mockReply =
      "Great question! I'd suggest a high-protein chicken and vegetable stir fry — quick (20 min), packed with 38g protein, and only about P150 per serving. Want the full recipe?";

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final msg = (text ?? _inputCtrl.text).trim();
    if (msg.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: msg, isUser: true, timestamp: DateTime.now()));
      _loading = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: _mockReply, isUser: false, timestamp: DateTime.now()));
        _loading = false;
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildMessages()),
                  if (_messages.length == 1) _buildQuickPrompts(),
                  if (_loading) _buildTypingIndicator(),
                  _buildInput(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PlatelyBottomNav(currentIndex: 3, onTap: (_) {}, onScanTap: () {}),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 24, 14),
      child: Row(
        children: [
          TapScale(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGray)),
              child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
            child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ask Plately',
                    style: TextStyle(color: AppTheme.darkText, fontSize: 16,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
                Text('AI cooking assistant',
                    style: TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.green, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Online',
                  style: TextStyle(color: AppTheme.green, fontSize: 11,
                      fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _Bubble(
        key: ValueKey(_messages[i].timestamp.microsecondsSinceEpoch),
        message: _messages[i],
      ).animate().fadeIn(duration: 280.ms)
          .slideX(begin: _messages[i].isUser ? 0.06 : -0.06, end: 0, duration: 280.ms),
    );
  }

  Widget _buildQuickPrompts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Try asking:',
                style: TextStyle(color: AppTheme.mutedText, fontSize: 12, fontFamily: 'DM Sans')),
          ),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _quickPrompts.map((p) => TapScale(
              onTap: () => _send(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.borderGray),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))
                    ]),
                child: Text(p,
                    style: const TextStyle(color: AppTheme.primaryDark, fontSize: 12,
                        fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
            child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderGray)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BounceDot(delay: 0),
                SizedBox(width: 5),
                _BounceDot(delay: 160),
                SizedBox(width: 5),
                _BounceDot(delay: 320),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 200.ms),
    );
  }

  Widget _buildInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                  color: AppTheme.creamBg,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppTheme.borderGray)),
              child: TextField(
                controller: _inputCtrl,
                onSubmitted: (_) => _send(),
                maxLines: null,
                style: const TextStyle(fontSize: 14, fontFamily: 'DM Sans', color: AppTheme.darkText),
                decoration: const InputDecoration(
                  hintText: 'Ask about recipes or nutrition...',
                  hintStyle: TextStyle(color: AppTheme.mutedText, fontSize: 14, fontFamily: 'DM Sans'),
                  contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TapScale(
            onTap: _send,
            child: Container(
              width: 46, height: 46,
              decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
              child: const Icon(LucideIcons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
              child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser ? AppTheme.primaryDark : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
                border: message.isUser ? null : Border.all(color: AppTheme.borderGray),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6, offset: const Offset(0, 2))
                ],
              ),
              child: Text(message.text,
                  style: TextStyle(
                      color: message.isUser ? Colors.white : AppTheme.darkText,
                      fontSize: 14, fontFamily: 'DM Sans', height: 1.5)),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 10),
            Container(
              width: 34, height: 34,
              decoration: const BoxDecoration(color: AppTheme.scanGreen, shape: BoxShape.circle),
              child: const Icon(LucideIcons.user, color: AppTheme.primaryDark, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

class _BounceDot extends StatefulWidget {
  final int delay;
  const _BounceDot({required this.delay});
  @override
  State<_BounceDot> createState() => _BounceDotState();
}

class _BounceDotState extends State<_BounceDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.0, end: -6.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(color: AppTheme.mutedText, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
