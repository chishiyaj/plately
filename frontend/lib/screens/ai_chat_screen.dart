import 'dart:convert';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';
import '../widgets/tap_scale.dart';

class AiChatScreen extends StatefulWidget {
  final String? initialPrompt;
  const AiChatScreen({super.key, this.initialPrompt});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  final _inputCtrl   = TextEditingController();
  final _scrollCtrl  = ScrollController();
  final _inputFocus  = FocusNode();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loading   = false;
  bool _hasText   = false;
  bool _showTimes = false;

  List<_ChatSession> _sessions = [];
  int _activeIdx = 0;

  static String get _kSessions {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    return 'ai_chat_sessions_v3_$uid';
  }
  static const _maxSessions = 30;

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(() {
      final has = _inputCtrl.text.trim().isNotEmpty;
      if (has != _hasText) { setState(() => _hasText = has); }
    });
    _loadSessions();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_kSessions);
    if (raw != null) {
      try {
        final sessions = (jsonDecode(raw) as List).map((s) => _ChatSession.fromJson(s)).toList();
        if (mounted) {
          setState(() { _sessions = sessions; _activeIdx = 0; });
          _scrollToBottom();
          if (widget.initialPrompt != null) { _send(widget.initialPrompt); }
          return;
        }
      } catch (_) {}
    }
    _newSession(save: false);
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _send(widget.initialPrompt));
    }
  }

  Future<void> _saveSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessions, jsonEncode(_sessions.map((s) => s.toJson()).toList()));
  }

  void _newSession({bool save = true}) {
    final s = _ChatSession(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      title: 'New chat', messages: [], createdAt: DateTime.now(),
    );
    setState(() {
      _sessions.insert(0, s);
      _activeIdx = 0;
      if (_sessions.length > _maxSessions) { _sessions = _sessions.sublist(0, _maxSessions); }
    });
    if (save) _saveSessions();
  }

  void _switchSession(int idx) {
    setState(() => _activeIdx = idx);
    _scrollToBottom();
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) Navigator.pop(context);
  }

  void _deleteSession(int idx) {
    HapticFeedback.mediumImpact();
    setState(() {
      _sessions.removeAt(idx);
      if (_sessions.isEmpty) { _newSession(save: false); }
      else { _activeIdx = _activeIdx.clamp(0, _sessions.length - 1); }
    });
    _saveSessions();
  }

  _ChatSession get _active => _sessions[_activeIdx];
  bool get _isEmpty => _active.messages.isEmpty;

  Future<void> _send([String? override]) async {
    final text = (override ?? _inputCtrl.text).trim();
    if (text.isEmpty || _loading) return;
    HapticFeedback.selectionClick();
    setState(() {
      _active.messages.add(ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      if (_active.title == 'New chat') {
        _active.title = text.length > 38 ? '${text.substring(0, 38)}…' : text;
      }
      _loading = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();
    // Build history from current session (last 6 messages, excluding the one just added)
    final history = _active.messages.length > 1
        ? _active.messages
            .sublist(0, _active.messages.length - 1)
            .reversed
            .take(6)
            .toList()
            .reversed
            .map((m) => <String, String>{
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
            .toList()
        : <Map<String, String>>[];
    final reply = await ApiService.sendChat(text, history: history);
    if (!mounted) return;
    setState(() {
      _active.messages.add(ChatMessage(text: reply, isUser: false, timestamp: DateTime.now()));
      _loading = false;
    });
    _scrollToBottom();
    _saveSessions();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
      }
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Copied to clipboard',
          style: TextStyle(fontFamily: 'DM Sans', fontWeight: FontWeight.w500)),
      backgroundColor: AppTheme.primaryDark,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final keyboard  = MediaQuery.of(context).viewInsets.bottom;
    const navBarH   = 116.0;
    final bottomPad = keyboard > navBarH ? keyboard : navBarH;
    final canGoBack = Navigator.of(context).canPop();

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppTheme.scaffoldBg(context),
      resizeToAvoidBottomInset: false,
      drawer: _SessionsDrawer(
        sessions: _sessions, activeIdx: _activeIdx,
        onSelect: _switchSession, onDelete: _deleteSession,
        onNew: () { Navigator.pop(context); _newSession(); },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _Header(
            title: _active.title, isEmpty: _isEmpty, showTimes: _showTimes,
            canGoBack: canGoBack,
            onBack: () => Navigator.pop(context),
            onMenu: () => _scaffoldKey.currentState?.openDrawer(),
            onNew: _newSession,
            onToggleTimes: () => setState(() => _showTimes = !_showTimes),
          ),
          Expanded(
            child: _isEmpty
                ? _WelcomeView(onPrompt: _send)
                : _MessageList(
                    messages: _active.messages, sessionId: _active.id,
                    loading: _loading, showTimes: _showTimes, scrollCtrl: _scrollCtrl,
                    onCopy: _copyMessage, onPrompt: _send,
                  ),
          ),
          _InputBar(
            ctrl: _inputCtrl, focus: _inputFocus, hasText: _hasText,
            loading: _loading, bottomPad: bottomPad, onSend: _send,
          ),
        ]),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String title;
  final bool isEmpty, showTimes, canGoBack;
  final VoidCallback onMenu, onNew, onToggleTimes, onBack;
  const _Header({required this.title, required this.isEmpty, required this.showTimes,
      required this.canGoBack, required this.onBack,
      required this.onMenu, required this.onNew, required this.onToggleTimes});

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.cardBg(context),
    padding: const EdgeInsets.fromLTRB(8, 12, 12, 10),
    child: Row(children: [
      if (canGoBack)
        TapScale(onTap: onBack, child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: const Icon(LucideIcons.arrowLeft, color: AppTheme.primaryDark, size: 20),
        ))
      else
        TapScale(onTap: onMenu, child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: const Icon(LucideIcons.panelLeft, color: AppTheme.primaryDark, size: 20),
        )),
      const SizedBox(width: 4),
      Container(
        width: 34, height: 34,
        decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
        child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 16),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ask Plately', style: TextStyle(
          color: AppTheme.darkText, fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w800)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            key: ValueKey(title),
            title == 'New chat' ? 'AI cooking & nutrition assistant' : title,
            style: const TextStyle(color: AppTheme.mutedText, fontSize: 11, fontFamily: 'DM Sans'),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
        ),
      ])),
      if (!isEmpty) TapScale(
        onTap: onToggleTimes,
        child: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: showTimes ? AppTheme.primaryDark.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(LucideIcons.clock3, size: 16,
              color: showTimes ? AppTheme.primaryDark : AppTheme.mutedText),
        ),
      ),
      const SizedBox(width: 4),
      // New Chat button — greyed out when current session is already empty (no messages)
      Opacity(
        opacity: isEmpty ? 0.35 : 1.0,
        child: TapScale(
          onTap: isEmpty ? null : onNew,
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: isEmpty ? null : AppTheme.tealGradient,
              color: isEmpty ? AppTheme.borderGray : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(LucideIcons.squarePen, color: isEmpty ? AppTheme.mutedText : Colors.white, size: 16),
          ),
        ),
      ),
    ]),
  );
}

// ─── Welcome View ─────────────────────────────────────────────────────────────

class _WelcomeView extends StatelessWidget {
  final void Function(String) onPrompt;
  const _WelcomeView({required this.onPrompt});

  static const _prompts = [
    (icon: LucideIcons.dumbbell,     label: 'High-protein\nbreakfast', q: 'Give me 3 high-protein breakfast ideas under 500 calories'),
    (icon: LucideIcons.egg,          label: 'Egg\nrecipes',            q: 'What can I cook with eggs? I want something quick and high-protein'),
    (icon: LucideIcons.piggyBank,    label: 'Budget\nmeals',           q: 'What are cheap high-protein meals a student can make?'),
    (icon: LucideIcons.calendarDays, label: 'Meal prep\nplan',         q: 'Plan a 5-day high-protein meal prep for a student'),
  ];
  static const _colors = [
    AppTheme.scanGreen,    Color(0xFF2E6B29),
    AppTheme.typeBlue,     Color(0xFF2E3472),
    AppTheme.browseYellow, Color(0xFF6B5A10),
    AppTheme.askPurple,    Color(0xFF5A1F6B),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Column(children: [
      const SizedBox(height: 32),
      Container(
        width: 72, height: 72,
        decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
        child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 34),
      ).animate().scale(begin: const Offset(0.7, 0.7), duration: 500.ms, curve: Curves.easeOutBack).fadeIn(duration: 400.ms),
      const SizedBox(height: 20),
      const Text('Hi, I\'m Plately', style: TextStyle(
        color: AppTheme.darkText, fontSize: 26, fontFamily: 'DM Sans', fontWeight: FontWeight.w800, letterSpacing: -0.5,
      )).animate().fadeIn(duration: 400.ms, delay: 80.ms).slideY(begin: 0.08),
      const SizedBox(height: 8),
      Text('Ask me anything about cooking, nutrition,\nor what to make with your ingredients.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.mutedText.withValues(alpha: 0.8), fontSize: 14, fontFamily: 'DM Sans', height: 1.55),
      ).animate().fadeIn(duration: 400.ms, delay: 140.ms),
      const SizedBox(height: 36),
      const Align(alignment: Alignment.centerLeft, child: Text('Try asking',
          style: TextStyle(color: AppTheme.darkText, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700))),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5),
        itemCount: _prompts.length,
        itemBuilder: (_, i) {
          final p = _prompts[i]; final bg = _colors[i * 2]; final fg = _colors[i * 2 + 1];
          return TapScale(
            onTap: () => onPrompt(p.q),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bg.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(18),
                border: Border.all(color: bg.withValues(alpha: 0.6)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(p.icon, color: fg, size: 16)),
                Text(p.label, style: TextStyle(color: fg, fontSize: 13, fontFamily: 'DM Sans', fontWeight: FontWeight.w700, height: 1.25)),
              ]),
            ),
          ).animate(delay: (i * 60).ms).fadeIn(duration: 350.ms).slideY(begin: 0.08);
        },
      ),
    ]),
  );
}

// ─── Message List ─────────────────────────────────────────────────────────────

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final String sessionId;
  final bool loading, showTimes;
  final ScrollController scrollCtrl;
  final void Function(String) onCopy;
  final void Function(String) onPrompt;
  const _MessageList({required this.messages, required this.sessionId, required this.loading,
      required this.showTimes, required this.scrollCtrl, required this.onCopy, required this.onPrompt});

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: scrollCtrl,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    itemCount: messages.length + (loading ? 1 : 0),
    itemBuilder: (_, i) {
      if (i == messages.length) return _TypingIndicator().animate().fadeIn(duration: 200.ms).slideY(begin: 0.1);
      final m = messages[i];
      final showTs = showTimes ||
          (i == messages.length - 1 && !m.isUser) ||
          (i < messages.length - 1 && m.isUser && !messages[i + 1].isUser);
      return _Bubble(key: ValueKey('${sessionId}_$i'), message: m, showTimestamp: showTs, onCopy: () => onCopy(m.text))
          .animate().fadeIn(duration: 260.ms).slideY(begin: 0.04, duration: 280.ms, curve: Curves.easeOutCubic);
    },
  );
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool showTimestamp;
  final VoidCallback onCopy;
  const _Bubble({required this.message, required this.showTimestamp, required this.onCopy, super.key});

  static String _fmtTs(DateTime dt) {
    final h = dt.hour; final m = dt.minute;
    final pm = h >= 12 ? 'PM' : 'AM';
    final hh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$hh:${m.toString().padLeft(2, '0')} $pm';
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(
      crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!message.isUser) Container(
              width: 28, height: 28, margin: const EdgeInsets.only(right: 8, bottom: 4),
              decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
              child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 13),
            ),
            Flexible(
              child: GestureDetector(
                onLongPress: () { HapticFeedback.mediumImpact(); onCopy(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  decoration: BoxDecoration(
                    color: message.isUser ? null
                        : message.text.startsWith('ERROR:')
                            ? AppTheme.red.withValues(alpha: 0.12)
                            : AppTheme.cardAltBg(context),
                    gradient: message.isUser ? AppTheme.tealGradient : null,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20), topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 20),
                    ),
                    boxShadow: [BoxShadow(
                      color: message.isUser ? AppTheme.primaryDark.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.05),
                      blurRadius: message.isUser ? 12 : 6, offset: const Offset(0, 3),
                    )],
                    border: message.text.startsWith('ERROR:')
                        ? Border.all(color: AppTheme.red.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: message.isUser
                      ? Text(message.text, style: const TextStyle(
                          color: Colors.white, fontSize: 14.5, fontFamily: 'DM Sans', height: 1.55))
                      : message.text.startsWith('ERROR:')
                          ? Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Padding(padding: EdgeInsets.only(top: 1, right: 6),
                                child: Icon(LucideIcons.circleAlert, size: 14, color: AppTheme.red)),
                              Flexible(child: Text(message.text.substring(6), style: const TextStyle(
                                  color: AppTheme.red, fontSize: 14, fontFamily: 'DM Sans', height: 1.55))),
                            ])
                      : MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(color: AppTheme.textPrimary(context), fontSize: 14, fontFamily: 'DM Sans', height: 1.55),
                            strong: TextStyle(color: AppTheme.textPrimary(context), fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
                            h1: TextStyle(color: AppTheme.textPrimary(context), fontSize: 16, fontFamily: 'DM Sans', fontWeight: FontWeight.w800),
                            h2: TextStyle(color: AppTheme.textPrimary(context), fontSize: 15, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
                            h3: TextStyle(color: AppTheme.textPrimary(context), fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700),
                            listBullet: TextStyle(color: AppTheme.textPrimary(context), fontSize: 14, fontFamily: 'DM Sans'),
                            code: const TextStyle(fontSize: 13, fontFamily: 'DM Sans', backgroundColor: Color(0xFFE8E6E0)),
                            blockSpacing: 6,
                          ),
                          softLineBreak: true,
                        ),
                ),
              ),
            ),
          ],
        ),
        if (showTimestamp)
          Padding(
            padding: EdgeInsets.only(top: 4, bottom: 8,
                left: message.isUser ? 0 : 36, right: message.isUser ? 4 : 0),
            child: Text(_fmtTs(message.timestamp), style: TextStyle(
              color: AppTheme.mutedText.withValues(alpha: 0.55), fontSize: 10, fontFamily: 'DM Sans')),
          )
        else
          const SizedBox(height: 10),
      ],
    ),
  );
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}
class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 8),
          decoration: const BoxDecoration(gradient: AppTheme.tealGradient, shape: BoxShape.circle),
          child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 13)),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppTheme.cardAltBg(context),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(20))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _PulseDot(ctrl: _ctrl, phase: 0.0), const SizedBox(width: 5),
          _PulseDot(ctrl: _ctrl, phase: 0.2), const SizedBox(width: 5),
          _PulseDot(ctrl: _ctrl, phase: 0.4),
        ]),
      ),
    ]),
  );
}
class _PulseDot extends StatelessWidget {
  final AnimationController ctrl; final double phase;
  const _PulseDot({required this.ctrl, required this.phase});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: ctrl,
    builder: (_, __) {
      final t       = (ctrl.value + phase) % 1.0;
      final scale   = 0.6 + 0.4 * (0.5 - 0.5 * (t * 2 * pi).abs().clamp(0.0, pi) / pi * 2).abs();
      final opacity = 0.35 + 0.65 * (t < 0.5 ? t * 2 : 1 - (t - 0.5) * 2);
      return Transform.scale(scale: scale.clamp(0.6, 1.0), child: Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: AppTheme.primaryDark.withValues(alpha: opacity.clamp(0.3, 1.0)),
          shape: BoxShape.circle,
        ),
      ));
    },
  );
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool hasText, loading;
  final double bottomPad;
  final VoidCallback onSend;
  const _InputBar({required this.ctrl, required this.focus, required this.hasText,
      required this.loading, required this.bottomPad, required this.onSend});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180), curve: Curves.easeOutCubic,
    color: AppTheme.cardBg(context),
    padding: EdgeInsets.fromLTRB(16, 10, 16, bottomPad + 10),
    child: Container(
      decoration: BoxDecoration(
        color: AppTheme.cardAltBg(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border(context)),
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        Expanded(child: TextField(
          controller: ctrl, focusNode: focus, onSubmitted: (_) => onSend(),
          maxLines: null, textCapitalization: TextCapitalization.sentences,
          style: TextStyle(fontSize: 14.5, fontFamily: 'DM Sans', color: AppTheme.textPrimary(context), height: 1.4),
          decoration: InputDecoration(
            hintText: 'Ask anything about cooking...',
            hintStyle: TextStyle(color: AppTheme.textMuted(context), fontSize: 14.5, fontFamily: 'DM Sans'),
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: InputBorder.none,
          ),
        )),
        const SizedBox(width: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic,
          width: 42, height: 42, margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: hasText && !loading ? AppTheme.tealGradient : null,
            color: hasText && !loading ? null : AppTheme.lightGray.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: TapScale(
            onTap: hasText && !loading ? onSend : null,
            child: Center(child: loading
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: 0.7)))
                : Icon(LucideIcons.arrowUp, size: 18, color: hasText ? Colors.white : AppTheme.mutedText.withValues(alpha: 0.5))),
          ),
        ),
      ]),
    ),
  );
}

// ─── Sessions Drawer ──────────────────────────────────────────────────────────

class _SessionsDrawer extends StatelessWidget {
  final List<_ChatSession> sessions;
  final int activeIdx;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onDelete;
  final VoidCallback onNew;
  const _SessionsDrawer({required this.sessions, required this.activeIdx,
      required this.onSelect, required this.onDelete, required this.onNew});

  String _fmtDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'Now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) => Drawer(
    backgroundColor: const Color(0xFF021E1F),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(
      topRight: Radius.circular(28), bottomRight: Radius.circular(28))),
    child: SafeArea(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 16, 0),
        child: Row(children: [
          Container(width: 38, height: 38,
              decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(12)),
              child: const Icon(LucideIcons.chefHat, color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Plately', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
            Text('Ask AI', style: TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'DM Sans')),
          ]),
          const Spacer(),
          TapScale(onTap: onNew, child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AppTheme.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.green.withValues(alpha: 0.4))),
            child: const Icon(LucideIcons.squarePen, color: AppTheme.green, size: 16),
          )),
        ]),
      ),
      const SizedBox(height: 20),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TapScale(onTap: onNew, child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(gradient: AppTheme.tealGradient, borderRadius: BorderRadius.circular(14)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(LucideIcons.plus, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('New Chat', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'DM Sans', fontWeight: FontWeight.w700)),
          ]),
        )),
      ),
      const SizedBox(height: 16),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 0, 8),
        child: Text(sessions.isEmpty ? 'No conversations yet' : 'Recent',
            style: const TextStyle(color: Colors.white38, fontSize: 11, fontFamily: 'DM Sans', fontWeight: FontWeight.w600, letterSpacing: 0.8)),
      ),
      Expanded(
        child: sessions.isEmpty
            ? const Center(child: Text('Start a new chat above',
                style: TextStyle(color: Colors.white24, fontSize: 13, fontFamily: 'DM Sans')))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: sessions.length,
                itemBuilder: (_, i) {
                  final s = sessions[i]; final active = i == activeIdx;
                  final preview = s.messages.isNotEmpty ? s.messages.last.text : 'No messages yet';
                  return Dismissible(
                    key: Key(s.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(color: AppTheme.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(14)),
                      alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 18),
                      child: const Icon(LucideIcons.trash2, color: AppTheme.red, size: 17),
                    ),
                    onDismissed: (_) => onDelete(i),
                    child: TapScale(
                      onTap: () => onSelect(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 3),
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        decoration: BoxDecoration(
                          color: active ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: active ? Border.all(color: Colors.white.withValues(alpha: 0.12)) : null,
                        ),
                        child: Row(children: [
                          AnimatedContainer(duration: const Duration(milliseconds: 180),
                            width: 3, height: 36, margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(color: active ? AppTheme.green : Colors.transparent, borderRadius: BorderRadius.circular(2))),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: active ? Colors.white : Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13, fontFamily: 'DM Sans', fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                            const SizedBox(height: 3),
                            Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontFamily: 'DM Sans')),
                          ])),
                          const SizedBox(width: 6),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_fmtDate(s.createdAt), style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10, fontFamily: 'DM Sans')),
                            const SizedBox(height: 4),
                            if (s.messages.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: active ? AppTheme.green.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('${s.messages.length}', style: TextStyle(
                                  color: active ? AppTheme.green : Colors.white.withValues(alpha: 0.35),
                                  fontSize: 10, fontFamily: 'DM Sans', fontWeight: FontWeight.w600)),
                              ),
                          ]),
                        ]),
                      ),
                    ),
                  );
                },
              ),
      ),
      Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Text('Swipe left to delete a chat',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11, fontFamily: 'DM Sans')),
      ),
    ])),
  );
}

// ─── Data Model ───────────────────────────────────────────────────────────────

class _ChatSession {
  String id, title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  _ChatSession({required this.id, required this.title, required this.messages, required this.createdAt});

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'created_at': createdAt.toIso8601String(),
    'messages': messages.map((m) => {'text': m.text, 'is_user': m.isUser, 'ts': m.timestamp.toIso8601String()}).toList(),
  };

  factory _ChatSession.fromJson(Map<String, dynamic> j) => _ChatSession(
    id: j['id'] as String, title: j['title'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
    messages: (j['messages'] as List).map((m) => ChatMessage(
      text: m['text'] as String, isUser: m['is_user'] as bool,
      timestamp: DateTime.parse(m['ts'] as String),
    )).toList(),
  );
}
